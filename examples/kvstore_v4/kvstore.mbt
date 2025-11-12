///|
priv struct Server {} derive(Hash, Show)

///|
impl @moonchor.Location for Server with name(_) {
  "server"
}

///|
let server : Server = Server::{  }

///|
priv struct Client {} derive(Hash, Show)

///|
impl @moonchor.Location for Client with name(_) {
  "client"
}

///|
let client : Client = Client::{  }

///|
priv struct Backup1 {} derive(Hash, Show)

///|
impl @moonchor.Location for Backup1 with name(_) {
  "backup1"
}

///|
let backup1 : Backup1 = Backup1::{  }

///|
priv struct Backup2 {} derive(Hash, Show)

///|
impl @moonchor.Location for Backup2 with name(_) {
  "backup2"
}

///|
let backup2 : Backup2 = Backup2::{  }

///|
priv struct ServerState {
  db : Map[String, Int]
}

///|
priv enum Request {
  Get(String)
  Put(String, Int)
} derive(ToJson, FromJson)

///|
type Response = Int?

///|
fn handle_request(state : ServerState, request : Request) -> Response {
  match request {
    Request::Get(key) => state.db.get(key)
    Request::Put(key, value) => {
      state.db[key] = value
      None
    }
  }
}

///|
async fn[Backup : @moonchor.Location] do_backup(
  ctx : @moonchor.ChoreoContext,
  request_at_server : @moonchor.Located[Request, Server],
  backup : Backup,
  state_at_backup : @moonchor.Located[ServerState, Backup],
) -> @moonchor.Located[Response, Server] {
  let request_at_backup = ctx.comm(server, backup, request_at_server)
  let response_at_backup = ctx.locally(backup, fn(unwrapper) {
    let request = unwrapper.unwrap(request_at_backup)
    let state = unwrapper.unwrap(state_at_backup)
    handle_request(state, request)
  })
  ctx.comm(backup, server, response_at_backup)
}

///|
type ReplicationStrategy = async (
  @moonchor.ChoreoContext,
  @moonchor.Located[Request, Server],
) -> @moonchor.Located[Response, Server]

///|
async fn double_replication_strategy(
  state_at_server : @moonchor.Located[ServerState, Server],
  state_at_backup1 : @moonchor.Located[ServerState, Backup1],
  state_at_backup2 : @moonchor.Located[ServerState, Backup2],
) -> ReplicationStrategy {
  fn(
    ctx : @moonchor.ChoreoContext,
    request_at_server : @moonchor.Located[Request, Server],
  ) {
    let res1 = do_backup(ctx, request_at_server, backup1, state_at_backup1)
    let res2 = do_backup(ctx, request_at_server, backup2, state_at_backup2)
    ctx.locally(server, fn(unwrapper) {
      let request = unwrapper.unwrap(request_at_server)
      let state = unwrapper.unwrap(state_at_server)
      let res = handle_request(state, request)
      check_consistency([unwrapper.unwrap(res1), unwrapper.unwrap(res2), res])
      res
    })
  }
}

///|
fn check_consistency(responses : Array[Response]) -> Unit {
  match responses.pop() {
    None => return
    Some(f) =>
      for res in responses {
        if res != f {
          abort("Inconsistent state: \{res} != \{f}")
          return
        }
      }
  }
}

///|
async fn access_server(
  ctx : @moonchor.ChoreoContext,
  request : @moonchor.Located[Request, Client],
  strategy : ReplicationStrategy,
) -> @moonchor.Located[Response, Client] {
  let request_at_server = ctx.comm(client, server, request)
  let response = strategy(ctx, request_at_server)
  ctx.comm(server, client, response)
}

///|
async fn put(
  ctx : @moonchor.ChoreoContext,
  strategy : ReplicationStrategy,
  key : String,
  value : Int,
) -> Unit {
  let request = ctx.locally(client, fn(_unwrapper) { Request::Put(key, value) })
  access_server(ctx, request, strategy) |> ignore
}

///|
async fn get(
  ctx : @moonchor.ChoreoContext,
  strategy : ReplicationStrategy,
  key : String,
) -> @moonchor.Located[Response, Client] {
  let request = ctx.locally(client, fn(_unwrapper) { Request::Get(key) })
  access_server(ctx, request, strategy)
}

///|
let test_pass : Ref[Bool] = Ref::new(false)

///|
async fn kvstore(ctx : @moonchor.ChoreoContext) -> Unit {
  let state_at_server = ctx.locally(server, fn(_unwrapper) {
    ServerState::{ db: {} }
  })
  let state_at_backup1 = ctx.locally(backup1, fn(_unwrapper) {
    ServerState::{ db: {} }
  })
  let state_at_backup2 = ctx.locally(backup2, fn(_unwrapper) {
    ServerState::{ db: {} }
  })
  let strategy = double_replication_strategy(
    state_at_server, state_at_backup1, state_at_backup2,
  )
  put(ctx, strategy, "key1", 42)
  put(ctx, strategy, "key2", 41)
  let v1_at_client = get(ctx, strategy, "key1")
  let v2_at_client = get(ctx, strategy, "key2")
  ctx.locally(client, fn(unwrapper) {
    let v1 = unwrapper.unwrap(v1_at_client).unwrap()
    let v2 = unwrapper.unwrap(v2_at_client).unwrap()
    if v1 + v2 == 83 {
      println("The server is working correctly")
      test_pass.val = true
    } else {
      abort("The server is not working correctly")
    }
  })
  |> ignore
}

///|
async fn main {
  @async.with_task_group(fn(group) {
    let backend = @moonchor.make_local_backend([
      server, client, backup1, backup2,
    ])
    group.spawn_bg(() => @moonchor.run_choreo(backend, kvstore, server))
    group.spawn_bg(() => @moonchor.run_choreo(backend, kvstore, client))
    group.spawn_bg(() => @moonchor.run_choreo(backend, kvstore, backup1))
    group.spawn_bg(() => @moonchor.run_choreo(backend, kvstore, backup2))
  })
}
