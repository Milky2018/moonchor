///|
priv struct Executor {
  ctx : @moonchor.ChoreoContext
  client : Client
  manager : Manager
  manager_state : @moonchor.Located[ManagerState, Manager]
}

///|
fn Executor::new(
  ctx : @moonchor.ChoreoContext,
  client : Client,
  manager : Manager,
  manager_state : @moonchor.Located[ManagerState, Manager]
) -> Executor {
  { ctx, client, manager, manager_state }
}

///|
async fn Executor::execute[In : @json.FromJson + ToJson, Out : @json.FromJson + ToJson](
  self : Executor,
  task : (In) -> Out,
  arg : @moonchor.Located[In, Client]
) -> @moonchor.Located[Out, Client] {
  let arg_at_manager = self.ctx.comm!(self.client, self.manager, arg)
  let result_at_manager = handle_task!(
    self.ctx,
    manager,
    self.manager_state,
    arg_at_manager,
    task,
  )
  self.ctx.comm!(self.manager, self.client, result_at_manager)
}
