
abstract class StorageProvider {
  String get name;
}

abstract class KeyValueStore implements StorageProvider {}
abstract class DocumentStore implements StorageProvider {}
abstract class VectorStore implements StorageProvider {}
abstract class BlobStore implements StorageProvider {}
abstract class CacheStore implements StorageProvider {}
abstract class QueueStore implements StorageProvider {}
