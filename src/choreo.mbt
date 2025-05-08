///| Represents a value located at a specific location.
enum Located[T, _] {
  Present(T)
  Absent
}

///| 
fn unwrap[T, L](self : Located[T, L]) -> T {
  match self {
    Located::Present(t) => t
    Located::Absent =>
      abort(
        "Bug: unwrapping an empty value. This should never happen. " +
        CONTACT_AUTHOR,
      )
  }
}

///|
pub(open) trait Location: Show + Hash {
  name(Self) -> String
}

///|
impl Eq for &Location with op_equal(self, other) {
  self.name() == other.name()
}

///|
struct ChoreoContext {
  location : &Location
  backend : Backend
  logger : &Logger
}

///| Run a choreography in the given location and backend.
/// Default logger is the backend logger.
pub async fn run_choreo[T, L : Location](
  backend : Backend,
  choreography : (ChoreoContext) -> T!Async,
  role : L,
  logger? : &Logger
) -> T {
  let logger = logger.or(backend.get_logger())
  let context = ChoreoContext::{ location: role, backend, logger }
  if not(backend.check_location(role)) {
    abort(
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

///| Communication between two locations.
pub async fn comm[T : @json.FromJson + ToJson, From : Location, To : Location](
  self : ChoreoContext,
  from : From,
  to : To,
  value : Located[T, From]
) -> Located[T, To] {
  self.logger.info("|CHOREO|COMM message from \{from.name()} to \{to.name()}")
  if self.location == from {
    self.backend.send!(from, to, unwrap(value))
    Located::Absent
  } else if self.location == to {
    Located::Present(self.backend.recv!(from, to))
  } else {
    return Located::Absent
  }
}

///| Make a located boolean as global condition.
pub async fn condition[L : Location](
  self : ChoreoContext,
  loc : L,
  c : Located[Bool, L]
) -> Bool {
  self.logger.info("|CHOREO|CONDITION at \{loc.name()}")
  if self.location == loc {
    let c = c.unwrap()
    self.backend.broadcast!(loc, c)
    c
  } else {
    let value = self.backend.recv!(loc, self.location)
    value
  }
}
