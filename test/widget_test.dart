import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/flutter_flow/internationalization.dart';
import 'package:pipe_app/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues(const {});
    await FFLocalizations.initialize();
  });

  test('Pipe app root can be constructed with persisted settings initialized',
      () {
    expect(const MyApp(), isA<StatefulWidget>());
  });
}
