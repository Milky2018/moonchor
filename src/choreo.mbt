///|
struct ChoreoContext {
  role : &Location
  locations : Array[&Location]
  backend : Backend
  logger : &Logger
}

///|
fn ChoreoContext::new(backend : Backend, role : &Location) -> ChoreoContext {
  let locations = backend.locations
  let logger = backend.logger
  ChoreoContext::{ role, locations, backend, logger }
}

///|
/// Choreography type.
pub type Choreo[T] = async (ChoreoContext) -> T

///|
/// Run a choreography in the given location and backend.
/// Default logger is the backend logger.
pub async fn[T, L : Location] run_choreo(
  backend : Backend,
  choreography : Choreo[T],
  role : L,
) -> T {
  let context = ChoreoContext::new(backend, role)
  let locations = context.locations
  if not(locations.contains(role)) {
    abort(
      "Bug: location " + role.name() + " is not registered. " + CONTACT_AUTHOR,
    )
  }
  backend.init_at(role)
  choreography(context)
}

///|
fn[L : Location] ChoreoContext::check_location(
  self : ChoreoContext,
  location : L,
) -> Unit {
  if not(self.locations.contains(location)) {
    abort(
      "Bug: location " +
      location.name() +
      " is out of enclave. " +
      CONTACT_AUTHOR,
    )
  }
}

///|
/// Local computation at the given location.
pub async fn[T, L : Location] ChoreoContext::locally(
  self : ChoreoContext,
  location : L,
  computation : async (Unwrapper[L]) -> T,
) -> Located[T, L] {
  self.check_location(location)
  self.logger.info("|CHOREO|LOCAL computation at \{location.name()}")
  if (location as &Location) == self.role {
    let result = self.backend.run(location, computation)
    return Located::Present(result)
  } else {
    return Located::Absent
  }
}

///|
/// Communication between two locations.
pub async fn[T : Message, From : Location, To : Location] ChoreoContext::comm(
  self : ChoreoContext,
  from : From,
  to : To,
  value : Located[T, From],
) -> Located[T, To] {
  self.check_location(from)
  self.check_location(to)
  self.logger.info("|CHOREO|COMM message from \{from.name()} to \{to.name()}")
  if (from as &Location) == to {
    abort("Sending a message to the same location. ")
  }
  if self.role == from {
    self.backend.send(from, to, value.unwrap())
    Located::Absent
  } else if self.role == to {
    Located::Present(self.backend.recv(from, to))
  } else {
    return Located::Absent
  }
}

///|
/// Broadcast a message to all locations.
pub async fn[T : Message, L : Location] ChoreoContext::broadcast(
  self : ChoreoContext,
  loc : L,
  value : Located[T, L],
) -> T {
  self.check_location(loc)
  let to_info = self.locations
    .filter(fn(to) { to != loc })
    .map(fn(to) { to.name() })
    .join(", ")
  self.logger.info("|CHOREO|BROADCAST from \{loc.name()} to \{to_info}")
  if self.role == loc {
    let value = value.unwrap()
    for to in self.locations {
      if to != loc {
        self.backend.send(loc, to, value)
      }
    }
    value
  } else if self.locations.contains(loc) {
    self.backend.recv(loc, self.role)
  } else {
    abort(
      "Broadcast target is not in the enclave. This should never happen. " +
      CONTACT_AUTHOR,
    )
  }
}

///|
/// Locally compute and then broadcast the result.
pub async fn[T : Message, L : Location] ChoreoContext::locally_broadcast(
  self : ChoreoContext,
  loc : L,
  computation : async (Unwrapper[L]) -> T,
) -> T {
  let located_value = self.locally(loc, computation)
  self.broadcast(loc, located_value)
}

///|
/// Make an enclave with a subchoreography where `broadcast` will
/// only spread to the given locations.
pub async fn ChoreoContext::enclave(
  self : ChoreoContext,
  locations : Array[&Location],
  subchoreo : Choreo[Unit],
) -> Unit {
  if not(locations.contains(self.role)) {
    return
  }
  for loc in locations {
    self.check_location(loc)
  }
  let location_info = locations.map(fn(loc) { loc.name() }).join(", ")
  self.logger.info("|CHOREO|ENCLAVE including \{location_info}")
  let context = ChoreoContext::{
    role: self.role,
    locations,
    backend: self.backend,
    logger: self.logger,
  }
  subchoreo(context)
}

///|
/// Announce a located value to all locations in the given array. 
/// This operation takes a subchoreography as an argument.
pub async fn[T : Message, L : Location] ChoreoContext::announce(
  self : ChoreoContext,
  loc : L,
  targets : Array[&Location],
  located_value : Located[T, L],
  subchoreo : async (ChoreoContext, T) -> Unit,
) -> Unit {
  self.enclave(targets + [loc], fn(ctx) {
    let value = ctx.broadcast(loc, located_value)
    subchoreo(ctx, value)
  })
}
