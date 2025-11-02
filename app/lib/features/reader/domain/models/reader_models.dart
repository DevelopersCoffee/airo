import 'package:equatable/equatable.dart';

/// Reader series model (manga/anime)
class ReaderSeries extends Equatable {
  final String id;
  final String title;
  final String? description;
  final String? coverUrl;
  final String source; // 'mangadex', 'anilist', etc.
  final String? sourceId;
  final int totalChapters;
  final DateTime? lastUpdated;
  final DateTime addedAt;

  const ReaderSeries({
    required this.id,
    required this.title,
    this.description,
    this.coverUrl,
    required this.source,
    this.sourceId,
    this.totalChapters = 0,
    this.lastUpdated,
    required this.addedAt,
  });

  @override
  List<Object?> get props => [
        id,
        title,
        description,
        coverUrl,
        source,
        sourceId,
        totalChapters,
        lastUpdated,
        addedAt,
      ];
}

/// Reader chapter model
class ReaderChapter extends Equatable {
  final String id;
  final String seriesId;
  final int chapterNumber;
  final String? title;
  final List<String> pageUrls;
  final DateTime? publishedAt;
  final DateTime? downloadedAt;
  final bool isDownloaded;

  const ReaderChapter({
    required this.id,
    required this.seriesId,
    required this.chapterNumber,
    this.title,
    this.pageUrls = const [],
    this.publishedAt,
    this.downloadedAt,
    this.isDownloaded = false,
  });

  @override
  List<Object?> get props => [
        id,
        seriesId,
        chapterNumber,
        title,
        pageUrls,
        publishedAt,
        downloadedAt,
        isDownloaded,
      ];
}

/// Reader page model
class ReaderPage extends Equatable {
  final String id;
  final String chapterId;
  final int pageNumber;
  final String imageUrl;
  final String? localPath;
  final bool isDownloaded;

  const ReaderPage({
    required this.id,
    required this.chapterId,
    required this.pageNumber,
    required this.imageUrl,
    this.localPath,
    this.isDownloaded = false,
  });

  @override
  List<Object?> get props => [
        id,
        chapterId,
        pageNumber,
        imageUrl,
        localPath,
        isDownloaded,
      ];
}

/// Reader progress model
class ReaderProgress extends Equatable {
  final String id;
  final String seriesId;
  final int lastChapterRead;
  final int lastPageRead;
  final DateTime lastReadAt;

  const ReaderProgress({
    required this.id,
    required this.seriesId,
    required this.lastChapterRead,
    required this.lastPageRead,
    required this.lastReadAt,
  });

  @override
  List<Object?> get props => [
        id,
        seriesId,
        lastChapterRead,
        lastPageRead,
        lastReadAt,
      ];
}

/// Reader source interface
abstract interface class ReaderSource {
  /// Get source name
  String get name;

  /// Search series
  Future<List<ReaderSeries>> search(String query);

  /// Get series details
  Future<ReaderSeries> getSeries(String sourceId);

  /// Get chapters for series
  Future<List<ReaderChapter>> getChapters(String sourceId);

  /// Get pages for chapter
  Future<List<ReaderPage>> getPages(String chapterId);
}

/// Fake reader source for development
class FakeReaderSource implements ReaderSource {
  @override
  String get name => 'Fake Source';

  @override
  Future<List<ReaderSeries>> search(String query) async {
    return [
      ReaderSeries(
        id: '1',
        title: 'Sample Manga',
        description: 'A sample manga series',
        source: 'fake',
        totalChapters: 100,
        addedAt: DateTime.now(),
      ),
    ];
  }

  @override
  Future<ReaderSeries> getSeries(String sourceId) async {
    return ReaderSeries(
      id: sourceId,
      title: 'Sample Manga',
      description: 'A sample manga series',
      source: 'fake',
      totalChapters: 100,
      addedAt: DateTime.now(),
    );
  }

  @override
  Future<List<ReaderChapter>> getChapters(String sourceId) async {
    return [
      ReaderChapter(
        id: '1',
        seriesId: sourceId,
        chapterNumber: 1,
        title: 'Chapter 1',
        pageUrls: List.generate(20, (i) => 'https://example.com/page$i.jpg'),
      ),
    ];
  }

  @override
  Future<List<ReaderPage>> getPages(String chapterId) async {
    return List.generate(
      20,
      (i) => ReaderPage(
        id: '$i',
        chapterId: chapterId,
        pageNumber: i + 1,
        imageUrl: 'https://example.com/page$i.jpg',
      ),
    );
  }
}

