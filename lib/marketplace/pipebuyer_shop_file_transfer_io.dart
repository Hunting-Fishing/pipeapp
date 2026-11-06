Future<({String fileName, String content})?> pickSpreadsheetTextFileImpl() async {
  return null;
}

Future<bool> downloadSpreadsheetCsvImpl({
  required String fileName,
  required String csvContent,
}) async {
  return false;
}

bool get supportsBrowserSpreadsheetFilePickerImpl => false;
