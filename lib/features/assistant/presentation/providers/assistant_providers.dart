import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../users/data/user_api.dart' show apiBaseUrl;
import '../../data/assistant_api.dart';

final assistantApiProvider = Provider<AssistantApi>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return AssistantApi(client: client, baseUri: Uri.parse(apiBaseUrl));
});
