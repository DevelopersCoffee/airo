// ignore_for_file: one_member_abstracts

abstract interface class Initializable {
  Future<void> initialize();
}

abstract interface class Disposable {
  Future<void> dispose();
}
