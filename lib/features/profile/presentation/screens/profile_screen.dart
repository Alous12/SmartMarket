import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/empty_or_error_state.dart';
import '../../../../core/widgets/section_label.dart';
import '../../../../core/widgets/skeleton_box.dart';
import '../../../../core/widgets/sm_buttons.dart';
import '../../../../core/widgets/sm_text_field.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../users/data/user_api.dart';
import '../../../users/domain/entities/user.dart';
import '../../../users/presentation/providers/users_providers.dart';

/// Datos de la persona con la sesión iniciada.
final profileProvider = FutureProvider.autoDispose<User>(
  (ref) => ref.watch(userApiProvider).getProfile(),
);

/// Interruptores «Cómo elige tu asistente».
final assistantSettingsProvider = FutureProvider.autoDispose<AssistantSettings>(
  (ref) => ref.watch(userApiProvider).getAssistantSettings(),
  retry: (count, error) => null,
);

final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

/// Pestaña Perfil: datos de la cuenta, cómo elige el asistente y accesos a
/// editar los datos y cambiar la contraseña.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: profile.when(
          loading: () => const _ProfileSkeleton(),
          error: (error, stack) => EmptyOrErrorState(
            icon: Icons.person_off_outlined,
            title: 'No se pudo cargar tu perfil: $error',
            onRetry: () => ref.invalidate(profileProvider),
          ),
          data: (user) => _ProfileBody(user: user),
        ),
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
  late User _user = widget.user;

  /// Valores mostrados mientras se guarda un cambio (respuesta inmediata).
  AssistantSettings? _pending;

  void _toast(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  Future<void> _openData() async {
    final updated = await Navigator.of(context, rootNavigator: true).push<User>(
      MaterialPageRoute(builder: (_) => _PersonalDataScreen(user: _user)),
    );
    if (updated == null || !mounted) return;
    setState(() => _user = updated);
    _toast('Tus datos se actualizaron.');
  }

  Future<void> _openPassword() async {
    final changed = await Navigator.of(
      context,
      rootNavigator: true,
    ).push<bool>(MaterialPageRoute(builder: (_) => const _PasswordScreen()));
    if (changed == true && mounted) _toast('Tu contraseña se cambió.');
  }

  Future<void> _setSetting(
    AssistantSettings current, {
    bool? prioritizeCheapest,
    bool? rememberBrands,
  }) async {
    setState(
      () => _pending = AssistantSettings(
        prioritizeCheapest: prioritizeCheapest ?? current.prioritizeCheapest,
        rememberBrands: rememberBrands ?? current.rememberBrands,
      ),
    );
    try {
      await ref
          .read(userApiProvider)
          .updateAssistantSettings(
            prioritizeCheapest: prioritizeCheapest,
            rememberBrands: rememberBrands,
          );
      ref.invalidate(assistantSettingsProvider);
      await ref.read(assistantSettingsProvider.future);
    } on Object catch (error) {
      if (mounted) _toast(error.toString());
    } finally {
      if (mounted) setState(() => _pending = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final initials = [_user.name, _user.lastName]
        .where((word) => word.isNotEmpty)
        .map((word) => word[0].toUpperCase())
        .join();
    final admin = _user.role == 'admin';
    final settings = ref.watch(assistantSettingsProvider);
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 32),
      children: [
        Row(
          children: [
            Container(
              width: 76,
              height: 76,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppTheme.green,
                borderRadius: BorderRadius.circular(AppTheme.radiusL + 2),
              ),
              child: Text(
                initials,
                style: const TextStyle(
                  color: AppTheme.lime,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_user.name} ${_user.lastName}',
                    style: const TextStyle(
                      color: AppTheme.ink,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          _user.email,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppTheme.muted,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const Text(
                        ' · ',
                        style: TextStyle(color: AppTheme.muted, fontSize: 16),
                      ),
                      Text(
                        admin ? 'Administrador' : 'Cliente',
                        style: const TextStyle(
                          color: AppTheme.muted,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        if (!admin) ...[
          const SizedBox(height: 24),
          const SectionLabel('Cómo elige tu asistente'),
          const SizedBox(height: 10),
          _Group(
            children: settings.when(
              loading: () => const [
                Padding(
                  padding: EdgeInsets.all(18),
                  child: SkeletonBox(height: 96),
                ),
              ],
              error: (error, stack) => [
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: EmptyOrErrorState(
                    compact: true,
                    icon: Icons.tune_rounded,
                    title: 'No se pudieron cargar estos ajustes.',
                    onRetry: () => ref.invalidate(assistantSettingsProvider),
                  ),
                ),
              ],
              data: (loaded) {
                final current = _pending ?? loaded;
                return [
                  _SwitchRow(
                    title: 'Priorizar lo más barato',
                    subtitle: 'Aprendido de tus últimas compras',
                    value: current.prioritizeCheapest,
                    onChanged: _pending != null
                        ? null
                        : (value) =>
                              _setSetting(loaded, prioritizeCheapest: value),
                  ),
                  const Divider(height: 1),
                  _SwitchRow(
                    title: 'Recordar mis marcas',
                    subtitle: 'Sugerimos lo que repites',
                    value: current.rememberBrands,
                    onChanged: _pending != null
                        ? null
                        : (value) => _setSetting(loaded, rememberBrands: value),
                  ),
                ];
              },
            ),
          ),
        ],
        const SizedBox(height: 24),
        const SectionLabel('Tu cuenta'),
        const SizedBox(height: 10),
        _Group(
          children: [
            _NavRow(
              title: 'Datos personales',
              subtitle: 'Nombre, apellido y correo',
              onTap: _openData,
            ),
            const Divider(height: 1),
            _NavRow(title: 'Cambiar contraseña', onTap: _openPassword),
          ],
        ),
        const SizedBox(height: 28),
        Center(
          child: TextButton(
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.danger,
              minimumSize: const Size(200, 52),
            ),
            child: const Text('Cerrar sesión'),
          ),
        ),
      ],
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
        border: Border.all(color: AppTheme.border, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: const EdgeInsets.fromLTRB(20, 10, 16, 10),
      title: Text(
        title,
        style: const TextStyle(
          color: AppTheme.ink,
          fontSize: 19,
          fontWeight: FontWeight.w800,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: AppTheme.muted, fontSize: 15),
      ),
      value: value,
      onChanged: onChanged,
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({required this.title, required this.onTap, this.subtitle});

  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppTheme.ink,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 15,
                      ),
                    ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppTheme.muted),
          ],
        ),
      ),
    );
  }
}

/// Encabezado de las subpantallas del perfil.
class _SubHeader extends StatelessWidget {
  const _SubHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
      child: Row(
        children: [
          const SmBackButton(),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.ink,
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// «Datos personales»: nombre, apellido y correo. Devuelve el usuario guardado.
class _PersonalDataScreen extends ConsumerStatefulWidget {
  const _PersonalDataScreen({required this.user});

  final User user;

  @override
  ConsumerState<_PersonalDataScreen> createState() =>
      _PersonalDataScreenState();
}

class _PersonalDataScreenState extends ConsumerState<_PersonalDataScreen> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.user.name);
  late final _lastName = TextEditingController(text: widget.user.lastName);
  late final _email = TextEditingController(text: widget.user.email);
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    for (final controller in [_name, _lastName, _email]) {
      controller.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final controller in [_name, _lastName, _email]) {
      controller.dispose();
    }
    super.dispose();
  }

  bool get _changed =>
      _name.text.trim() != widget.user.name ||
      _lastName.text.trim() != widget.user.lastName ||
      _email.text.trim().toLowerCase() != widget.user.email;

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final user = widget.user;
    final name = _name.text.trim(), lastName = _lastName.text.trim();
    final email = _email.text.trim().toLowerCase();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      // Solo se envía lo que cambió.
      final updated = await ref
          .read(userApiProvider)
          .updateProfile(
            name: name == user.name ? null : name,
            lastName: lastName == user.lastName ? null : lastName,
            email: email == user.email ? null : email,
          );
      if (!mounted) return;
      ref.read(authControllerProvider.notifier).updateUsername(updated.name);
      Navigator.pop(context, updated);
    } on Object catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Form(
          key: _form,
          child: Column(
            children: [
              const _SubHeader('Datos personales'),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
                  children: [
                    SmTextField(
                      label: 'Nombre',
                      controller: _name,
                      enabled: !_saving,
                      textCapitalization: TextCapitalization.words,
                      maxLength: 100,
                      validator: (value) => (value ?? '').trim().isEmpty
                          ? 'Ingresa tu nombre.'
                          : null,
                    ),
                    const SizedBox(height: 18),
                    SmTextField(
                      label: 'Apellido',
                      controller: _lastName,
                      enabled: !_saving,
                      textCapitalization: TextCapitalization.words,
                      maxLength: 100,
                      validator: (value) => (value ?? '').trim().isEmpty
                          ? 'Ingresa tu apellido.'
                          : null,
                    ),
                    const SizedBox(height: 18),
                    SmTextField(
                      label: 'Correo electrónico',
                      controller: _email,
                      enabled: !_saving,
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
                    if (_error != null) _ErrorText(_error!),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(58),
                  ),
                  onPressed: _saving || !_changed ? null : _save,
                  child: _saving
                      ? const _Spinner()
                      : const Text('Guardar cambios'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// «Contraseña»: actual, nueva y confirmación. Devuelve true si se cambió.
class _PasswordScreen extends ConsumerStatefulWidget {
  const _PasswordScreen();

  @override
  ConsumerState<_PasswordScreen> createState() => _PasswordScreenState();
}

class _PasswordScreenState extends ConsumerState<_PasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _saving = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _change() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(userApiProvider)
          .changePassword(
            currentPassword: _current.text,
            newPassword: _next.text,
          );
      if (mounted) Navigator.pop(context, true);
    } on Object catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Form(
          key: _form,
          child: Column(
            children: [
              const _SubHeader('Contraseña'),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
                  children: [
                    SmTextField(
                      label: 'Contraseña actual',
                      controller: _current,
                      enabled: !_saving,
                      obscureText: _obscure,
                      suffix: IconButton(
                        tooltip: _obscure
                            ? 'Mostrar contraseñas'
                            : 'Ocultar contraseñas',
                        onPressed: () => setState(() => _obscure = !_obscure),
                        icon: Icon(
                          _obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: AppTheme.muted,
                        ),
                      ),
                      validator: (value) => (value ?? '').isEmpty
                          ? 'Ingresa tu contraseña actual.'
                          : null,
                    ),
                    const SizedBox(height: 18),
                    SmTextField(
                      label: 'Nueva contraseña',
                      controller: _next,
                      enabled: !_saving,
                      obscureText: _obscure,
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
                    const SizedBox(height: 18),
                    SmTextField(
                      label: 'Confirmar nueva contraseña',
                      controller: _confirm,
                      enabled: !_saving,
                      obscureText: _obscure,
                      validator: (value) => value != _next.text
                          ? 'Las contraseñas no coinciden.'
                          : null,
                    ),
                    if (_error != null) _ErrorText(_error!),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(58),
                  ),
                  onPressed: _saving ? null : _change,
                  child: _saving
                      ? const _Spinner()
                      : const Text('Cambiar contraseña'),
                ),
              ),
            ],
          ),
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
    padding: const EdgeInsets.only(top: 16),
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.dangerTint,
        borderRadius: BorderRadius.circular(AppTheme.radiusS),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 20, color: AppTheme.danger),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppTheme.danger,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 22,
    height: 22,
    child: CircularProgressIndicator(strokeWidth: 2.4, color: AppTheme.ink),
  );
}

class _ProfileSkeleton extends StatelessWidget {
  const _ProfileSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 32),
      children: const [
        SkeletonBox(height: 76, radius: AppTheme.radiusL),
        SizedBox(height: 28),
        SkeletonBox(height: 150, radius: AppTheme.radiusXL),
        SizedBox(height: 28),
        SkeletonBox(height: 150, radius: AppTheme.radiusXL),
      ],
    );
  }
}
