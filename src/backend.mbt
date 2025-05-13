///|
enum Backend {
  Local(
    Array[&Location],
    Map[(&Location, &Location), @channel.T[Json]],
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
  Local(locations, channels, logger)
}

///|
async fn send[From : Location, To : Location, T : Message](
  self : Backend,
  from : From,
  to : To,
  msg : T
) -> Unit {
  match self {
    Local(_locations, channels, logger) => {
      logger.info("|BACKEND|\{from.name()}.send(msg, \{to.name()})")
      let channel = channels[(from, to)].unwrap()
      channel.push!(msg.to_json())
    }
  }
}

///|
async fn recv[From : Location, To : Location, T : Message](
  self : Backend,
  from : From,
  to : To
) -> T {
  match self {
    Local(_locations, channels, logger) => {
      logger.info("|BACKEND|\{to.name()}.recv(\{from.name()})")
      let channel = channels[(from, to)].unwrap()
      let msg = channel.pop!()
      try {
        let value = @json.from_json!(msg)
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

///|
fn Backend::register[L : Location](self : Backend, loc : L) -> Unit {
  match self {
    Local(locations, channels, logger) => {
      logger.info("|BACKEND|Registering \{loc.name()}")
      locations.push(loc)
      for from in locations {
        let channel = @channel.make()
        channels[(from, loc)] = channel
      }
      for to in locations {
        let channel = @channel.make()
        channels[(loc, to)] = channel
      }
    }
  }
}

///|
fn Backend::evict[L : Location](self : Backend, loc : L) -> Unit {
  match self {
    Local(locations, channels, logger) => {
      logger.info("|BACKEND|Evicting \{loc.name()}")
      locations.retain(fn(l) { l == loc })
      for from in locations {
        channels.remove((from, loc))
      }
      for to in locations {
        channels.remove((loc, to))
      }
    }
  }
}

// fn Backend::handle_register(self : Backend) -> &Location {

// }