///|
pub trait Logger {
  info(Self, String) -> Unit
}

///|
struct ConsoleLogger {}

///|
pub fn make_console_logger() -> ConsoleLogger {
  ConsoleLogger::{  }
}

///|
pub impl Logger for ConsoleLogger with info(_self, msg) {
  println("[INFO] \{msg}")
}

///|
struct MuteLogger {}

///|
pub impl Logger for MuteLogger with info(_self, _msg) {
  // Do nothing
}

///|
pub fn make_mute_logger() -> MuteLogger {
  MuteLogger::{  }
}
