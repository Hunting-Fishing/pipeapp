import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/flutter_flow/flutter_flow_util.dart';

void main() {
  test('JSON path extraction preserves scalar, list, and missing behavior', () {
    final response = <String, dynamic>{
      'seller': <String, dynamic>{'name': 'Pipe Buyer'},
      'items': <Map<String, dynamic>>[
        <String, dynamic>{'price': 73},
        <String, dynamic>{'price': 80},
      ],
    };

    expect(getJsonField(response, r'$.seller.name'), 'Pipe Buyer');
    expect(getJsonField(response, r'$.items[*].price'), <int>[73, 80]);
    expect(
      getJsonField(response, r'$.seller.name', true),
      <String>['Pipe Buyer'],
    );
    expect(getJsonField(response, r'$.seller.missing'), isNull);
  });
}
