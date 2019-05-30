class FileInfo {
  final String name;
  final String href;
  final String size;
  final String mTime;
  final String cTime;
  final String contentType;
  final String eTag;

  FileInfo({
    this.name,
    this.href,
    this.size,
    this.mTime,
    this.cTime,
    this.contentType,
    this.eTag,
  });

  bool get isDirectory => this.contentType == null;
}
