///|
pub async fn[X] ChoreoContext::spawn(
  self : ChoreoContext,
  f : async () -> X,
) -> @async.Task[X] {
  self.backend.spawn(f)
}
