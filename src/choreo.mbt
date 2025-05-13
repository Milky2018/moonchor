///|
struct ChoreoContext {
  role : &Location
  locations : Array[&Location]
  backend : Backend
  logger : &Logger
}

///| Choreography type.
typealias Choreo[T] = (ChoreoContext) -> T!Async

///| Run a choreography in the given location and backend.
/// Default logger is the backend logger.
pub async fn run_choreo[T, L : Location](
  backend : Backend,
  choreography : Choreo[T],
  role : L,
  logger? : &Logger
) -> T {
  let logger = logger.or(backend.get_logger())
  let locations = backend.get_locations()
  let context = ChoreoContext::{ role, locations, backend, logger }
  if not(locations.contains(role)) {
    @tlk.alert(
      "Bug: location " + role.name() + " is not registered. " + CONTACT_AUTHOR,
    )
  }
  choreography!(context)
}

///|
fn check_location[L : Location](self : ChoreoContext, location : L) -> Unit {
  if not(self.locations.contains(location)) {
    @tlk.alert(
      "Bug: location " +
      location.name() +
      " is out of enclave. " +
      CONTACT_AUTHOR,
    )
  }
}

///| Local computation at the given location.
pub fn locally[T, L : Location](
  self : ChoreoContext,
  location : L,
  computation : (Unwrapper[L]) -> T
) -> Located[T, L] {
  self.check_location(location)
  self.logger.info("|CHOREO|LOCAL computation at \{location.name()}")
  if location as &Location == self.role {
    let result = self.backend.run(location, computation)
    return Located::Present(result)
  } else {
    return Located::Absent
  }
}

///| Sugar for `locally`. Be aware: the `value` will always be 
/// evaluated. 
pub fn pure[T, L : Location](
  self : ChoreoContext,
  location : L,
  value : T
) -> Located[T, L] {
  self.locally(location, fn(_unwrapper) { value })
}

///| Communication between two locations.
pub async fn comm[T : Message, From : Location, To : Location](
  self : ChoreoContext,
  from : From,
  to : To,
  value : Located[T, From]
) -> Located[T, To] {
  self.check_location(from)
  self.check_location(to)
  self.logger.info("|CHOREO|COMM message from \{from.name()} to \{to.name()}")
  if from as &Location == to {
    @tlk.alert("Sending a message to the same location. ")
  }
  if self.role == from {
    self.backend.send!(to, value.unwrap())
    Located::Absent
  } else if self.role == to {
    Located::Present(self.backend.recv!(to))
  } else {
    return Located::Absent
  }
}

///| Broadcast a message to all locations.
pub async fn ChoreoContext::broadcast[T : Message, L : Location](
  self : ChoreoContext,
  loc : L,
  value : Located[T, L]
) -> T {
  self.check_location(loc)
  self.logger.info("|CHOREO|BROADCAST at \{loc.name()}")
  if self.role == loc {
    let value = value.unwrap()
    for to in self.locations {
      if to != loc {
        self.backend.send!(to, value)
      }
    }
    value
  } else {
    let value = self.backend.recv!(self.role)
    value
  }
}

///| Locally compute and then broadcast the result.
/// ```
/// ctx.locally_broadcast!(loc, f)
/// ```
/// equals to 
/// ```
/// let value = ctx.locally(loc, f)
/// ctx.broadcast!(loc, value)
/// ```
pub async fn ChoreoContext::locally_broadcast[T : Message, L : Location](
  self : ChoreoContext,
  loc : L,
  computation : (Unwrapper[L]) -> T
) -> T {
  let located_value = self.locally(loc, computation)
  self.broadcast!(loc, located_value)
}

///| Make an enclave with a subchoreography where `broadcast` will
/// only spread to the given locations.
pub async fn ChoreoContext::enclave[T](
  self : ChoreoContext,
  locations : Array[&Location],
  subchoreo : Choreo[T]
) -> T {
  for loc in locations {
    self.check_location(loc)
  }
  self.logger.info("|CHOREO|ENCLAVE at \{self.role.name()}")
  let context = ChoreoContext::{
    role: self.role,
    locations,
    backend: self.backend,
    logger: self.logger,
  }
  subchoreo!(context)
}

///| Announce a located value to all locations in the given array. 
/// This operation takes a subchoreography as an argument.
/// ``` 
/// announce(from, targets, located_value, fn (ctx, value) { ... })
/// ``` 
/// equals to
/// ```
/// ctx.enclave(targets + [from], fn (ctx) {
///   let value = ctx.broadcast!(from, located_value)
///   ...
/// })
/// ```
pub async fn ChoreoContext::announce[T : Message, L : Location, R](
  self : ChoreoContext,
  loc : L,
  targets : Array[&Location],
  located_value : Located[T, L],
  subchoreo : (ChoreoContext, T) -> R!Async
) -> R {
  self.enclave!(targets + [loc], fn(ctx) {
    let value = ctx.broadcast!(loc, located_value)
    subchoreo!(ctx, value)
  })
}
