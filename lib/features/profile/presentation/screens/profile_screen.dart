import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../users/domain/entities/user.dart';
import '../../../users/presentation/providers/users_providers.dart';

/// Datos de la persona con la sesión iniciada.
final profileProvider = FutureProvider.autoDispose<User>(
  (ref) => ref.watch(userApiProvider).getProfile(),
);

final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

/// Pestaña Perfil: ver y editar los datos propios y cambiar la contraseña.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Perfil',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
      ),
      body: profile.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.green),
        ),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'No se pudo cargar tu perfil: $error',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => ref.invalidate(profileProvider),
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
        data: (user) => _ProfileBody(user: user),
      ),
    );
  }
}

class _ProfileBody extends ConsumerStatefulWidget {
  const _ProfileBody({required this.user});

  final User user;

  @override
  ConsumerState<_ProfileBody> createState() => _ProfileBodyState();
}

class _ProfileBodyState extends ConsumerState<_ProfileBody> {
  final _dataForm = GlobalKey<FormState>();
  final _passwordForm = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.user.name);
  late final _lastName = TextEditingController(text: widget.user.lastName);
  late final _email = TextEditingController(text: widget.user.email);
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  late User _user = widget.user;
  bool _savingData = false;
  bool _savingPassword = false;
  bool _obscure = true;
  String? _dataError;
  String? _passwordError;

  @override
  void initState() {
    super.initState();
    for (final controller in [_name, _lastName, _email]) {
      controller.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _lastName,
      _email,
      _current,
      _next,
      _confirm,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  bool get _dataChanged =>
      _name.text.trim() != _user.name ||
      _lastName.text.trim() != _user.lastName ||
      _email.text.trim().toLowerCase() != _user.email;

  void _toast(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  Future<void> _saveData() async {
    if (!_dataForm.currentState!.validate()) return;
    final name = _name.text.trim(), lastName = _lastName.text.trim();
    final email = _email.text.trim().toLowerCase();
    setState(() {
      _savingData = true;
      _dataError = null;
    });
    try {
      // Solo se envía lo que cambió.
      final updated = await ref
          .read(userApiProvider)
          .updateProfile(
            name: name == _user.name ? null : name,
            lastName: lastName == _user.lastName ? null : lastName,
            email: email == _user.email ? null : email,
          );
      if (!mounted) return;
      ref.read(authControllerProvider.notifier).updateUsername(updated.name);
      setState(() => _user = updated);
      _toast('Tus datos se actualizaron.');
    } on Object catch (error) {
      if (mounted) setState(() => _dataError = error.toString());
    } finally {
      if (mounted) setState(() => _savingData = false);
    }
  }

  Future<void> _changePassword() async {
    if (!_passwordForm.currentState!.validate()) return;
    setState(() {
      _savingPassword = true;
      _passwordError = null;
    });
    try {
      await ref
          .read(userApiProvider)
          .changePassword(
            currentPassword: _current.text,
            newPassword: _next.text,
          );
      if (!mounted) return;
      _current.clear();
      _next.clear();
      _confirm.clear();
      _toast('Tu contraseña se cambió.');
    } on Object catch (error) {
      if (mounted) setState(() => _passwordError = error.toString());
    } finally {
      if (mounted) setState(() => _savingPassword = false);
    }
  }

  InputDecoration _field(String label, IconData icon, {Widget? suffix}) =>
      InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: suffix,
        border: const OutlineInputBorder(),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initials = [_user.name, _user.lastName]
        .where((word) => word.isNotEmpty)
        .map((word) => word[0].toUpperCase())
        .join();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Card(
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: AppTheme.lime,
                  child: Text(
                    initials,
                    style: const TextStyle(
                      color: AppTheme.ink,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_user.name} ${_user.lastName}',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(_user.email, style: theme.textTheme.bodyMedium),
                      const SizedBox(height: 6),
                      Chip(
                        label: Text(
                          _user.role == 'admin' ? 'Trabajador' : 'Cliente',
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _Section(
          title: 'Datos personales',
          child: Form(
            key: _dataForm,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _name,
                  enabled: !_savingData,
                  decoration: _field('Nombre', Icons.person_outline),
                  textCapitalization: TextCapitalization.words,
                  maxLength: 100,
                  validator: (value) => (value ?? '').trim().isEmpty
                      ? 'Ingresa tu nombre.'
                      : null,
                ),
                const SizedBox(height: 4),
                TextFormField(
                  controller: _lastName,
                  enabled: !_savingData,
                  decoration: _field('Apellido', Icons.person_outline),
                  textCapitalization: TextCapitalization.words,
                  maxLength: 100,
                  validator: (value) => (value ?? '').trim().isEmpty
                      ? 'Ingresa tu apellido.'
                      : null,
                ),
                const SizedBox(height: 4),
                TextFormField(
                  controller: _email,
                  enabled: !_savingData,
                  decoration: _field('Correo electrónico', Icons.mail_outline),
                  keyboardType: TextInputType.emailAddress,
                  maxLength: 255,
                  validator: (value) {
                    final email = (value ?? '').trim();
                    if (email.isEmpty) return 'Ingresa tu correo.';
                    if (!_emailPattern.hasMatch(email)) {
                      return 'Ingresa un correo válido.';
                    }
                    return null;
                  },
                ),
                if (_dataError != null) _ErrorText(_dataError!),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _savingData || !_dataChanged ? null : _saveData,
                  child: _savingData
                      ? const _Spinner()
                      : const Text('Guardar cambios'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _Section(
          title: 'Contraseña',
          child: Form(
            key: _passwordForm,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _current,
                  enabled: !_savingPassword,
                  obscureText: _obscure,
                  decoration: _field(
                    'Contraseña actual',
                    Icons.lock_outline,
                    suffix: IconButton(
                      tooltip: _obscure
                          ? 'Mostrar contraseñas'
                          : 'Ocultar contraseñas',
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  validator: (value) => (value ?? '').isEmpty
                      ? 'Ingresa tu contraseña actual.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _next,
                  enabled: !_savingPassword,
                  obscureText: _obscure,
                  decoration: _field('Nueva contraseña', Icons.lock_reset),
                  validator: (value) {
                    if ((value ?? '').length < 8) {
                      return 'Usa al menos 8 caracteres.';
                    }
                    if (value == _current.text) {
                      return 'Debe ser distinta de la actual.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _confirm,
                  enabled: !_savingPassword,
                  obscureText: _obscure,
                  decoration: _field(
                    'Confirmar nueva contraseña',
                    Icons.lock_reset,
                  ),
                  validator: (value) => value != _next.text
                      ? 'Las contraseñas no coinciden.'
                      : null,
                ),
                if (_passwordError != null) _ErrorText(_passwordError!),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _savingPassword ? null : _changePassword,
                  child: _savingPassword
                      ? const _Spinner()
                      : const Text('Cambiar contraseña'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          icon: const Icon(Icons.logout),
          label: const Text('Cerrar sesión'),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppTheme.green,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Text(
      message,
      textAlign: TextAlign.center,
      style: TextStyle(color: Theme.of(context).colorScheme.error),
    ),
  );
}

class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 20,
    height: 20,
    child: CircularProgressIndicator(strokeWidth: 2),
  );
}
