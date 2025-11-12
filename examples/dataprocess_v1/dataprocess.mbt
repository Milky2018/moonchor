///|
priv struct Manager {} derive(Show, Hash)

///|
impl @moonchor.Location for Manager with name(_) {
  "manager"
}

///|
priv struct Worker {
  id : String
} derive(Show, Hash, ToJson, FromJson)

///|
impl @moonchor.Location for Worker with name(self) {
  self.id
}

///|
let manager : Manager = Manager::{  }

///|
let worker1 : Worker = Worker::{ id: "worker1" }

///|
let worker2 : Worker = Worker::{ id: "worker2" }

///|
let worker3 : Worker = Worker::{ id: "worker3" }

///|
let worker4 : Worker = Worker::{ id: "worker4" }

///|
let workers : Array[Worker] = [worker1, worker2, worker3, worker4]

///|
fn data_process_stage(x : Int) -> Int {
  x + 1
}

///|
fn load_data() -> Array[Int] {
  [3, 2, 1, 0]
}

///|
async fn data_process(ctx : @moonchor.ChoreoContext) -> Unit {
  let mut counter_at_manager = ctx.locally(manager, fn(_unwrapper) { 0 })
  let data_at_manager = ctx.locally(manager, fn(_unwrapper) { load_data() })
  let results_at_manager = ctx.locally(manager, fn(_unwrapper) { [] })
  let mut data_is_empty = ctx.locally(manager, fn(unwrapper) {
    unwrapper.unwrap(data_at_manager).is_empty()
  })
  while not(ctx.broadcast(manager, data_is_empty)) {
    let data_piece_at_manager = ctx.locally(manager, fn(unwrapper) {
      unwrapper.unwrap(data_at_manager).pop().unwrap()
    })
    let worker_at_manager = ctx.locally(manager, fn(unwrapper) {
      let counter = unwrapper.unwrap(counter_at_manager)
      let idx = counter % workers.length()
      workers[idx]
    })
    let worker = ctx.broadcast(manager, worker_at_manager)
    counter_at_manager = ctx.locally(manager, fn(unwrapper) {
      let counter = unwrapper.unwrap(counter_at_manager)
      counter + 1
    })
    let data_piece_at_worker = ctx.comm(manager, worker, data_piece_at_manager)
    let result_at_worker = ctx.locally(worker, fn(unwrapper) {
      let data_piece = unwrapper.unwrap(data_piece_at_worker)
      println("Processing data piece: \{data_piece} at \{worker.name()}")
      data_process_stage(data_piece)
    })
    let result_at_manager = ctx.comm(worker, manager, result_at_worker)
    ctx.locally(manager, fn(unwrapper) {
      let results = unwrapper.unwrap(results_at_manager)
      let result = unwrapper.unwrap(result_at_manager)
      results.push(result)
    })
    |> ignore
    data_is_empty = ctx.locally(manager, fn(unwrapper) {
      unwrapper.unwrap(data_at_manager).is_empty()
    })
  }
  ctx.locally(manager, fn(unwrapper) {
    let results = unwrapper.unwrap(results_at_manager)
    println("Final results: \{results}")
  })
  |> ignore
}

///|
async test {
  // Should print:
  //   Processing data piece: 0 at worker1
  //   Processing data piece: 1 at worker2
  //   Processing data piece: 2 at worker3
  //   Processing data piece: 3 at worker4
  //   Final results: [1, 2, 3, 4]
  @async.with_task_group(fn(group) {
    let backend = @moonchor.make_local_backend(
      [manager, worker1, worker2, worker3, worker4],
      group,
    )
    group.spawn_bg(() => @moonchor.run_choreo(backend, data_process, manager))
    for worker in workers {
      group.spawn_bg(() => @moonchor.run_choreo(backend, data_process, worker))
    }
  })
}
