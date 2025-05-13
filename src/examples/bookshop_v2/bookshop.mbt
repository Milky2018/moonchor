///|
priv struct Buyer {
  address : String
} derive(Eq, Show, Hash)

///|
impl @moonchor.Location for Buyer with name(self) {
  "buyer-" + self.address
}

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
async fn bookshop(ctx : @moonchor.ChoreoContext, buyer : Buyer) -> Unit {
  let title_at_buyer = ctx.pure(buyer, get_title())
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
  if ctx.broadcast!(buyer, decision_at_buyer) {
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
    ctx.pure(seller, println("I will not sell the book")) |> ignore
  }
}

///|
test "bookshop 2.0" {
  // let backend = @moonchor.make_local_backend([seller])
  // @kit.run_async(async fn() {
  //   @moonchor.serve_choreo!(backend, bookshop, seller)
  // })
  // @kit.run_async(async fn() {
  //   let buyer1 = Buyer::{ address: "Rd1" }
  //   @moonchor.connect_choreo!(backend, bookshop, buyer1)
  // })
  // @kit.run_async(async fn() {
  //   let buyer2 = Buyer::{ address: "Rd2" }
  //   @moonchor.connect_choreo!(backend, bookshop, buyer2)
  // })
}
