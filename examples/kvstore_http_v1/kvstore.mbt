///|
fn ascii_to_string(ascii : BytesView) -> String {
  let builder = StringBuilder::new()
  for byte in ascii {
    match byte {
      '\n' => builder.write_char('\n')
      '\r' => builder.write_string("\\r")
      '\t' => builder.write_string("\\t")
      32..=126 => builder.write_char(byte.to_int().unsafe_to_char())
      x =>
        builder
        ..write_string("\\x")
        ..write_string(x.to_int().to_string(radix=16))
    }
  }
  builder.to_string()
}

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
} derive(ToJson, FromJson, Show)

///|
typealias Int? as Response

///|
async fn handle_request(state : ServerState, request : Request) -> Response {
  @pipe.stdout.write("Processing request: \{request}\n")
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
typealias async (@moonchor.ChoreoContext, @moonchor.Located[Request, Server]) -> @moonchor.Located[
  Response,
  Server,
] as ReplicationStrategy

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
  let stdin_reader = @io.BufferedReader::new(@pipe.stdin)
  for {
    let command_at_client = ctx.locally(client, fn(_unwrapper) {
      @pipe.stdout.write("> ")
      let newline_pos = stdin_reader.find(b"\n")
      let line_bytes = stdin_reader.read_exactly(newline_pos)
      stdin_reader.drop(1)
      let line = ascii_to_string(line_bytes)
      let cmd = line.split(" ").collect()
      guard cmd.length() > 1 else { return Request::Get("") }
      let key = cmd[1].to_string()
      match cmd[0].to_string() {
        "put" => Request::Put(key, try! @strconv.parse_int(cmd[2]))
        "get" => Request::Get(key)
        _ => Request::Get("")
      }
    })
    let response_at_client = access_server(ctx, command_at_client, strategy)
    ctx.locally(client, fn(unwrapper) {
      let response = unwrapper.unwrap(response_at_client)
      match response {
        None => @pipe.stdout.write("ok\n")
        Some(i) => @pipe.stdout.write("\{i}\n")
      }
    })
    |> ignore
  }
}

///|
async fn main {
  @async.with_task_group(fn(group) {
    let backend = @moonchor.make_http_backend(
      [
        (server, @socket.Addr::parse("127.0.0.1:8080")),
        (client, @socket.Addr::parse("127.0.0.1:8081")),
        (backup1, @socket.Addr::parse("127.0.0.1:8082")),
        (backup2, @socket.Addr::parse("127.0.0.1:8083")),
      ],
      group,
      // logger=@moonchor.make_console_logger(),
    )
    let args = @sys.get_cli_args()
    match args.get(1) {
      Some("server") => @moonchor.run_choreo(backend, kvstore, server)
      Some("client") => @moonchor.run_choreo(backend, kvstore, client)
      Some("backup1") => @moonchor.run_choreo(backend, kvstore, backup1)
      Some("backup2") => @moonchor.run_choreo(backend, kvstore, backup2)
      _ => @pipe.stdout.write("server, client, backup1, backup2\n")
    }
  })
}

///|
test {
  let data : Response = Some(1)
  let json = data.to_json()
  let msg : Response = @json.from_json(json)
  println(msg)
}
