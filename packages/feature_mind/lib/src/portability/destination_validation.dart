/// Whether free text naming a destination reads as something on the local
/// network rather than a remote service.
///
/// Surface 08 ("Portability · `.airobackup`",
/// `docs/superpowers/specs/2026-08-02-airo-mind-device-system-design.md`)
/// says it plainly: "No destination in the list is a server, because there
/// isn't one." [PackageDestination] already enforces that structurally --
/// there is no `cloud` variant to pick -- but a LAN peer's advertised name
/// or a chosen file/mount path is free text, and this is the second gate for
/// it: defence in depth against a peer name or path that has been spoofed,
/// mistyped, or resolves through some intermediary back to a hosted service.
const List<String> cloudDestinationMarkers = [
  'http://',
  'https://',
  's3.amazonaws.com',
  'storage.googleapis.com',
  'googleapis.com',
  'icloud.com',
  'dropbox.com',
  'onedrive',
  'drive.google.com',
  'blob.core.windows.net',
];

/// True when [target] contains none of [cloudDestinationMarkers].
///
/// [target] is whatever free text names the concrete destination for the
/// current step -- a peer's advertised device name, or a mount/file path for
/// "this device" and "USB drive". An empty string is local by default: no
/// text was volunteered to raise a flag.
bool isLocalDestinationTarget(String target) {
  final lower = target.toLowerCase();
  return !cloudDestinationMarkers.any(lower.contains);
}
