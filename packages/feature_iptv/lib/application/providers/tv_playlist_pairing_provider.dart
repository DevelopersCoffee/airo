import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/tv_playlist_pairing_server.dart';

/// Factory, not a singleton -- a fresh [TvPlaylistPairingServer] per QR
/// pairing attempt. Providing the constructor (rather than an instance)
/// keeps the server's lifecycle owned by the dialog that starts/stops it,
/// while still giving tests a seam to inject a loopback-bound fake.
final tvPlaylistPairingServerFactoryProvider =
    Provider<TvPlaylistPairingServer Function()>((ref) {
      return TvPlaylistPairingServer.new;
    });
