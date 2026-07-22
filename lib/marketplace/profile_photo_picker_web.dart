import 'dart:typed_data';

import 'package:image_picker_for_web/image_picker_for_web.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

Future<Uint8List?> pickProfilePhotoBytesImpl() async {
  final image = await ImagePickerPlugin().getImageFromSource(
    source: ImageSource.gallery,
    options: const ImagePickerOptions(
      imageQuality: 92,
      maxWidth: 2000,
      maxHeight: 2000,
    ),
  );
  return image?.readAsBytes();
}
