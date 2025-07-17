///|
priv struct Client {} derive(Show, Hash)

///|
priv struct ClientState {
  inputs : Array[Int]
  outputs : Array[Int]
}

///|
fn ClientState::new() -> ClientState {
  { inputs: load_data(), outputs: [] }
}

///|
fn data_process_stage(x : Int) -> Int {
  x + 1
}

///|
fn load_data() -> Array[Int] {
  [3, 2, 1, 0]
}

///|
impl @moonchor.Location for Client with name(_) {
  "client"
}
