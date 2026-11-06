import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

bool get supportsBrowserSpreadsheetFilePickerImpl => true;

Future<({String fileName, String content})?> pickSpreadsheetTextFileImpl() {
  final completer = Completer<({String fileName, String content})?>();
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = '.csv,.tsv,.txt,text/csv,text/tab-separated-values';

  input.onchange = ((web.Event _) {
    final files = input.files;
    if (files == null || files.length == 0) {
      if (!completer.isCompleted) completer.complete(null);
      return;
    }
    final file = files.item(0);
    if (file == null) {
      if (!completer.isCompleted) completer.complete(null);
      return;
    }
    final reader = web.FileReader();
    reader.onload = ((web.Event __) {
      final result = reader.result;
      final text = result?.dartify()?.toString() ?? '';
      if (!completer.isCompleted) {
        completer.complete((fileName: file.name, content: text));
      }
    }).toJS;
    reader.onerror = ((web.Event __) {
      if (!completer.isCompleted) completer.complete(null);
    }).toJS;
    reader.readAsText(file);
  }).toJS;

  input.click();
  return completer.future;
}

Future<bool> downloadSpreadsheetCsvImpl({
  required String fileName,
  required String csvContent,
}) async {
  final bytes = utf8.encode('\uFEFF$csvContent');
  final jsBytes = bytes.toJS;
  final blob = web.Blob(
    <JSAny>[jsBytes].toJS,
    web.BlobPropertyBag(type: 'text/csv;charset=utf-8'),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = fileName
    ..style.display = 'none';
  web.document.body?.appendChild(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
  return true;
}
