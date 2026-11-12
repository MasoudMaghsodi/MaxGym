import 'dart:io';
import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  await integrationDriver(
    onScreenshot: (String name, List<int> bytes, [Map<String, dynamic>? args]) async {
      final file = File('screenshots/android/$name.png');
      file.parent.createSync(recursive: true);
      file.writeAsBytesSync(bytes);
      print('Driver saved host screenshot: ${file.path} (${bytes.length} bytes)');
      return true;
    },
  );
}
