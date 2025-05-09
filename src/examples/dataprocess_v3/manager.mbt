///|
priv struct Manager {} derive(Eq, Show, Hash)

///|
impl @moonchor.Location for Manager with name(_) {
  "manager"
}

///|
priv struct ManagerState {
  mut counter : Int
  worker_list : Array[Worker]
}

///|
fn ManagerState::new(worker_list : Array[Worker]) -> ManagerState {
  ManagerState::{ counter: 0, worker_list }
}

///|
fn ManagerState::get_worker(self : ManagerState) -> Worker {
  let worker = self.worker_list[self.counter % self.worker_list.length()]
  self.counter = self.counter + 1
  worker
}

///|
async fn handle_task[In : @json.FromJson + ToJson, Out : @json.FromJson + ToJson](
  ctx : @moonchor.ChoreoContext,
  manager : Manager,
  state : @moonchor.Located[ManagerState, Manager],
  arg : @moonchor.Located[In, Manager],
  task : (In) -> Out
) -> @moonchor.Located[Out, Manager] {
  let worker_at_manager = ctx.locally(manager, fn(unwrapper) {
    unwrapper.unwrap(state).get_worker()
  })
  let worker = ctx.broadcast!(manager, worker_at_manager)
  let arg_at_worker = ctx.comm!(manager, worker, arg)
  let result_at_worker = ctx.locally(worker, fn(unwrapper) {
    let arg = unwrapper.unwrap(arg_at_worker)
    println("Processing data at \{worker.name()}")
    task(arg)
  })
  ctx.comm!(worker, manager, result_at_worker)
}
