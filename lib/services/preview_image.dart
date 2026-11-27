import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:flutter/painting.dart';

/// Ảnh sau khi thu nhỏ: cạnh dài tối đa 1280px (card chỉ rộng ~300–400px).
const _maxSide = 1280;

/// Mở hộp chọn file ảnh của trình duyệt → thu nhỏ → JPEG data URL.
/// Trả về null nếu người dùng huỷ. Lỗi → `error` là thông báo tiếng Việt.
///
/// data URL (~100–250 KB) được gửi kèm body /api/submissions; BE kiểm tra
/// magic bytes, encode lại JPEG rồi lưu file, trả về `previewUrl`.
Future<({String? dataUrl, String? error})?> pickPreviewImage() async {
  final input = html.FileUploadInputElement()
    ..accept = 'image/png,image/jpeg,image/webp';
  final picked = Completer<html.File?>();
  input.onChange.first.then((_) {
    final files = input.files;
    picked.complete(files != null && files.isNotEmpty ? files.first : null);
  });
  input.click();

  final file = await picked.future;
  if (file == null) return null;
  if (!file.type.startsWith('image/')) {
    return (dataUrl: null, error: 'Chỉ nhận ảnh PNG, JPG hoặc WebP');
  }
  // Không giới hạn dung lượng ảnh gốc: luôn thu nhỏ còn cạnh dài 1280px +
  // nén JPEG (~100–300 KB) trước khi gửi.

  try {
    final reader = html.FileReader()..readAsDataUrl(file);
    await reader.onLoad.first;
    final src = reader.result as String;

    final img = html.ImageElement(src: src);
    await img.onLoad.first;
    final w = img.naturalWidth;
    final h = img.naturalHeight;
    if (w == 0 || h == 0) throw StateError('empty image');

    final scale = (w > h ? w : h) > _maxSide ? _maxSide / (w > h ? w : h) : 1.0;
    final cw = (w * scale).round();
    final ch = (h * scale).round();
    final canvas = html.CanvasElement(width: cw, height: ch);
    canvas.context2D.drawImageScaled(img, 0, 0, cw, ch);
    return (dataUrl: canvas.toDataUrl('image/jpeg', .85), error: null);
  } catch (_) {
    return (dataUrl: null, error: 'Không đọc được ảnh này, thử ảnh khác');
  }
}

/// data URL được giải mã 1 lần rồi giữ lại → cùng 1 MemoryImage (cùng bytes)
/// → ImageCache dùng lại, không decode lại mỗi lần card rebuild.
final Map<String, Uint8List> _bytes = {};

ImageProvider previewImageProvider(String src) {
  if (!src.startsWith('data:')) return NetworkImage(src);
  final bytes = _bytes.putIfAbsent(src, () {
    if (_bytes.length > 40) _bytes.clear();
    final comma = src.indexOf(',');
    return base64Decode(src.substring(comma + 1));
  });
  return MemoryImage(bytes);
}
