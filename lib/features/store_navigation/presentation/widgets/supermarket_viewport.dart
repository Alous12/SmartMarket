import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../domain/entities/store_model.dart';
import 'local_viewer_server.dart';
import 'render_metrics.dart';

class SupermarketViewport extends StatefulWidget {
  const SupermarketViewport({
    super.key,
    required this.model,
    required this.metrics,
    required this.measureContinuously,
    required this.onRetry,
  });

  final StoreModel model;
  final ValueNotifier<RenderMetrics> metrics;
  final bool measureContinuously;
  final VoidCallback onRetry;

  @override
  State<SupermarketViewport> createState() => SupermarketViewportState();
}

class SupermarketViewportState extends State<SupermarketViewport>
    with WidgetsBindingObserver {
  LocalViewerServer? _server;
  WebViewController? _controller;
  final _loadWatch = Stopwatch()..start();
  bool _ready = false;
  bool _active = true;
  String? _error;
  Timer? _initializationTimeout;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializationTimeout = Timer(const Duration(seconds: 45), () {
      if (!_ready) _onError('El visor 3D no respondió a tiempo.');
    });
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    try {
      final server = await LocalViewerServer.start(widget.model.bytes);
      if (!mounted) {
        await server.close();
        return;
      }
      _server = server;
      final controller = WebViewController();
      await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      await controller.setBackgroundColor(const Color(0xFFF4F6F0));
      await controller.addJavaScriptChannel(
        'StoreViewer',
        onMessageReceived: _onMessage,
      );
      await controller.setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            return uri?.scheme == 'http' &&
                    uri?.host == '127.0.0.1' &&
                    uri?.port == server.uri.port &&
                    uri!.path.startsWith(
                      server.uri.path.replaceFirst('/index.html', '/'),
                    )
                ? NavigationDecision.navigate
                : NavigationDecision.prevent;
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame == true) {
              _onError(error.description);
            }
          },
        ),
      );
      if (!mounted) return;
      setState(() => _controller = controller);
      await controller.loadRequest(server.uri);
    } catch (error) {
      _onError(error.toString());
    }
  }

  void _onMessage(JavaScriptMessage message) {
    if (!mounted) return;
    try {
      final data = jsonDecode(message.message) as Map<String, dynamic>;
      switch (data['type']) {
        case 'ready':
          _initializationTimeout?.cancel();
          _loadWatch.stop();
          setState(() => _ready = true);
          _command('setContinuous', widget.measureContinuously);
          _command('setActive', _active);
        case 'metrics':
          final metrics = RenderMetrics(
            fps: (data['fps'] as num).toDouble(),
            drawCalls: (data['drawCalls'] as num).toInt(),
            triangles: (data['triangles'] as num).toInt(),
            loadMilliseconds: _loadWatch.elapsedMilliseconds,
          );
          widget.metrics.value = metrics;
          if (widget.measureContinuously) {
            debugPrint(
              'SMARTMARKET_3D fps=${metrics.fps.toStringAsFixed(1)} '
              'calls=${metrics.drawCalls} tris=${metrics.triangles} '
              'load_ms=${metrics.loadMilliseconds}',
            );
          }
        case 'error':
          _onError(data['message'].toString());
      }
    } catch (error) {
      _onError('Respuesta inválida del visor: $error');
    }
  }

  void _command(String method, [Object? value]) {
    if (_controller == null ||
        (method != 'dispose' && (!_ready || _error != null))) {
      return;
    }
    final argument = value == null ? '' : jsonEncode(value);
    unawaited(
      _controller!
          .runJavaScript('window.smartMarket?.$method($argument)')
          .catchError((Object error) {
            if (mounted) _onError(error.toString());
          }),
    );
  }

  void resetView() => _command('reset');
  void zoomBy(double factor) => _command('zoomBy', factor);

  void _onError(String error) {
    if (!mounted || _error != null) return;
    debugPrint('SMARTMARKET_3D error: $error');
    _command('dispose');
    _initializationTimeout?.cancel();
    setState(() => _error = 'No se pudo iniciar la vista 3D.');
  }

  @override
  void didUpdateWidget(covariant SupermarketViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.measureContinuously != widget.measureContinuously) {
      _command('setContinuous', widget.measureContinuously);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    _command('setActive', _active);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _initializationTimeout?.cancel();
    _command('dispose');
    final server = _server;
    if (server != null) unawaited(server.close());
    _loadWatch.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.view_in_ar_outlined, size: 44),
            const SizedBox(height: 12),
            Text(_error!),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: widget.onRetry,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        if (_controller != null) WebViewWidget(controller: _controller!),
        if (!_ready)
          const ColoredBox(
            color: Color(0xFFF4F6F0),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Preparando el supermercado…'),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
