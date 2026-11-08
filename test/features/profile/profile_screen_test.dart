import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smartmarket/features/auth/data/auth_api.dart';
import 'package:smartmarket/features/auth/presentation/providers/auth_provider.dart';
import 'package:smartmarket/features/profile/presentation/screens/profile_screen.dart';
import 'package:smartmarket/features/users/data/user_api.dart';
import 'package:smartmarket/features/users/presentation/providers/users_providers.dart';

class _Controller extends AuthController {
  @override
  Future<AuthSession?> build() async =>
      const AuthSession(token: 't', username: 'Ana', role: 'user');
}

Map<String, Object> _user({
  String name = 'Ana',
  String email = 'ana@mail.com',
}) => {
  'user_id': 7,
  'name': name,
  'last_name': 'Pérez',
  'email': email,
  'role': 'user',
  'status': true,
};

/// Backend falso del perfil: guarda las solicitudes recibidas.
class _Backend {
  final requests = <http.Request>[];
  String? passwordError;

  Future<http.Response> handle(http.Request request) async {
    requests.add(request);
    expect(request.headers['authorization'], 'Bearer t');
    if (request.url.path == '/api/users/me/password') {
      return passwordError == null
          ? http.Response('', 204)
          : http.Response(jsonEncode({'error': passwordError}), 400);
    }
    if (request.method == 'PATCH') {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode({'data': _user(name: body['name'] as String? ?? 'Ana')}),
        200,
      );
    }
    return http.Response(jsonEncode({'data': _user()}), 200);
  }
}

Future<ProviderContainer> _pump(WidgetTester tester, _Backend backend) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(_Controller.new),
        userApiProvider.overrideWithValue(
          UserApi(
            client: MockClient(backend.handle),
            baseUri: Uri.parse('http://localhost:3000/api'),
            tokenReader: () async => 't',
          ),
        ),
      ],
      child: const MaterialApp(home: ProfileScreen()),
    ),
  );
  await tester.pumpAndSettle();
  final container = ProviderScope.containerOf(
    tester.element(find.byType(ProfileScreen)),
  );
  // En la app la sesión ya está cargada cuando se abre el perfil.
  await tester.runAsync(() => container.read(authControllerProvider.future));
  return container;
}

void main() {
  testWidgets('muestra los datos de la persona', (tester) async {
    await _pump(tester, _Backend());

    expect(find.text('Ana Pérez'), findsOneWidget);
    expect(find.text('Cliente'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Ana'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'ana@mail.com'), findsOneWidget);
  });

  testWidgets('guarda solo lo que cambió y actualiza el nombre de la sesión', (
    tester,
  ) async {
    final backend = _Backend();
    final container = await _pump(tester, backend);
    final save = find.widgetWithText(FilledButton, 'Guardar cambios');
    expect(tester.widget<FilledButton>(save).onPressed, isNull);

    await tester.enterText(find.widgetWithText(TextFormField, 'Ana'), 'Anita');
    await tester.pump();
    await tester.tap(save);
    await tester.pumpAndSettle();

    final patch = backend.requests.singleWhere((r) => r.method == 'PATCH');
    expect(patch.url.path, '/api/users/me');
    expect(jsonDecode(patch.body), {'name': 'Anita'});
    expect(find.text('Tus datos se actualizaron.'), findsOneWidget);
    expect(find.text('Anita Pérez'), findsOneWidget);
    expect(
      container.read(authControllerProvider).asData?.value?.username,
      'Anita',
    );
  });

  testWidgets('no envía la contraseña si la confirmación no coincide', (
    tester,
  ) async {
    final backend = _Backend();
    await _pump(tester, backend);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Contraseña actual'),
      'vieja1234',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nueva contraseña'),
      'nueva1234',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Confirmar nueva contraseña'),
      'otra12345',
    );
    await tester.ensureVisible(find.text('Cambiar contraseña'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cambiar contraseña'));
    await tester.pumpAndSettle();

    expect(find.text('Las contraseñas no coinciden.'), findsOneWidget);
    expect(backend.requests.where((r) => r.method == 'PUT'), isEmpty);
  });

  testWidgets('cambia la contraseña con la actual', (tester) async {
    final backend = _Backend();
    await _pump(tester, backend);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Contraseña actual'),
      'vieja1234',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nueva contraseña'),
      'nueva1234',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Confirmar nueva contraseña'),
      'nueva1234',
    );
    await tester.ensureVisible(find.text('Cambiar contraseña'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cambiar contraseña'));
    await tester.pumpAndSettle();

    final put = backend.requests.singleWhere((r) => r.method == 'PUT');
    expect(put.url.path, '/api/users/me/password');
    expect(jsonDecode(put.body), {
      'current_password': 'vieja1234',
      'new_password': 'nueva1234',
    });
    expect(find.text('Tu contraseña se cambió.'), findsOneWidget);
  });

  testWidgets('muestra el error si la contraseña actual es incorrecta', (
    tester,
  ) async {
    final backend = _Backend()
      ..passwordError = 'La contraseña actual no es correcta.';
    await _pump(tester, backend);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Contraseña actual'),
      'mala12345',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nueva contraseña'),
      'nueva1234',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Confirmar nueva contraseña'),
      'nueva1234',
    );
    await tester.ensureVisible(find.text('Cambiar contraseña'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cambiar contraseña'));
    await tester.pumpAndSettle();

    expect(find.text('La contraseña actual no es correcta.'), findsOneWidget);
  });
}
