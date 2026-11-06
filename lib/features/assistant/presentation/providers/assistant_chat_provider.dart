import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/assistant_api.dart';
import '../../domain/entities/assistant_request.dart';
import '../../domain/entities/recipe_availability.dart';
import 'assistant_providers.dart';

/// Una petición del chat con su respuesta.
class AssistantChatEntry {
  const AssistantChatEntry({
    required this.request,
    this.availability,
    this.availabilityFailed = false,
  });

  final AssistantRequest request;
  final RecipeAvailability? availability;
  final bool availabilityFailed;
}

class AssistantChatState {
  const AssistantChatState({this.entries = const [], this.sending = false});

  final List<AssistantChatEntry> entries;

  /// Hay una petición en curso: se atiende una a la vez.
  final bool sending;
}

/// Conversación con el asistente. Vive fuera de la pantalla para conservarse al
/// salir del chat y para que una petición en curso termine aunque el usuario se
/// vaya; se borra cuando cambia la sesión.
final assistantChatProvider =
    NotifierProvider<AssistantChatNotifier, AssistantChatState>(
      AssistantChatNotifier.new,
    );

class AssistantChatNotifier extends Notifier<AssistantChatState> {
  /// Consultas máximas mientras la IA procesa (unos 90 s con el intervalo por defecto).
  static const _maxPolls = 45;

  String? _sessionToken;

  AssistantApi get _api => ref.read(assistantApiProvider);

  @override
  AssistantChatState build() {
    _sessionToken = ref.watch(
      authControllerProvider.select((auth) => auth.asData?.value?.token),
    );
    return const AssistantChatState();
  }

  Future<String> _token() async {
    final session = await ref.read(authControllerProvider.future);
    if (session == null) {
      throw const AssistantApiException('Inicia sesión para enviar tu petición.');
    }
    return session.token;
  }

  /// Envía la petición y sigue su avance en segundo plano. Lanza una excepción
  /// si no se pudo enviar; devuelve false si ya hay otra en curso.
  Future<bool> send(String prompt) async {
    if (state.sending || prompt.trim().isEmpty) return false;
    _setSending(true);
    try {
      final token = await _token();
      // La pestaña sigue abierta: un fallo puntual quedaría guardado como null.
      final branchId =
          await ref.read(assistantBranchIdProvider.future) ??
          await ref.refresh(assistantBranchIdProvider.future);
      final request = await _api.sendRequest(
        token: token,
        prompt: prompt,
        branchId: branchId,
      );
      state = AssistantChatState(
        entries: [...state.entries, AssistantChatEntry(request: request)],
        sending: true,
      );
      unawaited(_follow(token, request));
      return true;
    } on Object {
      _setSending(false);
      rethrow;
    }
  }

  /// Consulta la petición hasta que la IA identifique la receta y su lista.
  Future<void> _follow(String token, AssistantRequest request) async {
    final interval = ref.read(assistantPollIntervalProvider);
    var current = request;
    for (var poll = 0; poll < _maxPolls && !current.isFinished; poll++) {
      await Future<void>.delayed(interval);
      if (token != _sessionToken) return;
      try {
        current = await _api.fetchRequest(token: token, requestId: request.id);
      } on AssistantApiException {
        // Un fallo puntual de red no detiene la espera.
        continue;
      }
      if (token != _sessionToken) return;
      _replace(AssistantChatEntry(request: current));
    }
    if (!current.isFinished) {
      _replace(
        AssistantChatEntry(
          request: AssistantRequest(
            id: current.id,
            prompt: current.prompt,
            status: AssistantRequestStatus.failed,
            message:
                'El asistente está tardando más de lo normal. Inténtalo de nuevo en unos minutos.',
          ),
        ),
      );
    }
    if (current.status == AssistantRequestStatus.completed) {
      await _loadAvailability(token, current);
    }
    if (token == _sessionToken) _setSending(false);
  }

  /// Compara la lista de ingredientes con el inventario de los supermercados.
  Future<void> _loadAvailability(String token, AssistantRequest request) async {
    _replace(AssistantChatEntry(request: request));
    try {
      final availability = await _api.fetchAvailability(
        token: token,
        requestId: request.id,
      );
      if (token != _sessionToken) return;
      _replace(AssistantChatEntry(request: request, availability: availability));
    } on AssistantApiException {
      if (token != _sessionToken) return;
      _replace(AssistantChatEntry(request: request, availabilityFailed: true));
    }
  }

  Future<void> retryAvailability(AssistantRequest request) async {
    await _loadAvailability(await _token(), request);
  }

  /// Trae una receta del historial al chat sin consultar a la IA: usa su lista
  /// guardada y la compara con el inventario actual.
  Future<RecipeAvailability> repeat(int requestId) async {
    final token = await _token();
    final request = await _api.fetchRequest(token: token, requestId: requestId);
    final availability = await _api.fetchAvailability(
      token: token,
      requestId: requestId,
    );
    state = AssistantChatState(
      entries: [
        ...state.entries.where((entry) => entry.request.id != requestId),
        AssistantChatEntry(request: request, availability: availability),
      ],
      sending: state.sending,
    );
    return availability;
  }

  void _replace(AssistantChatEntry entry) {
    state = AssistantChatState(
      entries: [
        for (final current in state.entries)
          current.request.id == entry.request.id ? entry : current,
      ],
      sending: state.sending,
    );
  }

  void _setSending(bool sending) {
    state = AssistantChatState(entries: state.entries, sending: sending);
  }
}
