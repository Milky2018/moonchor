///|
/// Types that can be (de)serialized. Now only JSON is supported.
pub(open) trait Message: ToJson + @json.FromJson {}

///|
pub impl Message for Int
