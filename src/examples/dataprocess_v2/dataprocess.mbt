///|
priv struct Manager {} derive(Eq, Show, Hash)

///|
impl @moonchor.Location for Manager with name(_) {
  "manager"
}

///|
priv struct Worker {
  id : String
} derive(Eq, Show, Hash, ToJson, FromJson)

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
priv struct ManagerState {
  mut counter : Int
  results : Array[Int]
}

///|
fn ManagerState::get_new_counter(self : ManagerState) -> Int {
  let counter = self.counter
  self.counter = counter + 1
  counter
}

///|
fn ManagerState::push_result(self : ManagerState, result : Int) -> Unit {
  self.results.push(result)
}

///|
fn data_process_stage(x : Int) -> Int {
  x + 1
}

///|
fn load_data() -> Array[Int] {
  [3, 2, 1, 0]
}

///|
async fn remote_task[In : @moonchor.Message, Out : @moonchor.Message](
  ctx : @moonchor.ChoreoContext,
  worker : Worker,
  arg : @moonchor.Located[In, Manager],
  task : (In) -> Out
) -> @moonchor.Located[Out, Manager] {
  let data_piece_at_worker = ctx.comm!(manager, worker, arg)
  let result_at_worker = ctx.locally(worker, fn(unwrapper) {
    let data_piece = unwrapper.unwrap(data_piece_at_worker)
    println("Processing data at \{worker.name()}")
    task(data_piece)
  })
  ctx.comm!(worker, manager, result_at_worker)
}

///|
async fn data_process(ctx : @moonchor.ChoreoContext) -> Unit {
  let state_at_manager = ctx.locally(manager, fn(_unwrapper) {
    ManagerState::{ counter: 0, results: [] }
  })
  let data_at_manager = ctx.locally(manager, fn(_unwrapper) { load_data() })
  let mut data_is_empty = ctx.locally(manager, fn(unwrapper) {
    unwrapper.unwrap(data_at_manager).is_empty()
  })
  while not(ctx.announce!(manager, data_is_empty)) {
    let data_piece_at_manager = ctx.locally(manager, fn(unwrapper) {
      unwrapper.unwrap(data_at_manager).pop().unwrap()
    })
    let worker_at_manager = ctx.locally(manager, fn(unwrapper) {
      let state = unwrapper.unwrap(state_at_manager)
      let counter = state.get_new_counter()
      let idx = counter % workers.length()
      workers[idx]
    })
    let worker = ctx.announce!(manager, worker_at_manager)
    let result_at_manager = remote_task!(
      ctx, worker, data_piece_at_manager, data_process_stage,
    )
    ctx.locally(manager, fn(unwrapper) {
      let state = unwrapper.unwrap(state_at_manager)
      let result = unwrapper.unwrap(result_at_manager)
      state.push_result(result)
    })
    |> ignore
    data_is_empty = ctx.locally(manager, fn(unwrapper) {
      unwrapper.unwrap(data_at_manager).is_empty()
    })
  }
  ctx.locally(manager, fn(unwrapper) {
    let results = unwrapper.unwrap(state_at_manager).results
    println("Final results: \{results}")
  })
  |> ignore
}

///|
test "data_process 2.0" {
  // Should print:
  //   Processing data at worker1
  //   Processing data at worker2
  //   Processing data at worker3
  //   Processing data at worker4
  //   Final results: [1, 2, 3, 4]
  let backend = @moonchor.make_local_backend([
    manager, worker1, worker2, worker3, worker4,
  ])
  @moonchor.run_async(async fn() {
    @moonchor.run_choreo!(backend, data_process, manager)
  })
  for worker in workers {
    @moonchor.run_async(async fn() {
      @moonchor.run_choreo!(backend, data_process, worker)
    })
  }
}
