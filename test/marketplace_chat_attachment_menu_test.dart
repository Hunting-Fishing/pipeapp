import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pipe_app/marketplace/marketplace_messages_page.dart';

void main() {
  Widget app({
    bool uploading = false,
    required ValueChanged<ImageSource> onSelected,
  }) =>
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: MarketplaceChatAttachmentMenu(
              uploading: uploading,
              onSelected: onSelected,
            ),
          ),
        ),
      );

  testWidgets('attachment button opens gallery and camera choices',
      (tester) async {
    ImageSource? selected;
    await tester.pumpWidget(app(onSelected: (value) => selected = value));

    await tester.tap(find.byIcon(Icons.attach_file));
    await tester.pumpAndSettle();

    expect(find.text('Choose from gallery'), findsOneWidget);
    expect(find.text('Take a photo'), findsOneWidget);
    await tester.tap(find.text('Take a photo'));
    await tester.pumpAndSettle();
    expect(selected, ImageSource.camera);
  });

  testWidgets('attachment button is disabled while an upload is running',
      (tester) async {
    await tester.pumpWidget(app(
      uploading: true,
      onSelected: (_) => fail('Disabled attachment menu selected a source.'),
    ));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Choose from gallery'), findsNothing);
    expect(find.text('Take a photo'), findsNothing);
  });
}
