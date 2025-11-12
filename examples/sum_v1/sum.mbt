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
const BASE_SIZE : Int = 20

///|
let validates : Array[(String, Int)] = []

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
      @async.sleep(i + 5)
      let value_at_bob = ctx.comm(alice, bob, value_at_alice)
      sum_at_bob = ctx.locally(bob, fn(unwrapper) {
        let sum = unwrapper.unwrap(sum_at_bob)
        let value = unwrapper.unwrap(value_at_bob)
        validates.push(("alice", value))
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
      @async.sleep(i + 5)
      sum_at_bob = ctx.locally(bob, fn(unwrapper) {
        let sum = unwrapper.unwrap(sum_at_bob)
        let value = unwrapper.unwrap(value_at_bob)
        validates.push(("carol", value))
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
    validates.push(("bob", sum))
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
  inspect(
    validates,
    content=(
      #|[("alice", 0), ("carol", 0), ("alice", 1), ("carol", 1), ("alice", 2), ("carol", 2), ("alice", 3), ("carol", 3), ("alice", 4), ("carol", 4), ("alice", 5), ("carol", 5), ("alice", 6), ("carol", 6), ("alice", 7), ("carol", 7), ("alice", 8), ("carol", 8), ("alice", 9), ("carol", 9), ("alice", 10), ("carol", 10), ("alice", 11), ("carol", 11), ("alice", 12), ("carol", 12), ("alice", 13), ("carol", 13), ("alice", 14), ("carol", 14), ("alice", 15), ("carol", 15), ("alice", 16), ("carol", 16), ("alice", 17), ("carol", 17), ("alice", 18), ("carol", 18), ("alice", 19), ("carol", 19), ("bob", 380)]
    ),
  )
}
