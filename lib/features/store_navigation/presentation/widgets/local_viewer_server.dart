import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';

class LocalViewerServer {
  LocalViewerServer._(this._server, this._prefix, this._files);

  final HttpServer _server;
  final String _prefix;
  final Map<String, Uint8List> _files;

  Uri get uri =>
      Uri.parse('http://127.0.0.1:${_server.port}$_prefix/index.html');

  static Future<LocalViewerServer> start(Uint8List modelBytes) async {
    const assets = {
      '/index.html': 'assets/store_viewer/index.html',
      '/viewer.js': 'assets/store_viewer/viewer.js',
      '/instancing.js': 'assets/store_viewer/instancing.js',
      '/vendor/three.module.min.js':
          'assets/store_viewer/vendor/three.module.min.js',
      '/vendor/three.core.min.js':
          'assets/store_viewer/vendor/three.core.min.js',
      '/vendor/GLTFLoader.js': 'assets/store_viewer/vendor/GLTFLoader.js',
      '/vendor/OrbitControls.js': 'assets/store_viewer/vendor/OrbitControls.js',
      '/utils/BufferGeometryUtils.js':
          'assets/store_viewer/vendor/BufferGeometryUtils.js',
    };
    final files = <String, Uint8List>{'/model.glb': modelBytes};
    await Future.wait(
      assets.entries.map((entry) async {
        final data = await rootBundle.load(entry.value);
        files[entry.key] = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );
      }),
    );
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final random = Random.secure();
    final prefix =
        '/${List.generate(16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join()}';
    final viewer = LocalViewerServer._(server, prefix, files);
    server.listen(viewer._handle);
    return viewer;
  }

  Future<void> _handle(HttpRequest request) async {
    final path = request.uri.path;
    final file = path.startsWith('$_prefix/')
        ? _files[path.substring(_prefix.length)]
        : null;
    final response = request.response;
    if (request.method != 'GET' && request.method != 'HEAD') {
      response.statusCode = HttpStatus.methodNotAllowed;
    } else if (file == null) {
      response.statusCode = HttpStatus.notFound;
    } else {
      response.headers.contentType = path.endsWith('.html')
          ? ContentType.html
          : path.endsWith('.js')
          ? ContentType('application', 'javascript', charset: 'utf-8')
          : ContentType('model', 'gltf-binary');
      response.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
      response.contentLength = file.length;
      if (request.method == 'GET') response.add(file);
    }
    try {
      await response.close();
    } on SocketException {
      // The WebView may close a request while the screen is being disposed.
    }
  }

  Future<void> close() async {
    await _server.close(force: true);
    _files.clear();
  }
}
