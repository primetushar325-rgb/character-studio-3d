import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

/// Pure-Dart GIF89a encoder — real animated GIFs from rendered frames,
/// no platform plugins. Global palette via median-cut quantization +
/// Floyd–Steinberg-lite error diffusion on copy.
class GifEncoder {
  GifEncoder({this.width = 0, this.height = 0, this.dither = true});

  final int width;
  final int height;
  final bool dither;
  final List<Uint8List> _frames = [];
  final List<int> _delays = [];

  Future<void> addFrameAsync(ui.Image image, {required int delayMs}) async {
    _paletteImage ??= image;
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    _frames.add(Uint8List.fromList(data!.buffer.asUint8List()));
    _delays.add(delayMs);
  }

  /// Median-cut quantizer → 256-color palette + indexed frames.
  Uint8List encode() {
    if (_frames.isEmpty) throw StateError('No frames added');
    final img = _paletteImage;
    if (img == null) throw StateError('No frames added');
    final palette = _medianCut(_frames.first, 256);
    final indexed = <Uint8List>[];
    for (final f in _frames) {
      indexed.add(_mapToPalette(f, palette, dither: dither));
    }
    return _buildGif(palette, indexed, img.width, img.height);
  }

  ui.Image? _paletteImage;

  Uint8List _buildGif(List<List<int>> palette, List<Uint8List> frames, int w, int h) {
    final out = BytesBuilder();
    // Header + logical screen descriptor.
    out.add(utf8('GIF89a'));
    out.add(u16(w));
    out.add(u16(h));
    out.add([0xF7, 0, 0]); // global color table, 256 entries
    for (final c in palette) {
      out.add([c[0], c[1], c[2]]);
    }
    for (var i = palette.length; i < 256; i++) {
      out.add([0, 0, 0]);
    }
    // Netscape looping extension.
    out.add([0x21, 0xFF, 0x0B]);
    out.add(utf8('NETSCAPE2.0'));
    out.add([0x03, 0x01, 0x00, 0x00, 0x00]);

    for (var f = 0; f < frames.length; f++) {
      out.add([0x21, 0xF9, 0x04, 0x04]); // graphic control, disposal=1
      out.add(u16(_delays[f]));
      out.add([0x00, 0x00]);
      out.add([0x2C]); // image descriptor
      out.add(u16(0));
      out.add(u16(0));
      out.add(u16(w));
      out.add(u16(h));
      out.add([0x00]);
      _lzwEncode(out, frames[f], 8);
    }
    out.add([0x3B]); // trailer
    return out.toBytes();
  }

  // ---- median cut -----------------------------------------------------------
  List<List<int>> _medianCut(Uint8List rgba, int maxColors) {
    final pixels = <List<int>>[];
    final n = rgba.length ~/ 4;
    final step = math.max(1, n ~/ 20000); // sample for speed
    for (var i = 0; i < n; i += step) {
      final o = i * 4;
      if (rgba[o + 3] < 8) continue;
      pixels.add([rgba[o], rgba[o + 1], rgba[o + 2]]);
    }
    if (pixels.isEmpty) return [[0, 0, 0]];
    var boxes = [pixels];
    while (boxes.length < maxColors) {
      boxes.sort((a, b) => _range(b).compareTo(_range(a)));
      final box = boxes.removeAt(0);
      if (box.length < 2 || _range(box) == 0) {
        boxes.add(box);
        break;
      }
      final ch = _widestChannel(box);
      box.sort((a, b) => a[ch].compareTo(b[ch]));
      final mid = box.length ~/ 2;
      boxes..add(box.sublist(0, mid))..add(box.sublist(mid));
    }
    return [for (final b in boxes) _avg(b)];
  }

  int _widestChannel(List<List<int>> box) {
    var r = 0, g = 0, bl = 0;
    for (final p in box) {
      r = math.max(r, p[0]);
      g = math.max(g, p[1]);
      bl = math.max(bl, p[2]);
    }
    final rr = _rangeChannel(box, 0), rg = _rangeChannel(box, 1), rb = _rangeChannel(box, 2);
    if (rr >= rg && rr >= rb) return 0;
    if (rg >= rb) return 1;
    return 2;
  }

  int _rangeChannel(List<List<int>> box, int ch) {
    var mn = 255, mx = 0;
    for (final p in box) {
      if (p[ch] < mn) mn = p[ch];
      if (p[ch] > mx) mx = p[ch];
    }
    return mx - mn;
  }

  int _range(List<List<int>> box) {
    final r = _rangeChannel(box, 0), g = _rangeChannel(box, 1), b = _rangeChannel(box, 2);
    return math.max(r, math.max(g, b));
  }

  List<int> _avg(List<List<int>> box) {
    var r = 0, g = 0, b = 0;
    for (final p in box) {
      r += p[0];
      g += p[1];
      b += p[2];
    }
    final n = box.length;
    return [r ~/ n, g ~/ n, b ~/ n];
  }

  Uint8List _mapToPalette(Uint8List rgba, List<List<int>> palette, {required bool dither}) {
    final w = _paletteImage!.width;
    final n = rgba.length ~/ 4;
    final out = Uint8List(n);
    final err = Float32List(n * 3);
    for (var i = 0; i < n; i++) {
      final o = i * 4;
      var r = rgba[o].toDouble() + err[i * 3];
      var g = rgba[o + 1].toDouble() + err[i * 3 + 1];
      var b = rgba[o + 2].toDouble() + err[i * 3 + 2];
      r = r.clamp(0.0, 255.0);
      g = g.clamp(0.0, 255.0);
      b = b.clamp(0.0, 255.0);
      var best = 0;
      double bestD = 1e18;
      for (var p = 0; p < palette.length; p++) {
        final dr = r - palette[p][0];
        final dg = g - palette[p][1];
        final db = b - palette[p][2];
        final d = dr * dr + dg * dg + db * db;
        if (d < bestD) {
          bestD = d;
          best = p;
        }
      }
      out[i] = best;
      if (dither) {
        final er = r - palette[best][0];
        final eg = g - palette[best][1];
        final eb = b - palette[best][2];
        final x = i % w;
        if (x + 1 < w && i + 1 < n) _push(err, i + 1, er, eg, eb, 7 / 16);
        if (i + w < n) _push(err, i + w, er, eg, eb, 5 / 16);
        if (x > 0 && i + w - 1 < n) _push(err, i + w - 1, er, eg, eb, 3 / 16);
        if (i + w + 1 < n) _push(err, i + w + 1, er, eg, eb, 1 / 16);
      }
    }
    return out;
  }

  void _push(Float32List err, int i, double r, double g, double b, double k) {
    err[i * 3] += r * k;
    err[i * 3 + 1] += g * k;
    err[i * 3 + 2] += b * k;
  }

  // ---- LZW --------------------------------------------------------------------
  void _lzwEncode(BytesBuilder out, Uint8List pixels, int minCodeSize) {
    final clearCode = 1 << minCodeSize;
    final eoiCode = clearCode + 1;
    var codeSize = minCodeSize + 1;
    var dictSize = eoiCode + 1;
    var dict = <String, int>{};
    void resetDict() {
      dict = {};
      dictSize = eoiCode + 1;
      codeSize = minCodeSize + 1;
    }

    resetDict();
    final bb = <int>[];
    var bitBuf = 0;
    var bitCount = 0;
    void emit(int code) {
      bitBuf |= code << bitCount;
      bitCount += codeSize;
      while (bitCount >= 8) {
        bb.add(bitBuf & 0xFF);
        bitBuf >>= 8;
        bitCount -= 8;
      }
    }

    emit(clearCode);
    var prefix = pixels.isEmpty ? '' : String.fromCharCode(pixels[0]);
    for (var i = 1; i < pixels.length; i++) {
      final c = String.fromCharCode(pixels[i]);
      final combo = prefix + c;
      if (dict.containsKey(combo)) {
        prefix = combo;
      } else {
        emit(prefix.isEmpty ? clearCode : _codeOf(prefix, dict, minCodeSize));
        dict[combo] = dictSize++;
        if (dictSize > (1 << codeSize) && codeSize < 12) codeSize++;
        if (dictSize >= 4096) {
          emit(clearCode);
          resetDict();
        }
        prefix = c;
      }
    }
    if (prefix.isNotEmpty) emit(_codeOf(prefix, dict, minCodeSize));
    emit(eoiCode);
    if (bitCount > 0) bb.add(bitBuf & 0xFF);

    out.add([minCodeSize]);
    for (var i = 0; i < bb.length; i += 255) {
      final chunk = bb.sublist(i, math.min(i + 255, bb.length));
      out.add([chunk.length]);
      out.add(chunk);
    }
    out.add([0x00]);
  }

  int _codeOf(String prefix, Map<String, int> dict, int minCodeSize) {
    if (prefix.length == 1) return prefix.codeUnitAt(0);
    return dict[prefix] ?? 0;
  }
}

List<int> u16(int v) => [v & 0xFF, (v >> 8) & 0xFF];
List<int> utf8(String s) => s.codeUnits;
