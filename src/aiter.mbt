///|
async fn async_each[T](iter : Iter[T], f : (T) -> Unit!Async) -> Unit {
  let fst = iter.head()
  if fst is Some(v) {
    f!(v)
    async_each!(iter[1:], f)
  }
}

///|
async fn async_each2[A, B](
  iter : Iter2[A, B],
  f : (A, B) -> Unit!Async
) -> Unit {
  async_each!(iter.iter(), fn(ab) {
    let a = ab.0
    let b = ab.1
    f!(a, b)
  })
}

///|
test "Async print arrays" {
  async fn print(i : Int) {
    println("Element: \{i}")
  }

  @promise.spawn(async fn(_) { [1, 2, 3].iter() |> async_each!(print) })
  |> ignore
}
