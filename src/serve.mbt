// ///|
// typealias ServeChoreo[T, C] = (ChoreoContext, C) -> T!Async

// ///|
// pub async fn serve_choreo[T, S : Location, C : Location](
//   backend : Backend,
//   choreo : ServeChoreo[T, C],
//   server : S
// ) -> T {
//   // loop {
//   //   let client : C = backend.recv!()
//   // }
//   ...
// }

// ///|
// pub async fn connect_choreo[T, C : Location](
//   backend : Backend,
//   choreo : ServeChoreo[T, C],
//   client : C
// ) -> T {
//   ...
// }
