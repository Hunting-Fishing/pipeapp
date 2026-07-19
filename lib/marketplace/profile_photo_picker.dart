import 'dart:typed_data';

import 'profile_photo_picker_io.dart'
    if (dart.library.html) 'profile_photo_picker_web.dart';

Future<Uint8List?> pickProfilePhotoBytes() => pickProfilePhotoBytesImpl();
