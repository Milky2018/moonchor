///|
enum Backend {
  Local(Map[&Location, @guardch.GuardChannel[(Array[Int], Json)]], &Logger)
  // HttpConfig
}

///|
pub fn get_logger(self : Backend) -> &Logger {
  match self {
    Local(_, logger) => logger
  }
}

///|
pub fn get_locations(self : Backend) -> Array[&Location] {
  match self {
    Local(channels, _) => channels.keys().to_array()
  }
}

///|
pub fn make_local_backend(
  locations : Array[&Location],
  logger~ : &Logger = make_mute_logger()
) -> Backend {
  let channels = {}
  for location in locations {
    channels[location] = @guardch.GuardChannel::new()
  }
  Local(channels, logger)
}

///|
fn send[To : Location, T : Message](
  self : Backend,
  to : To,
  msg : T,
  id_list : Array[Int]
) -> Unit {
  match self {
    Local(channels, logger) => {
      logger.info("|BACKEND|send(msg, \{to.name()})")
      let channel = channels
        .get(to)
        .or_else(fn() { @tlk.alert("Channel \{to.name()} not found") })
      channel.send((id_list, msg.to_json()))
    }
  }
}

///|
async fn recv[To : Location, T : Message](
  self : Backend,
  to : To,
  id_list : Array[Int]
) -> T {
  match self {
    Local(channels, logger) => {
      logger.info("|BACKEND|\{to.name()}.recv()")
      let channel = channels
        .get(to)
        .or_else(fn() { @tlk.alert("Channel \{to.name()} not found") })
      let msg = channel.recv!(fn(target) { target.0 == id_list })
      try {
        let value = @json.from_json!(msg.1)
        return value
      } catch {
        _ => @tlk.alert("Bug: deserialzing JSON failed. " + CONTACT_AUTHOR)
      }
    }
  }
}

///| The unwrapper is used to unwrap located values in the computation.
/// It is passed to the computation function as the only argument.
struct Unwrapper[_] {}

///| Unwrap a located value.
pub fn Unwrapper::unwrap[T, L](_ : Unwrapper[L], v : Located[T, L]) -> T {
  v.unwrap()
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

// fn Backend::register[L : Location](self : Backend, loc : L) -> Unit {
//   match self {
//     Local(channels, logger) => {
//       logger.info("|BACKEND|Registering \{loc.name()}")
//       let channel = 
//       channels[loc] = channel
//     }
//   }
// }

// fn Backend::evict[L : Location](self : Backend, loc : L) -> Unit {
//   match self {
//     Local(channels, logger) => {
//       logger.info("|BACKEND|Evicting \{loc.name()}")
//       channels.remove(loc)
//     }
//   }
// }
