///|
enum NetworkConfig {
  LocalConfig(Map[(&Location, &Location), @channel.T[Json]])
  // HttpConfig
}

///|
pub fn make_local_config(locations : Array[&Location]) -> NetworkConfig {
  let channels = {}
  for from in locations {
    for to in locations {
      if from != to {
        let channel = @channel.make()
        channels[(from, to)] = channel
      }
    }
  }
  return LocalConfig(channels)
}

///|
pub async fn send[From : Location, To : Location, T : ToJson + @json.FromJson](
  self : NetworkConfig,
  from : From,
  to : To,
  msg : T
) -> Unit {
  match self {
    LocalConfig(channels) => {
      let channel = channels[(from, to)].unwrap()
      channel.push!(msg.to_json())
    }
  }
}

///|
pub async fn recv[From : Location, To : Location, T : ToJson + @json.FromJson](
  self : NetworkConfig,
  from : From,
  to : To
) -> T {
  match self {
    LocalConfig(channels) => {
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
pub fn run[L : Location, T](
  self : NetworkConfig,
  loc : L,
  computation : (Unwrapper[L]) -> T
) -> T {
  let unwrapper = Unwrapper::{  }
  computation(unwrapper)
}

///|
pub async fn broadcast[From : Location, T : ToJson + @json.FromJson](
  self : NetworkConfig,
  from : From,
  msg : T
) -> Unit {
  match self {
    LocalConfig(channels) =>
      channels.iter2()
      |> into_aiter2
      |> AIter2::each!(async fn(from_to, channel) {
        if from_to.0 == from {
          channel.push!(msg.to_json())
        }
      })
  }
}
