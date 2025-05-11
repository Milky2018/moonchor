///| Represents a value located at a specific location.
enum Located[T, _] {
  Present(T)
  Absent
}

///| Mapping a located value
/// ```
/// v.map(f)
/// ``` 
/// Equals to 
/// ```
/// ctx.locally(loc, fn (unwrapper) { f(unwrapper.unwrap(v)) })
/// ```
pub fn Located::map[T, L, R](self : Located[T, L], f : (T) -> R) -> Located[R, L] {
  match self {
    Located::Present(t) => Located::Present(f(t))
    Located::Absent => Located::Absent
  }
}

///| 
fn Located::unwrap[T, L](self : Located[T, L]) -> T {
  match self {
    Located::Present(t) => t
    Located::Absent =>
      alert(
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
