///|
enum Backend {
  Local(
    Array[&Location],
    Map[(&Location, &Location), @aqueue.Queue[Json]],
    &Logger
  )
  Http(
    Array[&Location],
    Map[&Location, @socket.Addr],
    Map[String, @aqueue.Queue[Json]],
    @async.TaskGroup[Unit],
    &Logger
  )
}

///|
pub fn Backend::get_logger(self : Backend) -> &Logger {
  match self {
    Local(_, _, logger) => logger
    Http(_, _, _, _, logger) => logger
  }
}

///|
pub fn Backend::get_locations(self : Backend) -> Array[&Location] {
  match self {
    Local(locations, _, _) => locations
    Http(locations, _, _, _, _) => locations
  }
}

///|
pub fn make_local_backend(
  locations : Array[&Location],
  logger? : &Logger = make_mute_logger(),
) -> Backend {
  let channels = {}
  for from in locations {
    for to in locations {
      if from != to {
        channels[(from, to)] = @aqueue.Queue::new()
      }
    }
  }
  Local(locations, channels, logger)
}

///|
pub fn make_http_backend(
  location_addrs : Array[(&Location, @socket.Addr)],
  group : @async.TaskGroup[Unit],
  logger? : &Logger = make_mute_logger(),
) -> Backend {
  let locations = []
  let addrs = {}
  let mails = {}
  for loc in location_addrs {
    addrs[loc.0] = loc.1
    mails[loc.0.name()] = @aqueue.Queue::new()
    locations.push(loc.0)
  }
  Http(locations, addrs, mails, group, logger)
}

///|
pub async fn[L : Location] Backend::init_at(self : Backend, role : L) -> Unit {
  match self {
    Local(_) => ()
    Http(_locations, addrs, mails, group, logger) => {
      let addr = addrs
        .get(role)
        .unwrap_or_else(fn() { abort("Address for role: \{role} not found") })
      group.spawn_bg(allow_failure=true, fn() {
        try {
          let server = @socket.TCPServer::new(addr)
          logger.info("|Backend-http|TCP Server established")
          defer server.close()
          defer logger.info("|Backend-http|TCP Server closing")
          for {
            let (conn, addr) = server.accept()
            logger.info("|Backend-http|CONNECTION accepted from \{addr}")
            let conn = @http.ServerConnection::new(conn)
            defer conn.close()
            defer logger.info("|Backend-http|CONNECTION closing")
            conn.read_request() |> ignore
            let data = conn.read_all()
            let json = data.json()
            let msg = json.value("msg").unwrap()
            let from = json.value("from").unwrap().as_string().unwrap()
            logger.info("|Backend-http|TCP receive: \{msg} from \{from}")
            mails
            .get(from)
            .unwrap_or_else(() => abort("No mail for location: \{from}"))
            .put(msg)
            conn..send_response(200, "Success")..end_response()
          }
        } catch {
          e => {
            logger.info("|Backend-http|Error: \{e}")
            raise e
          }
        }
      })
    }
  }
}

///|
async fn[From : Location, To : Location, T : Message] Backend::send(
  self : Backend,
  from : From,
  to : To,
  msg : T,
) -> Unit {
  match self {
    Local(_locations, channels, logger) => {
      logger.info("|BACKEND|send(msg, \{from.name()}, \{to.name()})")
      let channel = channels
        .get((from, to))
        .unwrap_or_else(fn() {
          abort("Channel (\{from.name()}}, \{to.name()}) not found")
        })
      channel.put(msg.to_json())
    }
    Http(_locations, addrs, _mails, _group, logger) => {
      logger.info("|BACKEND|send(msg, \{from.name()}, \{to.name()})")
      let addr = addrs
        .get(to)
        .unwrap_or_else(fn() { abort("Addr \{to.name()} not found") })
      let data : Json = { "from": from.name(), "msg": msg }
      let response = @http.post(
        "http://\{addr_ipstring(addr)}",
        data,
        port=addr.port(),
      )
      logger.info("|BACKEND|Response code: \{response.0.code}")
    }
  }
}

///|
fn addr_ipstring(addr : @socket.Addr) -> String {
  let ip = addr.ip()
  StringBuilder::new()
  ..write_object(ip >> 24)
  ..write_char('.')
  ..write_object((ip >> 16) & 255)
  ..write_char('.')
  ..write_object((ip >> 8) & 255)
  ..write_char('.')
  ..write_object(ip & 255)
  .to_string()
}

///|
async fn[From : Location, To : Location, T : Message] Backend::recv(
  self : Backend,
  from : From,
  to : To,
) -> T {
  let msg = match self {
    Local(_locations, channels, logger) => {
      logger.info("|BACKEND|\{to.name()}.recv(\{from.name()})")
      let channel = channels
        .get((from, to))
        .unwrap_or_else(fn() {
          abort("Channel (\{from.name()}, \{to.name()}) not found")
        })
      channel.get()
    }
    Http(_locations, _addrs, mails, _group, logger) => {
      logger.info("|BACKEND|\{to.name()}.recv(\{from.name()})")
      let mail = mails
        .get(from.name())
        .unwrap_or_else(fn() { abort("Mail \{from.name()} not found") })
      mail.get()
    }
  }
  try {
    let value = @json.from_json(msg)
    return value
  } catch {
    _ => abort("Bug: deserialzing JSON failed. " + CONTACT_AUTHOR)
  }
}

///|
/// The unwrapper is used to unwrap located values in the computation.
/// It is passed to the computation function as the only argument.
struct Unwrapper[_] {}

///|
/// Unwrap a located value.
pub fn[T, L] Unwrapper::unwrap(_ : Unwrapper[L], v : Located[T, L]) -> T {
  v.unwrap()
}

///|
fn[L : Location, T] Backend::run(
  self : Backend,
  loc : L,
  computation : (Unwrapper[L]) -> T,
) -> T {
  let logger = self.get_logger()
  logger.info("|BACKEND|\{loc.name()}.run(computation)")
  let unwrapper = Unwrapper::{  }
  computation(unwrapper)
}
