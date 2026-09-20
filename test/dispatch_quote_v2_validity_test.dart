import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/marketplace/marketplace_dispatch_quote_validity.dart';

void main() {
  test('legacy B1 pending quotes remain active and awardable', () {
    final quote = <String, dynamic>{
      'status': 'pending',
      'revision': 1,
    };

    expect(dispatchQuoteValidityStatus(quote), 'active');
    expect(dispatchQuoteIsCurrentAndAwardable(quote), isTrue);
  });

  test('older version is marked superseded by the next version', () {
    final presentation = dispatchQuoteVersionPresentation(
      currentQuote: {
        'status': 'pending',
        'validityStatus': 'active',
        'quoteVersion': 3,
      },
      revision: {
        'event': 'quote_updated',
        'quoteVersion': 2,
      },
    );

    expect(presentation.kind, DispatchQuoteValidityKind.superseded);
    expect(presentation.supersededByVersion, 3);
    expect(presentation.label, 'Version 2 · Superseded by Version 3');
    expect(presentation.watermark, 'QUOTE UPDATED - NO LONGER VALID');
  });

  test('cancelled current quote is visibly invalid', () {
    final current = <String, dynamic>{
      'status': 'cancelled',
      'validityStatus': 'cancelled',
      'quoteVersion': 4,
    };
    final presentation = dispatchQuoteVersionPresentation(
      currentQuote: current,
      revision: {
        'event': 'quote_cancelled',
        'quoteVersion': 4,
      },
    );

    expect(dispatchQuoteIsCurrentAndAwardable(current), isFalse);
    expect(presentation.kind, DispatchQuoteValidityKind.cancelled);
    expect(presentation.label, 'Version 4 · Cancelled');
    expect(presentation.watermark, 'QUOTE CANCELLED - NO LONGER VALID');
  });

  test('current active version has no invalidation watermark', () {
    final current = <String, dynamic>{
      'status': 'pending',
      'validityStatus': 'active',
      'quoteVersion': 5,
    };
    final presentation = dispatchQuoteVersionPresentation(
      currentQuote: current,
      revision: {
        'event': 'quote_updated',
        'quoteVersion': 5,
      },
    );

    expect(presentation.kind, DispatchQuoteValidityKind.active);
    expect(presentation.label, 'Version 5 · Current');
    expect(presentation.watermark, isEmpty);
  });
}
