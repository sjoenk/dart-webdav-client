import 'http_date_time.dart';

class FileInfo {
  final String name;
  final String path;
  final String href;
  final String size;
  final String mTime;
  final String cTime;
  final String contentType;
  final String eTag;
  DateTime _dateTime;

  FileInfo({
    this.name,
    this.path,
    this.href,
    this.size,
    this.mTime,
    this.cTime,
    this.contentType,
    this.eTag,
  });

  List<String> get pathParts {
    List<String> pathParts = this.path.split('/');
    pathParts.removeWhere((part) => part.trim().isEmpty);
    return pathParts;
  }

  FileInfo get parentDirectory {
    List<String> pathParts = this.pathParts;
    if (pathParts.length > 1) {
      pathParts.removeLast();

      return FileInfo(
        name: Uri.decodeFull(pathParts.last),
        path: "/" + pathParts.join("/") + "/",
      );
    }

    return FileInfo(
      path: "/",
    );
  }

  DateTime get dateTime {
    return this._dateTime ?? (this._dateTime = HttpDateTime.tryParse(this.mTime));
  }

  bool get isDirectory => this.contentType == null;
  bool get isImageFile => this.contentType?.contains("image") ?? false;
  bool get isAudioFile => this.contentType?.contains("audio") ?? false;
  bool get isVideoFile => this.contentType?.contains("video") ?? false;
}
