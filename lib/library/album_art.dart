import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// A cover small enough for Telegram's album art slot on an audio post: a JPEG of at
/// most [maxSide] pixels and [maxBytes] bytes.
class CoverThumb {
  const CoverThumb(this.bytes, this.width, this.height);
  final Uint8List bytes;
  final int width, height;
}

const maxSide = 320;
const maxBytes = 200 * 1024;

/// Shrinks any image the decoder knows to fit [side] pixels and [limit] bytes, which
/// default to Telegram's album art slot. Null if it can't be read or won't get small
/// enough, in which case there's simply no cover.
CoverThumb? shrinkCover(Uint8List bytes, {int side = maxSide, int limit = maxBytes}) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  final scale = min(1.0, side / max(decoded.width, decoded.height));
  final small = scale < 1
      ? img.copyResize(
          decoded,
          width: max(1, (decoded.width * scale).round()),
          height: max(1, (decoded.height * scale).round()),
          interpolation: img.Interpolation.average,
        )
      : decoded;
  for (final quality in const [85, 70, 50]) {
    final jpeg = Uint8List.fromList(img.encodeJpg(small, quality: quality));
    if (jpeg.length <= limit) return CoverThumb(jpeg, small.width, small.height);
  }
  return null;
}

/// [shrinkCover] off the UI thread: decoding a large cover takes a moment.
Future<CoverThumb?> shrinkCoverInBackground(Uint8List bytes, {int side = maxSide, int limit = maxBytes}) =>
    Isolate.run(() => shrinkCover(bytes, side: side, limit: limit));
