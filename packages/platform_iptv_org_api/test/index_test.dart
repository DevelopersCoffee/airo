import 'package:platform_iptv_org_api/platform_iptv_org_api.dart';
import 'package:test/test.dart';

void main() {
  const channel = IptvOrgChannel(
    id: 'News.in',
    name: 'News',
    altNames: [],
    network: null,
    owners: [],
    country: 'IN',
    categories: ['news'],
    isNsfw: false,
    launched: null,
    closed: null,
    replacedBy: null,
    website: null,
  );

  IptvOrgSnapshot snapshot({
    List<IptvOrgFeed> feeds = const [],
    List<IptvOrgLogo> logos = const [],
    List<IptvOrgStream> streams = const [],
    List<IptvOrgGuide> guides = const [],
    List<IptvOrgBlocklistEntry> blocklist = const [],
    List<IptvOrgChannel> channels = const [channel],
  }) => IptvOrgSnapshot(
    channels: channels,
    feeds: feeds,
    logos: logos,
    streams: streams,
    guides: guides,
    categories: const [],
    languages: const [],
    countries: const [],
    subdivisions: const [],
    cities: const [],
    regions: const [],
    timezones: const [],
    blocklist: blocklist,
  );

  test('preferred feed honors exact area then main then stable id', () {
    final index = IptvOrgIndex(
      snapshot(
        feeds: const [
          IptvOrgFeed(
            channel: 'News.in',
            id: 'Main',
            name: 'Main',
            altNames: [],
            isMain: true,
            broadcastArea: ['c/IN'],
            timezones: [],
            languages: ['hin'],
            format: '576i',
          ),
          IptvOrgFeed(
            channel: 'News.in',
            id: 'Delhi',
            name: 'Delhi',
            altNames: [],
            isMain: false,
            broadcastArea: ['s/IN-DL'],
            timezones: [],
            languages: ['hin'],
            format: '1080p',
          ),
        ],
      ),
    );

    expect(
      index
          .preferredFeed('News.in', countryCode: 'IN', subdivisionCode: 'IN-DL')
          ?.id,
      'Delhi',
    );
    expect(index.preferredFeed('News.in', countryCode: 'IN')?.id, 'Main');
  });

  test('logo pick prefers feed, in-use, format, dimensions', () {
    final index = IptvOrgIndex(
      snapshot(
        logos: const [
          IptvOrgLogo(
            channel: 'News.in',
            feed: null,
            inUse: true,
            tags: [],
            width: 2000,
            height: 1000,
            format: 'PNG',
            url: 'https://example.com/global.png',
          ),
          IptvOrgLogo(
            channel: 'News.in',
            feed: 'Delhi',
            inUse: true,
            tags: [],
            width: 500,
            height: 250,
            format: 'SVG',
            url: 'https://example.com/delhi.svg',
          ),
        ],
      ),
    );

    expect(
      index.preferredLogo('News.in', feedId: 'Delhi')?.url,
      'https://example.com/delhi.svg',
    );
  });

  test('streams rank preferred feed then quality and preserve headers', () {
    final index = IptvOrgIndex(
      snapshot(
        streams: const [
          IptvOrgStream(
            channel: 'News.in',
            feed: 'Main',
            title: '4K',
            url: 'https://example.com/4k',
            referrer: null,
            userAgent: null,
            quality: '2160p',
            label: null,
          ),
          IptvOrgStream(
            channel: 'News.in',
            feed: 'Delhi',
            title: 'HD',
            url: 'https://example.com/hd',
            referrer: 'https://example.com/',
            userAgent: 'Airo fixture',
            quality: '1080p',
            label: null,
          ),
        ],
      ),
    );

    final result = index.streamsForChannel('News.in', preferredFeedId: 'Delhi');
    expect(result.first.url, 'https://example.com/hd');
    expect(result.first.referrer, 'https://example.com/');
    expect(result.first.userAgent, 'Airo fixture');
  });

  test('DMCA always blocks while NSFW follows explicit policy', () {
    const dmca = IptvOrgBlocklistEntry(
      channel: 'News.in',
      reason: IptvOrgBlockReason.dmca,
      rawReason: 'dmca',
      ref: 'https://example.com/dmca',
    );
    const nsfw = IptvOrgBlocklistEntry(
      channel: 'Adult.in',
      reason: IptvOrgBlockReason.nsfw,
      rawReason: 'nsfw',
      ref: 'https://example.com/nsfw',
    );
    final index = IptvOrgIndex(snapshot(blocklist: const [dmca, nsfw]));

    expect(index.isBlocked('News.in'), isTrue);
    expect(
      index.isBlocked('News.in', nsfwPolicy: IptvOrgNsfwPolicy.include),
      isTrue,
    );
    expect(index.isBlocked('Adult.in'), isTrue);
    expect(
      index.isBlocked('Adult.in', nsfwPolicy: IptvOrgNsfwPolicy.include),
      isFalse,
    );
  });
}
