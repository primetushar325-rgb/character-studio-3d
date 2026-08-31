import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;

/// A tiny HTTP server bound to 127.0.0.1 that serves the offline 3D engine
/// and character files to the WebView renderer.
///
/// Why: model-viewer/three.js must `fetch()` its model from a real URL, and
/// Android WebView blocks cross-origin file:// access. Serving everything
/// from the loopback interface keeps rendering fully offline and same-origin.
/// No external host is ever contacted (see network_security_config.xml).
class ViewerServerService {
  ViewerServerService._();
  static final ViewerServerService instance = ViewerServerService._();

  HttpServer? _server;
  Directory? _charactersDir;
  Directory? _pendingDir;
  int _port = 0;

  int get port => _port;
  bool get isRunning => _server != null;

  void configureCharactersDirectory(Directory dir) {
    _charactersDir = dir;
  }

  void configurePendingDirectory(Directory dir) {
    _pendingDir = dir;
  }

  Future<int> start() async {
    if (_server != null) return _port;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server = server;
    _port = server.port;
    server.listen(_handle, onError: (_) {});
    return _port;
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }

  String urlFor(String path) => 'http://127.0.0.1:$_port$path';

  Future<void> _handle(HttpRequest request) async {
    try {
      final response = request.response;
      final path = request.uri.path;

      if (path == '/viewer/index.html') {
        final bytes = await rootBundle.load('assets/viewer/index.html');
        await _respondBytes(
          response,
          bytes.buffer.asUint8List(),
          'text/html; charset=utf-8',
        );
        return;
      }

      if (path == '/viewer/model-viewer.min.js') {
        final bytes = await rootBundle.load('assets/viewer/model-viewer.min.js');
        await _respondBytes(response, bytes.buffer.asUint8List(), 'text/javascript');
        return;
      }

      if (path.startsWith('/models/')) {
        await _serveModel(
          path: path,
          baseRoute: '/models/',
          dir: _charactersDir,
          response: response,
        );
        return;
      }

      if (path.startsWith('/pending/')) {
        await _serveModel(
          path: path,
          baseRoute: '/pending/',
          dir: _pendingDir,
          response: response,
        );
        return;
      }

      response.statusCode = HttpStatus.notFound;
      await response.close();
    } catch (_) {
      try {
        request.response.statusCode = HttpStatus.internalServerError;
        await request.response.close();
      } catch (_) {}
    }
  }

  Future<void> _serveModel({
    required String path,
    required String baseRoute,
    required Directory? dir,
    required HttpResponse response,
  }) async {
    if (dir == null) {
      response.statusCode = HttpStatus.notFound;
      await response.close();
      return;
    }
    final name = Uri.decodeComponent(path.substring(baseRoute.length));
    // Security: reject anything that tries to escape the model directory.
    if (name.contains('/') || name.contains('\\') || name.contains('..')) {
      response.statusCode = HttpStatus.forbidden;
      await response.close();
      return;
    }
    final file = File('${dir.path}${Platform.pathSeparator}$name');
    if (!await file.exists()) {
      response.statusCode = HttpStatus.notFound;
      await response.close();
      return;
    }
    final length = await file.length();
    response.statusCode = HttpStatus.ok;
    response.headers.set(HttpHeaders.contentTypeHeader, 'model/gltf-binary');
    response.headers.set(HttpHeaders.contentLengthHeader, length);
    response.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
    await response.addStream(file.openRead());
    await response.close();
  }

  Future<void> _respondBytes(HttpResponse response, Uint8List bytes, String type) async {
    response.statusCode = HttpStatus.ok;
    response.headers.set(HttpHeaders.contentTypeHeader, type);
    response.headers.set(HttpHeaders.contentLengthHeader, bytes.length);
    response.headers.set(HttpHeaders.cacheControlHeader, 'max-age=3600');
    response.add(bytes);
    await response.close();
  }
}
