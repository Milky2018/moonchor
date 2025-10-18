///|
enum Backend {
  Local(
    Array[&Location],
    Map[(&Location, &Location), @aqueue.Queue[Json]],
    &Logger
  )
  // HttpConfig
}

///|
pub fn get_logger(self : Backend) -> &Logger {
  match self {
    Local(_, _, logger) => logger
  }
}

///|
pub fn get_locations(self : Backend) -> Array[&Location] {
  match self {
    Local(locations, _, _) => locations
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
async fn[From : Location, To : Location, T : Message] send(
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
  }
}

///|
async fn[From : Location, To : Location, T : Message] recv(
  self : Backend,
  from : From,
  to : To,
) -> T {
  match self {
    Local(_locations, channels, logger) => {
      logger.info("|BACKEND|\{to.name()}.recv(\{from.name()})")
      let channel = channels
        .get((from, to))
        .unwrap_or_else(fn() {
          abort("Channel (\{from.name()}, \{to.name()}) not found")
        })
      let msg = channel.get()
      try {
        let value = @json.from_json(msg)
        return value
      } catch {
        _ => abort("Bug: deserialzing JSON failed. " + CONTACT_AUTHOR)
      }
    }
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
