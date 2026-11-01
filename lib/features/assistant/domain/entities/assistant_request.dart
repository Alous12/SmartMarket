enum AssistantRequestStatus { received, processing, completed, failed }

/// Petición escrita por el usuario y guardada por el backend.
class AssistantRequest {
  const AssistantRequest({
    required this.id,
    required this.prompt,
    required this.status,
  });

  final int id;
  final String prompt;
  final AssistantRequestStatus status;

  factory AssistantRequest.fromJson(Map<String, dynamic> json) {
    return AssistantRequest(
      id: json['request_id'] as int,
      prompt: json['prompt'] as String,
      status: AssistantRequestStatus.values.byName(
        (json['status'] as String).toLowerCase(),
      ),
    );
  }
}
