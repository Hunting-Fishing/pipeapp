import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'profile_photo_upload_types.dart';

Future<String> uploadProfilePhotoImpl({
  required Uint8List bytes,
  required String userId,
  required String idToken,
  required String storageBucket,
  required ProfilePhotoProgress onProgress,
}) {
  final objectPath =
      'profile_media/$userId/avatar_${DateTime.now().millisecondsSinceEpoch}.png';
  final uploadUrl = Uri.https(
    'firebasestorage.googleapis.com',
    '/v0/b/$storageBucket/o',
    {'uploadType': 'media', 'name': objectPath},
  ).toString();
  final request = web.XMLHttpRequest()
    ..open('POST', uploadUrl)
    ..timeout = 90000
    ..setRequestHeader('Authorization', 'Firebase $idToken')
    ..setRequestHeader('Content-Type', 'image/png');
  final completer = Completer<String>();

  void fail(String code, String message) {
    if (!completer.isCompleted) {
      completer.completeError(ProfilePhotoUploadException(code, message));
    }
  }

  request.upload.onprogress = ((web.Event event) {
    final progressEvent = event as web.ProgressEvent;
    if (!progressEvent.lengthComputable || progressEvent.total <= 0) return;
    onProgress(progressEvent.loaded / progressEvent.total);
  }).toJS;
  request.onerror = ((web.Event _) {
    fail('network-error',
        'The browser could not reach profile photo storage. Check the connection and try again.');
  }).toJS;
  request.ontimeout = ((web.Event _) {
    fail('timeout',
        'The profile photo upload timed out. Check the connection and try again.');
  }).toJS;
  request.onabort = ((web.Event _) {
    fail('canceled', 'The profile photo upload was canceled.');
  }).toJS;
  request.onload = ((web.Event _) {
    if (request.status < 200 || request.status >= 300) {
      var message = 'Profile photo storage returned HTTP ${request.status}.';
      var code = 'http-${request.status}';
      try {
        final response = jsonDecode(request.responseText);
        if (response is Map) {
          final error = response['error'];
          if (error is Map) {
            message = '${error['message'] ?? message}';
            code = '${error['code'] ?? code}';
          }
        }
      } catch (_) {}
      fail(code, message);
      return;
    }
    try {
      final metadata = jsonDecode(request.responseText);
      if (metadata is! Map) {
        fail('invalid-response',
            'Profile photo storage returned an invalid response.');
        return;
      }
      final rawTokens = '${metadata['downloadTokens'] ?? ''}'.trim();
      final downloadToken =
          rawTokens.isEmpty ? '' : rawTokens.split(',').first.trim();
      final encodedPath = Uri.encodeComponent(objectPath);
      final tokenQuery = downloadToken.isEmpty
          ? ''
          : '&token=${Uri.encodeQueryComponent(downloadToken)}';
      onProgress(1);
      if (!completer.isCompleted) {
        completer.complete(
            'https://firebasestorage.googleapis.com/v0/b/$storageBucket/o/$encodedPath?alt=media$tokenQuery');
      }
    } catch (_) {
      fail('invalid-response',
          'Profile photo storage returned an unreadable response.');
    }
  }).toJS;

  final blob = web.Blob(
    <JSAny>[bytes.toJS].toJS,
    web.BlobPropertyBag(type: 'image/png'),
  );
  request.send(blob);
  return completer.future;
}
