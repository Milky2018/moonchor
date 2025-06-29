///|
priv struct Buyer {} derive(Eq, Show, Hash)

///|
impl @moonchor.Location for Buyer with name(_) {
  "buyer"
}

///|
let buyer : Buyer = Buyer::{  }

///|
priv struct Seller {} derive(Eq, Show, Hash)

///|
impl @moonchor.Location for Seller with name(_) {
  "seller"
}

///|
let seller : Seller = Seller::{  }

///|
fn get_title() -> String {
  "Homotopy Type Thoery"
}

///|
fn get_price(_title : String) -> Int {
  50
}

///|
fn get_budget() -> Int {
  100
}

///|
fn get_delivery_date(_title : String) -> String {
  "2025-10-01"
}

///|
async fn bookshop(ctx : @moonchor.ChoreoContext) -> Unit {
  let title_at_buyer = ctx.locally(buyer, _unwrapper => get_title())
  let title_at_seller = ctx.comm(buyer, seller, title_at_buyer)
  let price_at_seller = ctx.locally(seller, fn(unwrapper) {
    let title = unwrapper.unwrap(title_at_seller)
    get_price(title)
  })
  let price_at_buyer = ctx.comm(seller, buyer, price_at_seller)
  let decision_at_buyer = ctx.locally(buyer, fn(unwrapper) {
    let price = unwrapper.unwrap(price_at_buyer)
    price < get_budget()
  })
  if ctx.broadcast(buyer, decision_at_buyer) {
    let delivery_date_at_seller = ctx.locally(seller, fn(unwrapper) {
      println("I will sell the book")
      get_delivery_date(unwrapper.unwrap(title_at_seller))
    })
    let delivery_date_at_buyer = ctx.comm(
      seller, buyer, delivery_date_at_seller,
    )
    ctx.locally(buyer, fn(unwrapper) {
      let delivery_date = unwrapper.unwrap(delivery_date_at_buyer)
      println("The book will be delivered on \{delivery_date}")
    })
    |> ignore
  } else {
    ctx.locally(seller, fn(_unwrapper) { println("I will not sell the book") })
    |> ignore
  }
}

///|
test "bookshop 1.0" {
  // Should print: 
  //   I will sell the book
  //   The book will be delivered on 2025-10-01
  let backend = @moonchor.make_local_backend([buyer, seller],
    // logger=make_console_logger(),
  )
  @tlk.run_async(async fn() { @moonchor.run_choreo(backend, bookshop, buyer) })
  @tlk.run_async(async fn() { @moonchor.run_choreo(backend, bookshop, seller) })
}
