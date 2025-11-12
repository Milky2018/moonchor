///|
struct Backend {
  locations : Array[&Location]
  logger : &Logger
  group : @async.TaskGroup[Unit]
  messager : Messager
}

///|
priv enum Messager {
  Local(Map[(&Location, &Location), @aqueue.Queue[Json]])
  Http(Map[&Location, @socket.Addr], Map[String, @aqueue.Queue[Json]])
}

///|
pub fn make_local_backend(
  locations : Array[&Location],
  group : @async.TaskGroup[Unit],
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
  { locations, group, logger, messager: Local(channels) }
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
  { locations, logger, group, messager: Http(addrs, mails) }
}

///|
pub async fn[L : Location] Backend::init_at(self : Backend, role : L) -> Unit {
  match self.messager {
    Local(_) => ()
    Http(addrs, mails) => {
      let oneshot = @async.Queue::new()
      let addr = addrs
        .get(role)
        .unwrap_or_else(fn() { abort("Address for role: \{role} not found") })
      self.group.spawn_bg(allow_failure=true, fn() {
        try {
          let server = @socket.TcpServer::new(addr)
          self.logger.info("|BACKEND_HTTP|TCP Server established at \{addr}")
          oneshot.put(())
          defer server.close()
          defer self.logger.info("|BACKEND_HTTP|TCP Server closing")
          for {
            let (conn, addr) = server.accept()
            self.logger.info("|BACKEND_HTTP|CONNECTION accepted from \{addr}")
            let conn = @http.ServerConnection::new(conn)
            conn.read_request() |> ignore
            let data = conn.read_all()
            let json = data.json()
            let msg = json.value("msg").unwrap()
            let from = json.value("from").unwrap().as_string().unwrap()
            self.logger.info("|BACKEND_HTTP|TCP receive: \{msg} from \{from}")
            conn..send_response(200, "Success")..end_response()
            mails
            .get(from)
            .unwrap_or_else(() => abort("No mail for location: \{from}"))
            .put(msg)
            self.logger.info("|BACKEND_HTTP|CONNECTION closing")
            conn.close()
          }
        } catch {
          e => abort("Error: \{e}")
        }
      })
      oneshot.get() |> ignore
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
  match self.messager {
    Local(channels) => {
      self.logger.info("|BACKEND|send(msg, \{from.name()}, \{to.name()})")
      let channel = channels
        .get((from, to))
        .unwrap_or_else(fn() {
          abort("Channel (\{from.name()}}, \{to.name()}) not found")
        })
      channel.put(msg.to_json())
    }
    Http(addrs, _mails) => {
      let addr = addrs
        .get(to)
        .unwrap_or_else(fn() { abort("Addr \{to.name()} not found") })
      let data : Json = { "from": from.name(), "msg": msg }
      self.logger.info(
        "|BACKEND|send \{data} to \{to.name()} (http://\{addr_ipstring(addr)})",
      )
      let response = @http.post(
        "http://\{addr_ipstring(addr)}",
        data,
        port=addr.port(),
      )
      self.logger.info("|BACKEND|Response code: \{response.0.code}")
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
  let msg = match self.messager {
    Local(channels) => {
      self.logger.info("|BACKEND|\{to.name()}.recv(\{from.name()})")
      let channel = channels
        .get((from, to))
        .unwrap_or_else(fn() {
          abort("Channel (\{from.name()}, \{to.name()}) not found")
        })
      channel.get()
    }
    Http(_addrs, mails) => {
      self.logger.info("|BACKEND_HTTP|\{to.name()}.recv(\{from.name()})")
      let mail = mails
        .get(from.name())
        .unwrap_or_else(fn() { abort("Mail \{from.name()} not found") })
      let msg = mail.get()
      self.logger.info("|BACKEND_HTTP|MSG: \{msg})")
      msg
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
pub async fn[T, L] Unwrapper::unwrap_async(
  _ : Unwrapper[L],
  v : AsyncLocated[T, L],
) -> T {
  v.unwrap()
}

///|
async fn[L : Location, T] Backend::run(
  self : Backend,
  loc : L,
  computation : async (Unwrapper[L]) -> T,
) -> T {
  self.logger.info("|BACKEND|\{loc.name()}.run(computation)")
  let unwrapper = Unwrapper::{  }
  computation(unwrapper)
}
