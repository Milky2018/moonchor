///|
struct ChoreoContext {
  location : &Location
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
  let context = ChoreoContext::{ location: role, backend, logger }
  if not(backend.check_location(role)) {
    alert(
      "Bug: location " + role.name() + " is not registered. " + CONTACT_AUTHOR,
    )
  }
  choreography!(context)
}

///| Local computation at the given location.
pub fn locally[T, L : Location](
  self : ChoreoContext,
  location : L,
  computation : (Unwrapper[L]) -> T
) -> Located[T, L] {
  self.logger.info("|CHOREO|LOCAL computation at \{location.name()}")
  if location as &Location == self.location {
    let result = self.backend.run(location, computation)
    return Located::Present(result)
  } else {
    return Located::Absent
  }
}

///| Sugar for `locally
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
  self.logger.info("|CHOREO|COMM message from \{from.name()} to \{to.name()}")
  if from as &Location == to {
    alert("Sending a message to the same location. ")
  }
  if self.location == from {
    self.backend.send!(from, to, unwrap(value))
    Located::Absent
  } else if self.location == to {
    Located::Present(self.backend.recv!(from, to))
  } else {
    return Located::Absent
  }
}

///| Broadcast a message to all locations.
pub async fn ChoreoContext::announce[T : Message, L : Location](
  self : ChoreoContext,
  loc : L,
  value : Located[T, L]
) -> T {
  self.logger.info("|CHOREO|BROADCAST at \{loc.name()}")
  if self.location == loc {
    let value = value.unwrap()
    self.backend.broadcast!(loc, value)
    value
  } else {
    let value = self.backend.recv!(loc, self.location)
    value
  }
}

///|
pub async fn ChoreoContext::locally_announce[T : Message, L : Location](
  self : ChoreoContext,
  loc : L,
  computation : (Unwrapper[L]) -> T
) -> T {
  let located_value = self.locally(loc, computation)
  self.announce!(loc, located_value)
}
