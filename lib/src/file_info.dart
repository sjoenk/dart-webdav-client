class FileInfo {
  final String name;
  final String path;
  final String href;
  final String size;
  final String mTime;
  final String cTime;
  final String contentType;
  final String eTag;

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
    pathParts.removeWhere((part) => part.isEmpty);
    return pathParts;
  }

  String get currentDirectory {
    List<String> pathParts = this.pathParts;
    if (this.isDirectory) {
      return pathParts?.last ?? "/";
    } else {
      return pathParts.length > 1 ? pathParts[pathParts.length - 2] : "/";
    }
  }

  bool get isDirectory => this.contentType == null;
  bool get isImageFile => this.contentType.contains("image");
  bool get isAudioFile => this.contentType.contains("audio");
  bool get isVideoFile => this.contentType.contains("video");
}
