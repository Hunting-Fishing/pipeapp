import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

Future<Uint8List?> pickProfilePhotoBytesImpl() async {
  final image = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    imageQuality: 92,
    maxWidth: 2000,
    maxHeight: 2000,
  );
  return image?.readAsBytes();
}
