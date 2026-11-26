import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/sm_buttons.dart';
import '../../../../core/widgets/sm_text_field.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_widgets.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    // La ayuda «Mínimo 8 caracteres» se pone verde mientras se escribe.
    _passwordController.addListener(_onPasswordChanged);
  }

  void _onPasswordChanged() => setState(() {});

  @override
  void dispose() {
    _passwordController.removeListener(_onPasswordChanged);
    _nameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref
        .read(authControllerProvider.notifier)
        .register(
          name: _nameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
    if (!mounted) return;
    if (ref.read(authControllerProvider).asData?.value != null) {
      context.goNamed('supermarket');
    }
  }

  void _openLogin() {
    ref.read(authControllerProvider.notifier).clearError();
    context.goNamed('login');
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;
    final error = authState.hasError ? authState.error.toString() : null;
    final passwordLongEnough = _passwordController.text.length >= 8;

    final nameField = SmTextField(
      label: 'Nombre',
      controller: _nameController,
      enabled: !isLoading,
      textCapitalization: TextCapitalization.words,
      textInputAction: TextInputAction.next,
      maxLength: 100,
      validator: (value) =>
          value == null || value.trim().isEmpty ? 'Ingresa tu nombre.' : null,
    );
    final lastNameField = SmTextField(
      label: 'Apellido',
      controller: _lastNameController,
      enabled: !isLoading,
      textCapitalization: TextCapitalization.words,
      textInputAction: TextInputAction.next,
      maxLength: 100,
      validator: (value) =>
          value == null || value.trim().isEmpty ? 'Ingresa tu apellido.' : null,
    );

    return Scaffold(
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 14, 22, 16),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              SmBackButton(
                                tooltip: 'Volver al inicio de sesión',
                                onPressed: isLoading ? null : _openLogin,
                              ),
                              const Spacer(),
                              const SmLogo(size: 40),
                            ],
                          ),
                          const SizedBox(height: 22),
                          Semantics(
                            header: true,
                            child: const Text(
                              'Crea tu cuenta',
                              style: TextStyle(
                                color: AppTheme.ink,
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.7,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Regístrate para empezar a explorar SmartMarket.',
                            style: TextStyle(
                              color: AppTheme.muted,
                              fontSize: 17,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 24),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              if (constraints.maxWidth < 300) {
                                return Column(
                                  children: [
                                    nameField,
                                    const SizedBox(height: 18),
                                    lastNameField,
                                  ],
                                );
                              }
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: nameField),
                                  const SizedBox(width: 10),
                                  Expanded(child: lastNameField),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 18),
                          SmTextField(
                            label: 'Correo electrónico',
                            controller: _emailController,
                            enabled: !isLoading,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.newUsername],
                            maxLength: 255,
                            validator: (value) {
                              final email = value?.trim() ?? '';
                              if (email.isEmpty) return 'Ingresa tu correo.';
                              if (!RegExp(
                                r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                              ).hasMatch(email)) {
                                return 'Ingresa un correo válido.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 18),
                          SmTextField(
                            label: 'Contraseña',
                            controller: _passwordController,
                            enabled: !isLoading,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.newPassword],
                            suffix: PasswordEye(
                              obscured: _obscurePassword,
                              onPressed: isLoading
                                  ? null
                                  : () => setState(
                                      () =>
                                          _obscurePassword = !_obscurePassword,
                                    ),
                            ),
                            validator: (value) {
                              if (value == null || value.length < 8) {
                                return 'Usa al menos 8 caracteres.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 8),
                          _PasswordHint(met: passwordLongEnough),
                          const SizedBox(height: 14),
                          SmTextField(
                            label: 'Confirmar contraseña',
                            controller: _confirmPasswordController,
                            enabled: !isLoading,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _submit(),
                            validator: (value) =>
                                value != _passwordController.text
                                ? 'Las contraseñas no coinciden.'
                                : null,
                          ),
                          AnimatedSize(
                            duration: AppTheme.motion(context, AppTheme.medium),
                            curve: Curves.easeOutCubic,
                            child: error == null
                                ? const SizedBox(width: double.infinity)
                                : Padding(
                                    padding: const EdgeInsets.only(top: 16),
                                    child: AuthErrorBanner(message: error),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              AuthBottomActions(
                primary: SmPrimaryButton(
                  label: 'Crear cuenta',
                  loading: isLoading,
                  onPressed: _submit,
                ),
                secondary: TextButton(
                  onPressed: isLoading ? null : _openLogin,
                  child: const Text('Ya tengo una cuenta'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ayuda en vivo de la contraseña: pasa a verde con un check al cumplirse.
class _PasswordHint extends StatelessWidget {
  const _PasswordHint({required this.met});

  final bool met;

  @override
  Widget build(BuildContext context) {
    final color = met ? AppTheme.green : AppTheme.muted;
    final duration = AppTheme.motion(context, AppTheme.fast);
    return Semantics(
      liveRegion: true,
      child: Row(
        children: [
          AnimatedSwitcher(
            duration: duration,
            transitionBuilder: (child, animation) =>
                ScaleTransition(scale: animation, child: child),
            child: Icon(
              met ? Icons.check_rounded : Icons.circle_outlined,
              key: ValueKey(met),
              size: 20,
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          AnimatedDefaultTextStyle(
            duration: duration,
            style: TextStyle(
              color: color,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
            child: const Text('Mínimo 8 caracteres'),
          ),
        ],
      ),
    );
  }
}
