import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<String> saveJsonExport(String content) async {
  final directory = await getApplicationDocumentsDirectory();
  final file = File(p.join(directory.path, 'taskflow_export.json'));
  await file.writeAsString(content);
  return 'Data JSON tersimpan di:\\n${file.path}';
}
