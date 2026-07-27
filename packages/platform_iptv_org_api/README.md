# platform_iptv_org_api

Pure-Dart access to the public
[iptv-org API](https://github.com/iptv-org/api). The package validates all
thirteen endpoint shapes at the network/cache boundary, supports conditional
GET and offline last-good snapshots, and builds immutable relational indexes.

The public contract is additive and versioned as `IptvOrgApiV1`. Consumers
must use typed models and `IptvOrgIndex`; raw response maps are intentionally
not exposed.

```dart
final client = IptvOrgApiClient(
  transport: IoIptvOrgTransport(),
  cache: FileIptvOrgCache(Directory('/app/cache/iptv-org')),
);

final snapshot = await client.fetchSnapshot();
final index = IptvOrgIndex(snapshot);
final candidates = index.streamsForChannel('BBCOne.uk');
```

Responses larger than 50 KiB are decoded with `Isolate.run`, keeping JSON
parsing off the caller isolate without adding a Flutter dependency.
