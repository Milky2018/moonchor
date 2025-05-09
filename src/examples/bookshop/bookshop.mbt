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
async fn bookshop_v1(ctx : @moonchor.ChoreoContext) -> Unit {
  let title_at_buyer = ctx.locally(buyer, fn(_unwrapper) { get_title() })
  let title_at_seller = ctx.comm!(buyer, seller, title_at_buyer)
  let price_at_seller = ctx.locally(seller, fn(unwrapper) {
    let title = unwrapper.unwrap(title_at_seller)
    get_price(title)
  })
  let price_at_buyer = ctx.comm!(seller, buyer, price_at_seller)
  let decision_at_buyer = ctx.locally(buyer, fn(unwrapper) {
    let price = unwrapper.unwrap(price_at_buyer)
    if price < get_budget() {
      println("I will buy the book")
      true
    } else {
      println("I will not buy the book")
      false
    }
  })
  let decision_at_seller = ctx.comm!(buyer, seller, decision_at_buyer)
  ctx.locally(seller, fn(unwrapper) {
    let decision = unwrapper.unwrap(decision_at_seller)
    if decision {
      println("I will sell the book")
    } else {
      println("I will not sell the book")
    }
  })
  |> ignore
}

///|
async fn bookshop_v2(ctx : @moonchor.ChoreoContext) -> Unit {
  let title_at_buyer = ctx.locally(buyer, fn(_unwrapper) { get_title() })
  let title_at_seller = ctx.comm!(buyer, seller, title_at_buyer)
  let price_at_seller = ctx.locally(seller, fn(unwrapper) {
    let title = unwrapper.unwrap(title_at_seller)
    get_price(title)
  })
  let price_at_buyer = ctx.comm!(seller, buyer, price_at_seller)
  let decision_at_buyer = ctx.locally(buyer, fn(unwrapper) {
    let price = unwrapper.unwrap(price_at_buyer)
    price < get_budget()
  })
  if ctx.announce!(buyer, decision_at_buyer) {
    let delivery_date_at_seller = ctx.locally(seller, fn(unwrapper) {
      println("I will sell the book")
      get_delivery_date(unwrapper.unwrap(title_at_seller))
    })
    let delivery_date_at_buyer = ctx.comm!(
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
  //   I will not buy the book
  //   I will not sell the book
  let backend = @moonchor.make_local_backend([buyer, seller])
  @moonchor.run_async(async fn() {
    @moonchor.run_choreo!(backend, bookshop_v1, buyer)
  })
  @moonchor.run_async(async fn() {
    @moonchor.run_choreo!(backend, bookshop_v1, seller)
  })
}

///|
test "bookshop 2.0" {
  // Should print: 
  //   I will sell the book
  //   The book will be delivered on 2025-10-01
  let backend = @moonchor.make_local_backend([buyer, seller],
    // logger=make_console_logger(),
  )
  @moonchor.run_async(async fn() {
    @moonchor.run_choreo!(backend, bookshop_v2, buyer)
  })
  @moonchor.run_async(async fn() {
    @moonchor.run_choreo!(backend, bookshop_v2, seller)
  })
}
