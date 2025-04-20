///|
priv struct Buyer {} derive(Eq, Show, Hash)

///|
impl Location for Buyer with name(_) {
  "buyer"
}

///|
priv struct Seller {} derive(Eq, Show, Hash)

///|
impl Location for Seller with name(_) {
  "seller"
}

///|
fn get_title() -> String {
  "Homotopy Type Thoery"
}

///|
fn get_price(_title : String) -> Int {
  50
}

///|
async fn bookshop1(ctx : ChoreoContext) -> Unit {
  let buyer = Buyer::{  }
  let seller = Seller::{  }
  let title_at_buyer = ctx.locally(buyer, fn(_unwrapper) { get_title() })
  let title_at_seller = ctx.comm!(buyer, seller, title_at_buyer)
  let price_at_seller = ctx.locally(seller, fn(unwrapper) {
    let title = unwrapper.unwrap(title_at_seller)
    get_price(title)
  })
  let price_at_buyer = ctx.comm!(seller, buyer, price_at_seller)
  let decision = ctx.locally(buyer, fn(unwrapper) {
    let price = unwrapper.unwrap(price_at_buyer)
    if price < 40 {
      println("I will buy the book")
      true
    } else {
      println("I will not buy the book")
      false
    }
  })
  let decision_at_seller = ctx.comm!(buyer, seller, decision)
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
test "bookshop 1.0" {
  // Should print: 
  //   I will not buy the book
  //   I will not sell the book
  let buyer = Buyer::{  }
  let seller = Seller::{  }
  let config = make_local_config([buyer, seller])
  let _buyer_handler = @promise.spawn(async fn(_) {
    run_choreo!(config, bookshop1, buyer)
  })
  let _seller_handler = @promise.spawn(async fn(_) {
    run_choreo!(config, bookshop1, seller)
  })
}
