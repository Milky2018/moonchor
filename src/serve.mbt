///|
typealias ServeChoreo[T, C] = (ChoreoContext, C) -> T!Async

///|
pub async fn serve_choreo[T, S : Location, C : Location + Message](
  backend : Backend,
  choreo : ServeChoreo[T, C],
  server : S
) -> Unit {
  let ctx = ChoreoContext::new(backend, server)
  while true {
    let client : C = backend.recv!(server)
    ctx.logger.info("|CHOREO|RECEIVED new connection from \{client.name()}")
    ctx.locations.push(client)
    let result = choreo!(ctx, client)
    ctx.locations.retain(fn(loc) { loc != client })
    ignore(result)
  }
}

///|
pub async fn connect_choreo[T, C : Location + Message, R : Location](
  backend : Backend,
  choreo : ServeChoreo[T, C],
  client : C,
  registry~ : R
) -> T {
  let ctx = ChoreoContext::new(backend, client)
  backend.send!(registry, client)
  backend.register(client)
  ctx.locations.push(client)
  let result = choreo!(ctx, client)
  ctx.locations.retain(fn(loc) { loc != client })
  backend.evict(client)
  result
}
