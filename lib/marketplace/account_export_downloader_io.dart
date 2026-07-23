import 'dart:io';

import 'package:path_provider/path_provider.dart';

Future<String> downloadAccountExport(String fileName, String content) async {
  Directory? directory;
  try {
    directory = await getDownloadsDirectory();
  } catch (_) {
    // Some mobile path-provider implementations do not expose Downloads.
  }
  directory ??= await getApplicationDocumentsDirectory();
  final file = File('${directory.path}${Platform.pathSeparator}$fileName');
  await file.writeAsString(content, flush: true);
  return file.path;
}
