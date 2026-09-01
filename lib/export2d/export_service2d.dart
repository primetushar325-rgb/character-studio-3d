import 'dart:io';
import 'dart:ui' as ui;

import 'package:ffmpeg_kit_flutter_new_min_gpl/ffmpeg_kit.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../scene/scene_renderer.dart' show renderSceneFrame;
import '../state/editor_provider.dart';
import 'gif_encoder.dart';

/// Real frame-based export: renders the actual 16:9 composition frame by
/// frame (never the screen/UI) and encodes Video (H.264 MP4 via ffmpeg-kit),
/// GIF (pure Dart), PNG and PNG sequences.
enum ExportPhase { idle, preparing, rendering, encoding, finalizing, done, failed }

enum ExportType { video, gif, png, pngSequence }

class ExportProgress {
  const ExportProgress(this.phase, this.value, this.message);
  final ExportPhase phase;
  final double value; // 0..1
  final String message;
}

class ExportResult {
  ExportResult({required this.path, required this.mime, required this.fileBytes, this.frameCount = 1});
  final String path;
  final String mime;
  final int fileBytes;
  final int frameCount;
}

class ExportService2D {
  static const _channel = MethodChannel('characterstudio/mediastore');

  /// Renders every frame of the current animation and encodes it.
  ///
  /// [durationSeconds] comes from the animation clip; [loops] repeats it.
  Future<ExportResult> export({
    required EditorProvider ed,
    required ExportType type,
    required int width,
    required int height,
    required int fps,
    required int quality, // 0 low, 1 medium, 2 high, 3 ultra
    required double durationSeconds,
    required int loops,
    void Function(ExportProgress)? onProgress,
  }) async {
    final op = onProgress ?? (_) {};
    try {
      op(const ExportProgress(ExportPhase.preparing, 0.02, 'Preparing composition…'));
      final total = (durationSeconds * loops * fps).round().clamp(1, 3600);
      final framesDir = Directory.systemTemp.createTempSync('cs_frames');
      final encoder = GifEncoder();

      op(const ExportProgress(ExportPhase.rendering, 0.05, 'Rendering frames…'));
      final pngPaths = <String>[];
      for (var i = 0; i < total; i++) {
        final t = (i / fps) % durationSeconds;
        // PHASE 3: evaluate the story timeline at this frame — the exact same
        // evaluation the preview uses (spec §22: preview == export).
        ed.scrubSceneTo((t * 1000).round());
        final image = await renderSceneFrame(ed, width, height);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('${framesDir.path}/frame_${i.toString().padLeft(4, '0')}.png');
        await file.writeAsBytes(data!.buffer.asUint8List());
        pngPaths.add(file.path);
        if (type == ExportType.gif && width <= 854) {
          // GIF from downscaled frames for sane file size.
          final small = await renderSceneFrame(ed, width.clamp(1, 640), (height * (640 / width)).round().clamp(1, 640));
          await encoder.addFrameAsync(small, delayMs: (1000 / fps).round());
        }
        image.dispose();
        op(ExportProgress(ExportPhase.rendering, 0.05 + 0.45 * (i + 1) / total, 'Rendering frame ${i + 1}/$total'));
      }

      final stamp = DateTime.now().millisecondsSinceEpoch;
      final outDir = await _outputDir();
      switch (type) {
        case ExportType.png:
          op(const ExportProgress(ExportPhase.finalizing, 0.95, 'Saving PNG…'));
          final f = File('${outDir.path}/frame_$stamp.png');
          await f.writeAsBytes(await File(pngPaths.first).readAsBytes());
          return ExportResult(path: f.path, mime: 'image/png', fileBytes: await f.length());
        case ExportType.pngSequence:
          op(const ExportProgress(ExportPhase.finalizing, 0.9, 'Saving PNG sequence…'));
          final seqDir = Directory('${outDir.path}/sequence_$stamp');
          await seqDir.create(recursive: true);
          for (final src in pngPaths) {
            await File(src).copy('${seqDir.path}/${p.basename(src)}');
          }
          return ExportResult(path: seqDir.path, mime: 'image/png', fileBytes: pngPaths.length, frameCount: pngPaths.length);
        case ExportType.gif:
          op(const ExportProgress(ExportPhase.encoding, 0.55, 'Encoding GIF…'));
          final bytes = encoder.encode();
          final f = File('${outDir.path}/animation_$stamp.gif');
          await f.writeAsBytes(bytes);
          op(const ExportProgress(ExportPhase.done, 1, 'Export complete'));
          return ExportResult(path: f.path, mime: 'image/gif', fileBytes: bytes.length);
        case ExportType.video:
          op(const ExportProgress(ExportPhase.encoding, 0.55, 'Encoding H.264 video…'));
          final bitrate = ['', '1.5M', '3M', '6M', '12M'][quality.clamp(1, 3) + 1];
          final out = '${outDir.path}/animation_$stamp.mp4';
          final args = [
            '-y',
            '-framerate', '$fps',
            '-i', '${framesDir.path}/frame_%04d.png',
            '-c:v', 'libx264',
            '-preset', 'medium',
            '-b:v', bitrate,
            '-pix_fmt', 'yuv420p',
            '-movflags', '+faststart',
            out,
          ];
          final rc = await _runFfmpeg(args);
          if (rc != 0) {
            throw 'Video encoder failed (code $rc)';
          }
          op(const ExportProgress(ExportPhase.done, 1, 'Export complete'));
          return ExportResult(path: out, mime: 'video/mp4', fileBytes: await File(out).length(), frameCount: total);
      }
    } catch (e) {
      op(ExportProgress(ExportPhase.failed, 0, 'Export failed: $e'));
      rethrow;
    }
  }

  Future<Directory> _outputDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/2DStudio_exports');
    await dir.create(recursive: true);
    return dir;
  }

  /// Saves bytes to Android Movies/MediaStore (no permissions on API 29+).
  Future<String?> saveToMovies(String fileName, String mime, Uint8List bytes) async {
    if (!Platform.isAndroid) return null;
    try {
      return await _channel.invokeMethod<String>('saveToMovies', {
        'fileName': fileName,
        'mime': mime,
        'bytes': bytes,
      });
    } on PlatformException {
      return null;
    }
  }
}


typedef FfmpegRunner = Future<int> Function(List<String> args);

Future<int> _runFfmpeg(List<String> args) async {
  final session = await FFmpegKit.execute(args.join(' '));
  final code = await session.getReturnCode();
  return code?.getValue() ?? -1;
}
