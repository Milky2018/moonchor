///|
priv struct Alice {} derive(Eq, Show, Hash)

///|
impl @moonchor.Location for Alice with name(_) {
  "Alice"
}

///|
priv struct Bob {} derive(Eq, Show, Hash)

///|
impl @moonchor.Location for Bob with name(_) {
  "Bob"
}

///|
priv struct Carol {} derive(Eq, Show, Hash)

///|
impl @moonchor.Location for Carol with name(_) {
  "Carol"
}

///|
priv struct Dummy {} derive(Eq, Show, Hash)

///|
impl @moonchor.Location for Dummy with name(_) {
  "Dummy"
}

///|
let alice : Alice = Alice::{  }

///|
let bob : Bob = Bob::{  }

///|
let carol : Carol = Carol::{  }

///|
let dummy : Dummy = Dummy::{  }

///|
let validates : Array[Int] = []

///|
async fn out_of_order(ctx : @moonchor.ChoreoContext) -> Unit {
  let msg0 = ctx.locally(alice, fn(_unwrapper) { 0 })
  let msg1 = ctx.locally(bob, fn(_unwrapper) { 1 })
  let msg2 = ctx.locally(carol, fn(_unwrapper) { 2 })
  let msg0 = ctx.comm!(alice, dummy, msg0)
  let msg1 = ctx.comm!(bob, dummy, msg1)
  let msg2 = ctx.comm!(carol, dummy, msg2)
  let msg3 = ctx.locally_broadcast!(bob, fn(_unwrapper) { 3 })
  let msg4 = ctx.locally(carol, fn(_unwrapper) { 4 })
  ctx.locally(dummy, fn(unwrapper) {
    validates.push(unwrapper.unwrap(msg0))
    validates.push(unwrapper.unwrap(msg1))
    validates.push(unwrapper.unwrap(msg2))
    validates.push(msg3)
  })
  |> ignore
  ctx.announce!(carol, [alice, dummy], msg4, fn(ctx, msg4) {
    let msg51 = ctx.locally(alice, fn(_unwrapper) { 51 })
    let msg51 = ctx.comm!(alice, dummy, msg51)
    ctx.locally(dummy, fn(unwrapper) {
      validates.push(msg4)
      validates.push(unwrapper.unwrap(msg51))
    })
    |> ignore
  })
  ctx.enclave!([dummy, bob], fn(ctx) {
    let msg61 = ctx.locally(bob, fn(_unwrapper) { 61 })
    let msg61 = ctx.comm!(bob, dummy, msg61)
    ctx.locally(dummy, fn(unwrapper) { validates.push(unwrapper.unwrap(msg61)) })
    |> ignore
  })
  let msg7 = ctx.locally(carol, fn(_unwrapper) { 7 })
  let msg7 = ctx.comm!(carol, dummy, msg7)
  ctx.locally(dummy, fn(unwrapper) { validates.push(unwrapper.unwrap(msg7)) })
  |> ignore
}

///|
test "out of order 2.0" {
  let backend = @moonchor.make_local_backend([alice, bob, carol, dummy])
  @kit.run_async(async fn() {
    @moonchor.run_choreo!(backend, out_of_order, alice)
  })
  @kit.run_async(async fn() {
    @moonchor.run_choreo!(backend, out_of_order, bob)
  })
  @kit.run_async(async fn() {
    @moonchor.run_choreo!(backend, out_of_order, carol)
  })
  @kit.run_async(async fn() {
    @moonchor.run_choreo!(backend, out_of_order, dummy)
  })
  assert_eq!(validates, [0, 1, 2, 3, 4, 51, 61, 7])
}
