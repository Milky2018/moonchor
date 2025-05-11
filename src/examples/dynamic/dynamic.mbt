///|
priv struct Worker {
  id : String
} derive(Eq, Show, Hash)

///|
impl @moonchor.Location for Worker with name(self) {
  self.id
}

///|
let worker1 : Worker = Worker::{ id: "worker1" }

///|
let worker2 : Worker = Worker::{ id: "worker2" }

///|
async fn send_msg(ctx : @moonchor.ChoreoContext) -> Unit {
  let msg_at_worker1 = ctx.pure(worker1, "Hello")
  let msg_at_worker2 = ctx.comm!(worker1, worker2, msg_at_worker1)
  ctx.locally(worker2, fn(unwrapper) {
    let msg = unwrapper.unwrap(msg_at_worker2)
    println("Received message: \{msg}")
  })
  |> ignore
}

///|
test "Send message" {
  // Should print: 
  //   Received message: Hello
  let backend = @moonchor.make_local_backend([worker1, worker2])
  @moonchor.run_async(async fn() {
    @moonchor.run_choreo!(backend, send_msg, worker1)
  })
  @moonchor.run_async(async fn() {
    @moonchor.run_choreo!(backend, send_msg, worker2)
  })
}
