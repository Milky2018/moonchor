///|
pub trait Logger {
  fn info(Self, String) -> Unit
}

///|
struct ConsoleLogger {}

///|
pub fn make_console_logger() -> ConsoleLogger {
  ConsoleLogger::{ }
}

///|
pub impl Logger for ConsoleLogger with fn info(_self, msg) {
  println("[INFO] \{msg}")
}

///|
struct MuteLogger {}

///|
pub impl Logger for MuteLogger with fn info(_self, _msg) {
  // Do nothing
}

///|
pub fn make_mute_logger() -> MuteLogger {
  MuteLogger::{ }
}

///|
pub extend ConsoleLogger with Logger::{info}

///|
pub extend MuteLogger with Logger::{info}
