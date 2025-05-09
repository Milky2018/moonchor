///|
priv struct Worker {
  id : String
} derive(Eq, Show, Hash, ToJson, FromJson)

///|
impl @moonchor.Location for Worker with name(self) {
  self.id
}
