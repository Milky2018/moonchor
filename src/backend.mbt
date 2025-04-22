///|
enum Backend {
  Local(Map[(&Location, &Location), @channel.T[Json]], &Logger)
  // HttpConfig
}

///|
pub fn get_logger(self : Backend) -> &Logger {
  match self {
    Local(_, logger) => logger
  }
}

///|
pub fn check_location(self : Backend, loc : &Location) -> Bool {
  match self {
    Local(channels, _) =>
      channels.keys().any(fn(from_to) { from_to.0 == loc || from_to.1 == loc })
  }
}

///|
pub fn make_local_backend(
  locations : Array[&Location],
  logger~ : &Logger = make_mute_logger()
) -> Backend {
  let channels = {}
  for from in locations {
    for to in locations {
      if from != to {
        let channel = @channel.make()
        channels[(from, to)] = channel
      }
    }
  }
  Local(channels, logger)
}

///|
async fn send[From : Location, To : Location, T : ToJson + @json.FromJson](
  self : Backend,
  from : From,
  to : To,
  msg : T
) -> Unit {
  match self {
    Local(channels, logger) => {
      logger.info("|BACKEND|\{from.name()}.send(msg, \{to.name()})")
      let channel = channels[(from, to)].unwrap()
      channel.push!(msg.to_json())
    }
  }
}

///|
async fn recv[From : Location, To : Location, T : ToJson + @json.FromJson](
  self : Backend,
  from : From,
  to : To
) -> T {
  match self {
    Local(channels, logger) => {
      logger.info(
        "|BACKEND|\{to.name()}.recv(\{from.name()})",
      )
      let channel = channels[(from, to)].unwrap()
      let msg = channel.pop!()
      try {
        let value = @json.from_json!(msg)
        return value
      } catch {
        _ => abort("Bug: deserialzing JSON failed. " + CONTACT_AUTHOR)
      }
    }
  }
}

///|
struct Unwrapper[_] {}

///|
pub fn Unwrapper::unwrap[T, L](_ : Unwrapper[L], v : Located[T, L]) -> T {
  unwrap(v)
}

///|
fn Backend::run[L : Location, T](
  self : Backend,
  loc : L,
  computation : (Unwrapper[L]) -> T
) -> T {
  let logger = self.get_logger()
  logger.info("|BACKEND|\{loc.name()}.run(computation)")
  let unwrapper = Unwrapper::{  }
  computation(unwrapper)
}

///|
async fn broadcast[From : Location, T : ToJson + @json.FromJson](
  self : Backend,
  from : From,
  msg : T
) -> Unit {
  match self {
    Local(channels, logger) => {
      logger.info("|BACKEND|\{from.name()}.broadcast(msg)")
      channels.iter2()
      |> async_each2!(async fn(from_to, channel) {
        if from_to.0 == from {
          channel.push!(msg.to_json())
        }
      })
    }
  }
}
