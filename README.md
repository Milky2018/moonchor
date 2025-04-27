# Moonchor: Choreographic Programming Library for MoonBit

# Installation

```bash
moon add Milky2018/moonchor
```

# Examples

Check [examples](src/examples/)

# Basic APIs

```moonbit
trait Location: Show + Hash {
  name(Self) -> String
}

fn make_local_backend(
  locations : Array[&Location],
  logger~ : &Logger = make_mute_logger()
) -> Backend

async fn run_choreo[T, L : Location](
  backend : Backend,
  choreography : (ChoreoContext) -> T!Async,
  role : L,
  logger? : &Logger
) -> T 
```

For example, you can define some roles/locations by implementing the `Location` trait:

```moonbit
struct Alice {}
struct Bob {}
impl Location for Alice with name(_) { "Alice" }
impl Location for Bob with name(_) { "Bob" }
let alice : Alice = Alice::{ }
let bob : Bob = Bob::{ }
```

Define a simple choreography: Alice --msg-> Bob 

```moonbit
async fn simple_choreo(ctx: ChoreoContext) -> Unit {
  let msg_at_alice = ctx.locally(alice, fn (_) { "Hello" })
  let msg_at_bob = ctx.comm(alice, bob, msg_at_alice)
  ctx.locally(bob, fn (unwrapper) { println(unwrapper.unwrap(msg_at_bob)) })
}
```

Then you can run the choreography:

```moonbit
let backend = make_local_backend([alice, bob])
run_choreo!(backend, simple_choreo, alice)
// or  run_choreo!(backend, simple_choreo, bob)
```

# Todo

- [x] README
- [ ] HTTP backend
- [x] Broadcast and choice of knowledge

# Further Readings

[Introduction to Choreographies](https://www.fabriziomontesi.com/introduction-to-choreographies/)

[HasChor](https://github.com/gshen42/HasChor.git)