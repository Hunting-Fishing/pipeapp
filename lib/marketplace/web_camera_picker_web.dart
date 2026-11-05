import 'dart:async';
import 'dart:js_interop';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:image_picker_for_web/image_picker_for_web.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:web/web.dart' as web;

bool _installed = false;

void installWebCameraPicker() {
  if (_installed) return;
  _installed = true;
  ImagePickerPlatform.instance = PipeWebImagePickerPlugin();
}

class PipeWebImagePickerPlugin extends ImagePickerPlugin {
  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async {
    if (source != ImageSource.camera) {
      return super.getImageFromSource(source: source, options: options);
    }
    return _captureFromBrowserCamera(options);
  }

  Future<XFile?> _captureFromBrowserCamera(ImagePickerOptions options) async {
    final mediaDevices = web.window.navigator.mediaDevices;
    var facingMode = options.preferredCameraDevice == CameraDevice.front
        ? 'user'
        : 'environment';

    Future<web.MediaStream> openStream(String preferredFacing,
        {String? deviceId}) async {
      try {
        final trackConstraints = deviceId != null && deviceId.isNotEmpty
            ? web.MediaTrackConstraints(
                deviceId:
                    web.ConstrainDOMStringParameters(exact: deviceId.toJS),
                width: web.ConstrainULongRange(ideal: 1920),
                height: web.ConstrainULongRange(ideal: 1080),
              )
            : web.MediaTrackConstraints(
                facingMode: preferredFacing.toJS,
                width: web.ConstrainULongRange(ideal: 1920),
                height: web.ConstrainULongRange(ideal: 1080),
              );
        return await mediaDevices
            .getUserMedia(
              web.MediaStreamConstraints(
                video: trackConstraints,
                audio: false.toJS,
              ),
            )
            .toDart;
      } catch (_) {
        // Fallback for laptop/PC webcams that do not support facingMode or resolution constraints.
        return await mediaDevices
            .getUserMedia(
              web.MediaStreamConstraints(
                video: true.toJS,
                audio: false.toJS,
              ),
            )
            .toDart;
      }
    }

    web.MediaStream stream;
    try {
      stream = await openStream(facingMode);
    } catch (error) {
      final errorText = error.toString();
      if (errorText.contains('NotAllowedError') ||
          errorText.contains('PermissionDeniedError') ||
          errorText.toLowerCase().contains('permission')) {
        throw PlatformException(
          code: 'camera_access_denied',
          message:
              'Camera access was denied. Allow camera access in your browser address bar and try again.',
        );
      }
      throw PlatformException(
        code: 'no_available_camera',
        message:
            'No camera could be opened on this device. Check your camera connection or permissions and try again.',
      );
    }

    void stopStream(web.MediaStream? activeStream) {
      if (activeStream == null) return;
      final tracks = activeStream.getTracks().toDart;
      for (final track in tracks) {
        track.stop();
      }
    }

    final completer = Completer<XFile?>();
    final existingModal =
        web.document.getElementById('__pipe_buyer_camera_modal');
    existingModal?.remove();

    final overlay = web.HTMLDivElement()
      ..id = '__pipe_buyer_camera_modal'
      ..style.position = 'fixed'
      ..style.inset = '0'
      ..style.zIndex = '2147483647'
      ..style.backgroundColor = 'rgba(13, 17, 23, 0.88)'
      ..style.display = 'flex'
      ..style. flexDirection = 'column'
      ..style.alignItems = 'center'
      ..style.justifyContent = 'center'
      ..style.padding = '16px'
      ..style.fontFamily = '"Plus Jakarta Sans", system-ui, -apple-system, sans-serif';

    final card = web.HTMLDivElement()
      ..style.backgroundColor = '#161B22'
      ..style.border = '1px solid #30363D'
      ..style.borderRadius = '16px'
      ..style.maxWidth = '680px'
      ..style.width = '100%'
      ..style.overflow = 'hidden'
      ..style.boxShadow = '0 24px 48px rgba(0, 0, 0, 0.5)';

    final header = web.HTMLDivElement()
      ..style.display = 'flex'
      ..style.alignItems = 'center'
      ..style.justifyContent = 'space-between'
      ..style.padding = '14px 18px'
      ..style.borderBottom = '1px solid #30363D';

    final title = web.HTMLSpanElement()
      ..textContent = 'Take Photo with Camera'
      ..style.color = '#F0F6FC'
      ..style.fontSize = '16px'
      ..style.fontWeight = '700';

    final closeBtn = web.HTMLButtonElement()
      ..type = 'button'
      ..textContent = 'Cancel'
      ..style.background = 'transparent'
      ..style.border = '1px solid #30363D'
      ..style.color = '#C9D1D9'
      ..style.borderRadius = '8px'
      ..style.padding = '6px 12px'
      ..style.fontSize = '13px'
      ..style.fontWeight = '600'
      ..style.cursor = 'pointer';

    header
      ..appendChild(title)
      ..appendChild(closeBtn);

    final videoContainer = web.HTMLDivElement()
      ..style.position = 'relative'
      ..style.backgroundColor = '#000000'
      ..style.width = '100%'
      ..style.aspectRatio = '16 / 10'
      ..style.maxHeight = '65vh'
      ..style.display = 'flex'
      ..style.alignItems = 'center'
      ..style.justifyContent = 'center'
      ..style.overflow = 'hidden';

    final video = web.HTMLVideoElement()
      ..autoplay = true
      ..muted = true
      ..playsInline = true
      ..srcObject = stream
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.objectFit = 'contain';

    videoContainer.appendChild(video);

    final footer = web.HTMLDivElement()
      ..style.display = 'flex'
      ..style.alignItems = 'center'
      ..style.justifyContent = 'center'
      ..style.gap = '12px'
      ..style.padding = '16px 18px'
      ..style.borderTop = '1px solid #30363D';

    final switchBtn = web.HTMLButtonElement()
      ..type = 'button'
      ..textContent = 'Switch Camera'
      ..style.backgroundColor = '#21262D'
      ..style.border = '1px solid #30363D'
      ..style.color = '#F0F6FC'
      ..style.borderRadius = '10px'
      ..style.padding = '10px 16px'
      ..style.fontSize = '14px'
      ..style.fontWeight = '600'
      ..style.cursor = 'pointer'
      ..style.display = 'none';

    final captureBtn = web.HTMLButtonElement()
      ..type = 'button'
      ..textContent = 'Capture Photo'
      ..style.backgroundColor = '#FF6A00'
      ..style.border = 'none'
      ..style.color = '#FFFFFF'
      ..style.borderRadius = '10px'
      ..style.padding = '10px 24px'
      ..style.fontSize = '14px'
      ..style.fontWeight = '700'
      ..style.cursor = 'pointer';

    footer
      ..appendChild(switchBtn)
      ..appendChild(captureBtn);

    card
      ..appendChild(header)
      ..appendChild(videoContainer)
      ..appendChild(footer);
    overlay.appendChild(card);
    web.document.body?.appendChild(overlay);
    unawaited(video.play().toDart.catchError((_) => null));

    final videoDevices = <web.MediaDeviceInfo>[];
    var currentDeviceIndex = 0;
    unawaited(() async {
      try {
        final devices = (await mediaDevices.enumerateDevices().toDart).toDart;
        for (final device in devices) {
          if (device.kind == 'videoinput') {
            videoDevices.add(device);
          }
        }
        if (videoDevices.length > 1) {
          switchBtn.style.display = 'inline-block';
        }
      } catch (_) {}
    }());

    late final JSExportedDartFunction keyListener;
    void cleanup([XFile? result]) {
      web.window.removeEventListener('keydown', keyListener);
      stopStream(stream);
      overlay.remove();
      if (!completer.isCompleted) {
        completer.complete(result);
      }
    }

    keyListener = ((web.KeyboardEvent event) {
      if (event.key == 'Escape') {
        cleanup(null);
      }
    }).toJS;
    web.window.addEventListener('keydown', keyListener);

    closeBtn.onclick = ((web.Event _) {
      cleanup(null);
    }).toJS;

    switchBtn.onclick = ((web.Event _) {
      unawaited(() async {
        try {
          facingMode = facingMode == 'user' ? 'environment' : 'user';
          String? nextDeviceId;
          if (videoDevices.length > 1) {
            currentDeviceIndex = (currentDeviceIndex + 1) % videoDevices.length;
            nextDeviceId = videoDevices[currentDeviceIndex].deviceId;
          }
          final nextStream =
              await openStream(facingMode, deviceId: nextDeviceId);
          stopStream(stream);
          stream = nextStream;
          video.srcObject = stream;
          await video.play().toDart;
        } catch (_) {}
      }());
    }).toJS;

    captureBtn.onclick = ((web.Event _) {
      final rawWidth = video.videoWidth > 0 ? video.videoWidth : 1280;
      final rawHeight = video.videoHeight > 0 ? video.videoHeight : 720;
      var targetWidth = rawWidth.toDouble();
      var targetHeight = rawHeight.toDouble();
      if (options.maxWidth != null && targetWidth > options.maxWidth!) {
        final ratio = options.maxWidth! / targetWidth;
        targetWidth = options.maxWidth!;
        targetHeight = targetHeight * ratio;
      }
      if (options.maxHeight != null && targetHeight > options.maxHeight!) {
        final ratio = options.maxHeight! / targetHeight;
        targetHeight = options.maxHeight!;
        targetWidth = targetWidth * ratio;
      }

      final canvas = web.HTMLCanvasElement()
        ..width = math.max(1, targetWidth.round())
        ..height = math.max(1, targetHeight.round());
      final ctx = canvas.context2D;
      ctx.drawImage(
        video,
        0,
        0,
        canvas.width.toDouble(),
        canvas.height.toDouble(),
      );

      final quality =
          ((options.imageQuality ?? 88).clamp(10, 100)) / 100.0;
      canvas.toBlob(
        ((web.Blob? blob) {
          if (blob == null) {
            cleanup(null);
            return;
          }
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final file = XFile(
            web.URL.createObjectURL(blob),
            name: 'camera_photo_$timestamp.jpg',
            mimeType: 'image/jpeg',
            length: blob.size,
            lastModified: DateTime.now(),
          );
          cleanup(file);
        }).toJS,
        'image/jpeg',
        quality.toJS,
      );
    }).toJS;

    return completer.future;
  }
}
