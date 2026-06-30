sealed class DownloadState {}

class Queued extends DownloadState {}

class Downloading extends DownloadState {}

class Verifying extends DownloadState {}

class Installing extends DownloadState {}

class Completed extends DownloadState {}

class Failed extends DownloadState {
  Failed(this.error);
  final String error;
}

class Cancelled extends DownloadState {}

class Paused extends DownloadState {}

class Retrying extends DownloadState {}
