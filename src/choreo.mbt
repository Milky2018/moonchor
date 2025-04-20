///|
enum Located[T, L] {
  Wrap(T)
  Empty
}

///|
fn expect[T, L](self : Located[T, L]) -> T {
  match self {
    Located::Wrap(t) => t
    Located::Empty =>
      abort(
        "Bug: unwrapping an empty value. This should never happen. " + CONTACT_AUTHOR,
      )
  }
}

///|
pub trait Location: Show + Hash {
  name(Self) -> String
}

///|
impl Eq for &Location with op_equal(self, other) {
  self.name() == other.name()
}

///|
struct Unwrapper[L] {}

///|
pub fn unwrap[T, L](self : Unwrapper[L], v : Located[T, L]) -> T {
  expect(v)
}

///|
struct ChoreoContext {
  location : &Location
  channels : Map[(&Location, &Location), @channel.T[Json]]
}

enum NetworkConfig {
  LocalConfig(Map[(&Location, &Location), @channel.T[Json]])
  HttpConfig // TODO: 
}

pub fn make_local_config(locations: Array[&Location]) -> NetworkConfig {
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

pub async fn run_choreo[T, L: Location](config: NetworkConfig, choreography: async (ChoreoContext) -> T, role: L) -> T {
  match config {
    LocalConfig(channels) => {
      let context = ChoreoContext::{
        location: role,
        channels: channels
      }
      choreography!(context)
    }
    _ => {
      abort("Unsupported network configuration")
    }
  }
}

///|
pub fn locally[T, L : Location](
  self : ChoreoContext,
  location : L,
  computation : (Unwrapper[L]) -> T
) -> Located[T, L] {
  if location as &Location == self.location {
    let unwrapper = Unwrapper::{  }
    let result = computation(unwrapper)
    return Located::Wrap(result)
  } else {
    return Located::Empty
  }
}

///|
pub async fn comm[T : @json.FromJson + ToJson, From : Location, To : Location](
  self : ChoreoContext,
  from : From,
  to : To,
  value : Located[T, From]
) -> Located[T, To] {
  if self.location == from {
    let channel = self.channels[(from, to)].unwrap()
    let value = expect(value)
    channel.push!(value.to_json())
    Located::Empty
  } else if self.location == to {
    let channel = self.channels[(from, to)].unwrap()
    let value = try {
      channel.pop!() |> @json.from_json!()
    } catch {
      _ =>
        abort(
          "Bug: deserialzing JSON failed. " + CONTACT_AUTHOR,
        )
    }
    Located::Wrap(value)
  } else {
    return Located::Empty
  }
}
