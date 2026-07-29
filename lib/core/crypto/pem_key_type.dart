/// True when [pem]'s armor label marks a curve25519 key (Ed25519 identity or
/// HOODIK WRAPPING key) rather than a legacy RSA key.
///
/// Only RSA keys carry "RSA" in the `-----BEGIN <label>-----` line. Deciding by
/// the label is deliberate: scanning the whole PEM is wrong because a large
/// hybrid wrapping key's random base64 body contains the substring "RSA" about
/// 5% of the time, which would misclassify a curve key as RSA.
bool pemIsCurve(String pem) {
  final label =
      RegExp(r'-----BEGIN ([^-]+)-----').firstMatch(pem)?.group(1) ?? '';
  return pem.isNotEmpty && !label.toUpperCase().contains('RSA');
}
