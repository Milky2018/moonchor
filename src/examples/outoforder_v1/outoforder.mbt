///|
priv struct Alice {} derive(Show, Hash)

///|
impl @moonchor.Location for Alice with name(_) {
  "Alice"
}

///|
priv struct Bob {} derive(Show, Hash)

///|
impl @moonchor.Location for Bob with name(_) {
  "Bob"
}

///|
priv struct Carol {} derive(Show, Hash)

///|
impl @moonchor.Location for Carol with name(_) {
  "Carol"
}

///|
priv struct Dummy {} derive(Show, Hash)

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
  let msg1 = ctx.locally(alice, fn(_unwrapper) { 1 })
  let msg2 = ctx.locally(carol, fn(_unwrapper) { 2 })
  let nomsg = ctx.locally(alice, fn(_unwrapper) { 0 })
  for i in 0..<5 {
    ctx.comm(alice, dummy, nomsg) |> ignore
  }
  let msg1 = ctx.comm(alice, bob, msg1)
  let msg2 = ctx.comm(carol, bob, msg2)
  ctx.locally(bob, fn(unwrapper) {
    let msg1 = unwrapper.unwrap(msg1)
    let msg2 = unwrapper.unwrap(msg2)
    validates.push(msg1)
    validates.push(msg2)
  })
  |> ignore
}

///|
test "out of order 1.0" {
  let backend = @moonchor.make_local_backend([alice, bob, carol, dummy])
  @kit.run_async(() => @moonchor.run_choreo(backend, out_of_order, alice))
  @kit.run_async(() => @moonchor.run_choreo(backend, out_of_order, bob))
  @kit.run_async(() => @moonchor.run_choreo(backend, out_of_order, carol))
  @kit.run_async(() => @moonchor.run_choreo(backend, out_of_order, dummy))
  assert_eq(validates, [1, 2])
}
