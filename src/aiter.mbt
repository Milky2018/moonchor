///|
type AIter[T] Iter[T]

///|
pub fn into_aiter[T](iter : Iter[T]) -> AIter[T] {
  AIter(iter)
}

///|
pub async fn AIter::each[T](self : AIter[T], f : async (T) -> Unit) -> Unit {
  let fst = self._.head()
  if fst is Some(v) {
    f!(v)
    AIter::each!(self._[1:], f)
  }
}

///|
type AIter2[A, B] Iter[(A, B)]

///|
pub fn into_aiter2[A, B](iter : Iter2[A, B]) -> AIter2[A, B] {
  AIter2(iter.iter())
}

///|
pub async fn AIter2::each[A, B](
  self : AIter2[A, B],
  f : async (A, B) -> Unit
) -> Unit {
  AIter::each!(self._, async fn(ab) { f!(ab.0, ab.1) })
}

///|
test "Async print arrays" {
  async fn print(i : Int) {
    println("Element: \{i}")
  }

  @promise.spawn(async fn(_) { ([1, 2, 3].iter() |> into_aiter).each!(print) })
  |> ignore
}
