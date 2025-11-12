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
let alice : Alice = Alice::{  }

///|
let bob : Bob = Bob::{  }

///|
let carol : Carol = Carol::{  }

///|
const BASE_SIZE : Int = 200

///|
let validates : Array[Int] = []

///|
async fn compute_sum(ctx : @moonchor.ChoreoContext) -> Unit {
  let source_at_alice = ctx.locally(alice, fn(_unwrapper) {
    Array::makei(BASE_SIZE, i => i)
  })
  let source_at_carol = ctx.locally(carol, fn(_unwrapper) {
    Array::makei(BASE_SIZE, i => i)
  })
  let mut sum_at_bob = ctx.locally(bob, fn(_unwrapper) { 0 })
  let handles = []
  for i in 0..<BASE_SIZE {
    let handle = ctx.spawn(fn() {
      let value_at_alice = ctx.locally(alice, fn(unwrapper) {
        unwrapper.unwrap(source_at_alice)[i]
      })
      @async.sleep(i)
      let value_at_bob = ctx.comm(alice, bob, value_at_alice)
      sum_at_bob = ctx.locally(bob, fn(unwrapper) {
        let sum = unwrapper.unwrap(sum_at_bob)
        let value = unwrapper.unwrap(value_at_bob)
        println("adding alice \{value}")
        sum + value
      })
    })
    handles.push(handle)
  }
  for i in 0..<BASE_SIZE {
    let handle = ctx.spawn(fn() {
      let value_at_carol = ctx.locally(carol, fn(unwrapper) {
        unwrapper.unwrap(source_at_carol)[i]
      })
      let value_at_bob = ctx.comm(carol, bob, value_at_carol)
      @async.sleep(i)
      sum_at_bob = ctx.locally(bob, fn(unwrapper) {
        let sum = unwrapper.unwrap(sum_at_bob)
        let value = unwrapper.unwrap(value_at_bob)
        println("adding carol \{value}")
        sum + value
      })
    })
    handles.push(handle)
  }
  for handle in handles {
    handle.wait()
  }
  ctx.locally(bob, fn(unwrapper) {
    let sum = unwrapper.unwrap(sum_at_bob)
    validates.push(sum)
  })
  |> ignore
}

///|
async test {
  @async.with_task_group(fn(group) {
    let backend = @moonchor.make_local_backend([alice, bob, carol], group)
    group.spawn_bg(() => @moonchor.run_choreo(backend, compute_sum, alice))
    group.spawn_bg(() => @moonchor.run_choreo(backend, compute_sum, bob))
    group.spawn_bg(() => @moonchor.run_choreo(backend, compute_sum, carol))
  })
  inspect(validates, content="[39800]")
}
