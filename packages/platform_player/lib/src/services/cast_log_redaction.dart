/// Renders a URI for diagnostics as `scheme://host[:port]` only.
///
/// Paths and query strings are always dropped: phone-hosted media URLs carry
/// the session token in the path (CV-033) and the cast proxy carries its
/// access token in the query, so neither may ever reach logs.
String redactedUriForLog(Uri? uri) {
  if (uri == null) return 'none';
  final port = uri.hasPort ? ':${uri.port}' : '';
  return '${uri.scheme}://${uri.host}$port';
}
