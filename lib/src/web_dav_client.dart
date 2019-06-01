import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:retry/retry.dart';
import 'package:xml/xml.dart';
import 'package:meta/meta.dart';

import 'file_info.dart';

class WebDavClient {
  String baseUrl;
  String path;

  bool verifySsl = true;

  String currentDirectory = "/";

  HttpClient httpClient = HttpClient();

  WebDavClient({
    @required String host,
    @required String username,
    @required String password,
    this.path,
    String protocol = "https",
    int port,
  })  : assert(host != null),
        assert(username != null),
        assert(password != null) {
    this.baseUrl = "$protocol://" + _stripSlashes(host);

    if (port != null) {
      this.baseUrl += ":$port";
    }

    this.baseUrl += '/' + _stripSlashes(path);

    this.httpClient.addCredentials(
          Uri.parse(this.baseUrl),
          "",
          HttpClientBasicCredentials(username, password),
        );
  }

  String getUrl({String path = ""}) {
    if (path == null) {
      path = "";
    }
    if (path.startsWith('/')) {
      return this.baseUrl + path;
    }

    return [this.baseUrl, this.currentDirectory, path].join('');
  }

  /// change current directory to the given [path]
  void changeDirectory(String path) {
    if (path.isEmpty) {
      return;
    }

    if (path.startsWith('/')) {
      this.currentDirectory = path;
    } else {
      this.currentDirectory += path;
    }

    if (!this.currentDirectory.endsWith('/')) {
      this.currentDirectory += '/';
    }
  }

  /// make a dir with [path] under current dir
  Future<HttpClientResponse> makeDirectory(String path, [bool safe = true]) async {
    List<int> expectedCodes = [201];
    if (safe) {
      expectedCodes.addAll([301, 405]);
    }
    return await this._send('MKCOL', path, expectedCodes);
  }

  /// remove dir with given [path]
  Future<HttpClientResponse> remove(String path, [bool safe = true]) async {
    List<int> expectedCodes = [204];
    if (safe) {
      expectedCodes.addAll([204, 404]);
    }
    return await this._send('DELETE', path, expectedCodes);
  }

  /// upload a new file with [data] as content to [remotePath]
  Future<HttpClientResponse> upload(Uint8List data, String remotePath) async {
    return await this._upload(data, remotePath);
  }

  /// upload local file [path] to [remotePath]
  Future<HttpClientResponse> uploadFile(String path, String remotePath) async {
    return await this._upload(await File(path).readAsBytes(), remotePath);
  }

  /// download [remotePath] to local file [localFilePath]
  void download(String remotePath, String localFilePath) async {
    HttpClientResponse response = await this._send('GET', remotePath, [200]);
    await response.pipe(new File(localFilePath).openWrite());
  }

  /// download [remotePath] and store the response file contents to String
  Future<String> downloadToBinaryString(String remotePath) async {
    HttpClientResponse response = await this._send('GET', remotePath, [200]);
    return response.transform(utf8.decoder).join();
  }

  /// list the directories and files under given [remotePath]
  Future<List<FileInfo>> list({String remotePath}) async {
    Map userHeader = {"Depth": 1};
    HttpClientResponse response = await this._send('PROPFIND', remotePath, [207, 301], headers: userHeader);
    if (response.statusCode == 301) {
      return this.list(remotePath: response.headers.value('location'));
    }
    return _webDavXml(await response.transform(utf8.decoder).join());
  }

  /// upload a new file with [localData] as content to [remotePath]
  Future<HttpClientResponse> _upload(Uint8List localData, String remotePath) async {
    return await this._send(
      'PUT',
      remotePath,
      [200, 201, 204],
      data: localData,
    );
  }

  /// send the request with given [method] and [path]
  Future<HttpClientResponse> _send(
    String method,
    String path,
    List<int> expectedCodes, {
    Uint8List data,
    Map headers,
  }) async {
    return await retry(() => this.__send(method, path, expectedCodes, data: data, headers: headers),
        retryIf: (e) => e is WebDavException, maxAttempts: 5);
  }

  /// send the request with given [method] and [path]
  Future<HttpClientResponse> __send(
    String method,
    String path,
    List<int> expectedCodes, {
    Uint8List data,
    Map headers,
  }) async {
    String url = this.getUrl(path: path);
    print("[wevdav] http send with method: $method path: $path url: $url");

    HttpClientRequest request = await this.httpClient.openUrl(method, Uri.parse(url));
    request
      ..followRedirects = false
      ..persistentConnection = true;

    if (data != null) {
      request.add(data);
    }
    if (headers != null) {
      headers.forEach((k, v) => request.headers.add(k, v));
    }

    HttpClientResponse response = await request.close();

    if (!expectedCodes.contains(response.statusCode)) {
      throw WebDavException("operation failed method: $method\n"
          "path:$path exceptionCodes: $expectedCodes\n"
          "statusCode: ${response.statusCode}");
    }

    return response;
  }

  /// get file info list from `ls` command response
  List<FileInfo> _webDavXml(String webdavXml) {
    XmlDocument document = parse(webdavXml);
    print(document.toXmlString(pretty: true, indent: '\t'));

    final responses = document.findElements('d:multistatus').single.findElements('d:response');

    List<FileInfo> list = List<FileInfo>();

    responses.forEach((response) {
      final elem = response.findElements('d:propstat').single.findElements('d:prop').single;
      final href = response.findElements('d:href');
      final size = elem.findElements('d:getcontentlength');
      final mTime = elem.findElements('d:getlastmodified');
      final cTime = elem.findElements('d:creationdate');
      final contentType = elem.findElements('d:getcontenttype');
      final eTag = elem.findElements('d:getcontenttype');
      String name;
      String filePath;

      if (href.isNotEmpty) {
        filePath = '/' + href.single.text.replaceFirst(this.path, '');
        List parts = filePath.split("/");
        parts.removeWhere((part) => part.isEmpty);
        if (parts.isNotEmpty) {
          name = Uri.decodeFull(parts.last);
        }
      }

      FileInfo file = FileInfo(
        name: name,
        path: filePath,
        href: href.isNotEmpty ? href.single.text : null,
        size: size.isNotEmpty ? size.single.text : null,
        mTime: mTime.isNotEmpty ? mTime.single.text : null,
        cTime: cTime.isNotEmpty ? cTime.single.text : null,
        contentType: contentType.isNotEmpty ? contentType.single.text : null,
        eTag: eTag.isNotEmpty ? eTag.single.text : null,
      );
      list.add(file);
    });

    return list;
  }

  String _stripSlashes(String string) {
    if (string.startsWith('/')) {
      string = string.substring(1);
    }
    if (string.length > 0 && string.endsWith('/')) {
      string = string.substring(0, string.length - 1);
    }
    if (string.startsWith('/') || string.endsWith('/')) {
      string = _stripSlashes(string);
    }
    return string;
  }
}

class WebDavException implements Exception {
  String cause;

  WebDavException(this.cause);
}
