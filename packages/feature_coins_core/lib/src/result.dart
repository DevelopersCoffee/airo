/// Outcome of a coins repository or use-case operation.
///
/// Deliberately a record typedef rather than `core_domain`'s sealed
/// `Result<T>`: coins call sites read `.data` / `.error` directly, and the
/// two designs serve different ergonomics. Nothing in coins imports
/// `core_domain`, so the names never collide. Previously this exact
/// declaration was duplicated in all 15 repository contracts and use
/// cases, which forced the package barrel to `hide Result` nine times.
typedef Result<T> = ({T? data, String? error});
