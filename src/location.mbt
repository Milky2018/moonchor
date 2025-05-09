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
