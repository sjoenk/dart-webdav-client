import 'package:flutter_test/flutter_test.dart';
import 'package:dart_webdav/webdav.dart';

void main() {
  test('Get list', () async {
    WebDavClient client = WebDavClient(
      host: "webdavserver.com/",
      username: "username",
      password: "password",
      path: "",
    );

    List<FileInfo> list = await client.list();

    for (FileInfo item in list) {
      print(item.href);
      print("     - ${item.contentType} | ${item.size},  | ${item.cTime},  | ${item.mTime}");
    }
  });
}
