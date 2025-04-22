///|
enum Located[T, _] {
  Wrap(T)
  Empty
}

///|
fn unwrap[T, L](self : Located[T, L]) -> T {
  match self {
    Located::Wrap(t) => t
    Located::Empty =>
      abort(
        "Bug: unwrapping an empty value. This should never happen. " +
        CONTACT_AUTHOR,
      )
  }
}

///|
pub(open) trait Location: Show + Hash {
  name(Self) -> String
}

///|
impl Eq for &Location with op_equal(self, other) {
  self.name() == other.name()
}

///|
struct ChoreoContext {
  location : &Location
  network : NetworkConfig
  // channels : Map[(&Location, &Location), @channel.T[Json]]
}

///|
pub async fn run_choreo[T, L : Location](
  config : NetworkConfig,
  choreography : async (ChoreoContext) -> T,
  role : L
) -> T {
  let context = ChoreoContext::{ location: role, network: config }
  choreography!(context)
}

///|
pub fn locally[T, L : Location](
  self : ChoreoContext,
  location : L,
  computation : (Unwrapper[L]) -> T
) -> Located[T, L] {
  if location as &Location == self.location {
    let result = self.network.run(location, computation)
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
    self.network.send!(from, to, unwrap(value))
    Located::Empty
  } else if self.location == to {
    Located::Wrap(self.network.recv!(from, to))
  } else {
    return Located::Empty
  }
}

///|
pub async fn condition[L : Location](
  self : ChoreoContext,
  loc : L,
  c : Located[Bool, L]
) -> Bool {
  if self.location == loc {
    let c = c.unwrap()
    self.network.broadcast!(loc, c)
    c
    // self.channels.iter2()
    // |> into_aiter2
    // |> AIter2::each!(async fn(from_to, channel) {
    //   if from_to.0 == loc {
    //     channel.push!(c.to_json())
    //   }
    // })
    // c
  } else {
    // let channel = self.channels[(loc, self.location)].unwrap()
    // let value = try {
    //   channel.pop!() |> @json.from_json!()
    // } catch {
    //   _ => abort("Bug: deserialzing JSON failed. " + CONTACT_AUTHOR)
    // }
    // value
    let value = self.network.recv!(loc, self.location)
    value 
  }
}
