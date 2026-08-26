import 'dart:typed_data';

/// Guards the FRB DCO decoders that iOS AOT has SIGSEGV'd on.
///
/// A missing Vec<u8> or struct used to become a native field deref at
/// 0xf inside App.framework — not a Dart exception, so nothing could
/// catch it and the process died. Checking for null / the wrong runtime
/// type here turns that into a StateError the save path can surface.

/// Decode a rust Vec<u8> without assuming the wire value is a Uint8List.
Uint8List safeDecodeUint8List(dynamic raw, {String what = 'bytes'}) {
  if (raw == null) {
    throw StateError('$what: rust FFI returned null');
  }
  if (raw is Uint8List) return raw;
  if (raw is List<int>) return Uint8List.fromList(raw);
  throw StateError('$what: unexpected type ${raw.runtimeType}');
}

/// Decode a (u64, u64)-shaped DCO list, or null if the value is missing
/// or not a pair of integers. Callers that treat progress as optional
/// (the download poll) must not abort the isolate over a bad struct.
({BigInt transferred, BigInt total})? safeDecodeU64Pair(dynamic raw) {
  if (raw == null) return null;
  if (raw is! List || raw.length < 2) return null;
  final transferred = _asU64(raw[0]);
  final total = _asU64(raw[1]);
  if (transferred == null || total == null) return null;
  return (transferred: transferred, total: total);
}

BigInt? _asU64(dynamic raw) {
  if (raw == null) return null;
  if (raw is BigInt) return raw;
  if (raw is int) return BigInt.from(raw);
  return null;
}
