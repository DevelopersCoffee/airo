# Xtream Codes source contract

Airo TV treats Xtream Codes as a bring-your-own-content source. Users must
have authorization from their provider.

## Setup and storage

The TV source form verifies the server, username, and password before saving
the source. Rejected or expired accounts create neither a source record nor a
credential record, and the verification mutation disables automatic retries.

The non-secret source record contains:

- a generated stable source ID;
- the provider server URL and user label;
- account status, expiry, and maximum connections when supplied.

The username and password are stored only through
`ContentSourceCredentialStore` in the host platform's secure storage. They are
never written into preferences or interpolated into diagnostic messages.
Provider stream URLs necessarily contain credentials for playback, so refresh
failures deliberately log only the stable source ID.

## Channel and guide lifecycle

An active Xtream source contributes channels to the normal IPTV channel
provider. Provider category IDs are resolved through `get_live_categories`;
unknown IDs use `Uncategorized`. Channel IDs include the stable source ID so
two providers with the same numeric stream ID cannot collide.

After a successful channel refresh, `XtreamEpgRepository` is registered as a
named compact-guide source. It uses bounded `get_short_epg` requests for the
visible channel IDs. Removing the source deletes its secure credentials,
invalidates its channels, and removes its named guide repository.

Network or provider failure is isolated to that source. Other catalog, M3U,
and XMLTV sources remain available.
