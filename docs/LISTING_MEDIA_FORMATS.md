# Listing media formats

What a seller can pick from a phone, and what Pipe Buyer stores.

## Photos

| What the phone or browser hands over | What is stored |
|---|---|
| JPEG, PNG up to 5 MB | uploaded unchanged |
| JPEG/PNG over 5 MB, WebP, GIF, BMP, TIFF | re-encoded as JPEG, oriented upright, longest side 2000 px, transparency flattened onto white |
| HEIC / HEIF / AVIF | converted to JPEG **where the device can decode it** (see below) |

The format is read from the file's bytes, never from its name. Phones and browsers often mislabel files, so a
GIF named `IMG_1.JPG` is converted, and a text file named `x.jpg` is refused with a clear message.

Pickers accept originals up to 40 MB (`maxRawPhotoBytes`); the stored result is at most 5 MB (`maxPhotoBytes`).

Storage rules still allow only `photo_N.jpg|jpeg|png`, so non-web-safe formats can never be stored by mistake.

### HEIC / HEIF / AVIF

- iPhone and Android app: the photo picker already hands over JPEG, and the normalizer decodes HEIC with the
  device's own codec if it ever receives one.
- Safari and iOS web: Safari converts HEIC to JPEG on selection.
- Chrome, Edge and Firefox cannot decode HEIC. The seller sees: *"... is a HEIC photo this browser cannot read.
  Use the Pipe Buyer app or Safari, or set your camera to Most Compatible, then choose the photo again."*
  Supporting HEIC in those browsers needs a bundled WebAssembly decoder (about 1.5 MB); not done yet.

## Video

| Container | Where it comes from | Content type |
|---|---|---|
| MP4 | Android, iPhone | `video/mp4` |
| MOV | iPhone | `video/quicktime` |
| M4V | iPhone / editors | `video/x-m4v` |
| 3GP, 3G2 | older Android | `video/3gpp`, `video/3gpp2` |
| WebM | some Android apps | `video/webm` |

Limit: **100 MB** per listing video (`maxVideoBytes`, `storage.rules`). Anything else (AVI, MKV, ...) is refused
before upload.

Videos are stored as recorded. Playback depends on the viewer's device: MP4/H.264 plays everywhere; iPhone
MOV/HEVC plays in Safari and on phones but not in every desktop browser. Re-encoding every video to H.264 on the
server (Cloud Transcoder) is the follow-up that makes "plays everywhere" true; it needs the Transcoder API enabled
on the Firebase project and per-minute billing, so it is a product decision.

## Not covered yet

Profile photos, chat photos, Dispatch request photos, and report evidence still use their own pickers and
type checks. They rely on the phone picker's own JPEG conversion; the normalizer in
`lib/marketplace/marketplace_image_normalizer.dart` is ready to be applied there.
Photo EXIF location data is not stripped from JPEG/PNG files that pass through unchanged.
