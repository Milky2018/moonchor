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
let manager : Manager = Manager::{  }

///|
let client : Client = Client::{  }

///|
async fn data_process(ctx : @moonchor.ChoreoContext) -> Unit {
  let manager_state = ctx.locally(manager, fn(_unwrapper) {
    ManagerState::new(workers)
  })
  let client_state = ctx.locally(client, fn(_unwrapper) { ClientState::new() })
  let executor = Executor::new(ctx, client, manager, manager_state)
  while not(
          ctx.locally_broadcast(client, fn(unwrapper) {
            unwrapper.unwrap(client_state).inputs.is_empty()
          }),
        ) {
    let data_piece_at_client = client_state.map(fn(state) {
      state.inputs.pop().unwrap()
    })
    let result_at_client = executor.execute(
      data_process_stage, data_piece_at_client,
    )
    ctx.locally(client, fn(unwrapper) {
      let result = unwrapper.unwrap(result_at_client)
      unwrapper.unwrap(client_state).outputs.push(result)
    })
    |> ignore
  }
  client_state.map(fn(state) { println("Final results: \{state.outputs}") })
  |> ignore
}

///|
async fn main {
  // Should print:
  //   Processing data at worker1
  //   Processing data at worker2
  //   Processing data at worker3
  //   Processing data at worker4
  //   Final results: [1, 2, 3, 4]
  @async.with_task_group(fn(group) {
    let backend = @moonchor.make_local_backend(
      [manager, worker1, worker2, worker3, worker4, client],
      group,
    )
    group.spawn_bg(() => @moonchor.run_choreo(backend, data_process, manager))
    group.spawn_bg(() => @moonchor.run_choreo(backend, data_process, client))
    for worker in workers {
      group.spawn_bg(() => @moonchor.run_choreo(backend, data_process, worker))
    }
  })
}
