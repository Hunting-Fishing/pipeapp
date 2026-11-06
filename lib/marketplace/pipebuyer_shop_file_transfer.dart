import 'pipebuyer_shop_file_transfer_io.dart'
    if (dart.library.js_interop) 'pipebuyer_shop_file_transfer_web.dart';

bool get supportsBrowserSpreadsheetFilePicker =>
    supportsBrowserSpreadsheetFilePickerImpl;

Future<({String fileName, String content})?> pickSpreadsheetTextFile() =>
    pickSpreadsheetTextFileImpl();

Future<bool> downloadSpreadsheetCsv({
  required String fileName,
  required String csvContent,
}) =>
    downloadSpreadsheetCsvImpl(fileName: fileName, csvContent: csvContent);
