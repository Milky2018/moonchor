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
priv struct Backup {} derive(Hash, Show)

///|
impl @moonchor.Location for Backup with name(_) {
  "backup"
}

///|
let backup : Backup = Backup::{  }

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
typealias Int? as Response

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
async fn replicate(
  ctx : @moonchor.ChoreoContext,
  request_at_server : @moonchor.Located[Request, Server],
  state_at_server : @moonchor.Located[ServerState, Server],
  state_at_backup : @moonchor.Located[ServerState, Backup],
) -> @moonchor.Located[Response, Server] {
  let request_is_put = ctx.locally(server, fn(unwrapper) {
    let request = unwrapper.unwrap(request_at_server)
    request is Put(_, _)
  })
  if ctx.broadcast(server, request_is_put) {
    let request_at_backup = ctx.comm(server, backup, request_at_server)
    let response_at_backup = ctx.locally(backup, fn(unwrapper) {
      let request = unwrapper.unwrap(request_at_backup)
      let state = unwrapper.unwrap(state_at_backup)
      handle_request(state, request)
    })
    ctx.comm(backup, server, response_at_backup) |> ignore
  }
  ctx.locally(server, fn(unwrapper) {
    let request = unwrapper.unwrap(request_at_server)
    let state = unwrapper.unwrap(state_at_server)
    handle_request(state, request)
  })
}

///|
async fn access_server(
  ctx : @moonchor.ChoreoContext,
  request : @moonchor.Located[Request, Client],
  state_at_server : @moonchor.Located[ServerState, Server],
  state_at_backup : @moonchor.Located[ServerState, Backup],
) -> @moonchor.Located[Response, Client] {
  let request_at_server = ctx.comm(client, server, request)
  let response = replicate(
    ctx, request_at_server, state_at_server, state_at_backup,
  )
  ctx.comm(server, client, response)
}

///|
async fn put(
  ctx : @moonchor.ChoreoContext,
  state_at_server : @moonchor.Located[ServerState, Server],
  state_at_backup : @moonchor.Located[ServerState, Backup],
  key : String,
  value : Int,
) -> Unit {
  let request = ctx.locally(client, fn(_unwrapper) { Request::Put(key, value) })
  access_server(ctx, request, state_at_server, state_at_backup) |> ignore
}

///|
async fn get(
  ctx : @moonchor.ChoreoContext,
  state_at_server : @moonchor.Located[ServerState, Server],
  state_at_backup : @moonchor.Located[ServerState, Backup],
  key : String,
) -> @moonchor.Located[Response, Client] {
  let request = ctx.locally(client, fn(_unwrapper) { Request::Get(key) })
  access_server(ctx, request, state_at_server, state_at_backup)
}

///|
let test_pass : Ref[Bool] = Ref::new(false)

///|
async fn kvstore(ctx : @moonchor.ChoreoContext) -> Unit {
  let state_at_server = ctx.locally(server, fn(_unwrapper) {
    ServerState::{ db: {} }
  })
  let state_at_backup = ctx.locally(backup, fn(_unwrapper) {
    ServerState::{ db: {} }
  })
  put(ctx, state_at_server, state_at_backup, "key1", 42)
  put(ctx, state_at_server, state_at_backup, "key2", 41)
  let v1_at_client = get(ctx, state_at_server, state_at_backup, "key1")
  let v2_at_client = get(ctx, state_at_server, state_at_backup, "key2")
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
    let backend = @moonchor.make_local_backend([server, client, backup])
    group.spawn_bg(() => @moonchor.run_choreo(backend, kvstore, server))
    group.spawn_bg(() => @moonchor.run_choreo(backend, kvstore, client))
    group.spawn_bg(() => @moonchor.run_choreo(backend, kvstore, backup))
  })
}
