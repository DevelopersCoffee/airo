/// Shared bill-split domain models consumed by both the Bill Split feature
/// and Airo Coins' expense flows. Extracted so coins no longer reaches into
/// another app feature's internals (issue #1111 slice 4).
library;

export 'src/receipt_item.dart';
