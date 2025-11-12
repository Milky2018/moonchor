///|
enum AsyncLocated[T, _] {
  Present(@async.Task[T])
  Absent
}

///|
async fn[T, L] AsyncLocated::unwrap(self : AsyncLocated[T, L]) -> T {
  match self {
    Present(t) => t.wait()
    Absent =>
      abort(
        "Bug: unwrapping an empty value. This should never happen. " +
        CONTACT_AUTHOR,
      )
  }
}

///|
/// Communication between two locations.
// pub async fn[T : Message, From : Location, To : Location] ChoreoContext::async_comm(
//   self : ChoreoContext,
//   from : From,
//   to : To,
//   value : Located[T, From],
// ) -> AsyncLocated[T, To] {
//   self.check_location(from)
//   self.check_location(to)
//   self.logger.info("|CHOREO|COMM message from \{from.name()} to \{to.name()}")
//   if (from as &Location) == to {
//     abort("Sending a message to the same location. ")
//   }
//   if self.role == from {
//     self.backend.send(from, to, value.unwrap())
//     Absent
//   } else if self.role == to {
//     Present(self.backend.recv(from, to))
//   } else {
//     return Absent
//   }
// }
