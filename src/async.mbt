///|
pub async fn suspend[A](f : ((A) -> Unit) -> Unit) -> A = "%async.suspend"

///|
pub async fn suspend_err[A](f : ((A) -> Unit, (Error) -> Unit) -> Unit) -> A! = "%async.suspend"

///|
pub fn run_async(f : () -> Unit!Async) -> Unit = "%async.run"
