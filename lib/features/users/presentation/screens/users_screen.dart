import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/empty_or_error_state.dart';
import '../../../../core/widgets/sm_buttons.dart';
import '../../../../core/widgets/sm_card.dart';
import '../../../../core/widgets/sm_text_field.dart';
import '../../../../core/widgets/staggered_entrance.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../domain/entities/user.dart';
import '../providers/users_providers.dart';

class UsersScreen extends ConsumerWidget {
  const UsersScreen({super.key});

  Future<void> _createUser(BuildContext context, WidgetRef ref) async {
    final input = await showDialog<_NewUserInput>(
      context: context,
      builder: (context) => const _NewUserDialog(),
    );
    if (input == null) return;

    try {
      await ref
          .read(userApiProvider)
          .createUser(
            name: input.name,
            lastName: input.lastName,
            email: input.email,
            password: input.password,
          );
      ref.invalidate(usersProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Usuario creado correctamente.')),
        );
      }
    } on Object catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  /// Hoja para editar nombre, apellido y si la cuenta está activa.
  Future<void> _editUser(BuildContext context, WidgetRef ref, User user) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      sheetAnimationStyle: AnimationStyle(
        curve: Curves.easeOutCubic,
        duration: AppTheme.motion(context, AppTheme.slow),
      ),
      builder: (context) => _EditUserSheet(user: user),
    );
    if (saved != true) return;
    ref.invalidate(usersProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Usuario actualizado.')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = ref.watch(usersProvider);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createUser(context, ref),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text(
          'Nuevo usuario',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
              child: Row(
                children: [
                  if (Navigator.of(context).canPop()) ...[
                    const SmBackButton(),
                    const SizedBox(width: 16),
                  ],
                  Semantics(
                    header: true,
                    child: const Text(
                      'Usuarios',
                      style: TextStyle(
                        color: AppTheme.ink,
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: AppTheme.motion(context, AppTheme.medium),
                child: users.when(
                  loading: () => const Center(
                    key: ValueKey('loading'),
                    child: CircularProgressIndicator(color: AppTheme.green),
                  ),
                  error: (error, _) => EmptyOrErrorState(
                    key: const ValueKey('error'),
                    title: 'No se pudieron cargar los usuarios.',
                    message: '$error',
                    onRetry: () => ref.invalidate(usersProvider),
                  ),
                  data: (items) => _UserList(
                    key: const ValueKey('data'),
                    users: items,
                    onTap: (user) => _editUser(context, ref, user),
                    onRefresh: () async {
                      ref.invalidate(usersProvider);
                      try {
                        await ref.read(usersProvider.future);
                      } on Object {
                        // The provider exposes refresh failures in the screen's error state.
                      }
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserList extends StatelessWidget {
  const _UserList({
    super.key,
    required this.users,
    required this.onRefresh,
    required this.onTap,
  });

  final List<User> users;
  final Future<void> Function() onRefresh;
  final ValueChanged<User> onTap;

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) {
      return RefreshIndicator(
        color: AppTheme.green,
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 120),
            EmptyOrErrorState(
              error: false,
              icon: Icons.group_outlined,
              title: 'Todavía no hay usuarios registrados.',
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: AppTheme.green,
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 96),
        itemCount: users.length,
        separatorBuilder: (context, index) => const SizedBox(height: 10),
        itemBuilder: (context, index) => StaggeredEntrance(
          index: index,
          child: _UserCard(
            user: users[index],
            onTap: () => onTap(users[index]),
          ),
        ),
      ),
    );
  }
}

String _initials(User user) {
  final letters = [user.name, user.lastName]
      .where((word) => word.isNotEmpty)
      .map((word) => word[0].toUpperCase())
      .join();
  return letters.isEmpty ? '?' : letters;
}

class _UserCard extends StatelessWidget {
  const _UserCard({required this.user, required this.onTap});

  final User user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SmCard(
      onTap: onTap,
      radius: AppTheme.radiusXL,
      borderWidth: 1.5,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppTheme.tint,
              shape: BoxShape.circle,
            ),
            child: Text(
              _initials(user),
              style: const TextStyle(
                color: AppTheme.green,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${user.name} ${user.lastName}',
                  style: const TextStyle(
                    color: AppTheme.ink,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  user.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppTheme.muted, fontSize: 16),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          StatusChip(
            label: user.isActive ? 'Activo' : 'Inactivo',
            tone: user.isActive ? StatusTone.ok : StatusTone.neutral,
          ),
        ],
      ),
    );
  }
}

/// Edita una cuenta con `PATCH /users/:id`. Devuelve true si se guardó.
class _EditUserSheet extends ConsumerStatefulWidget {
  const _EditUserSheet({required this.user});

  final User user;

  @override
  ConsumerState<_EditUserSheet> createState() => _EditUserSheetState();
}

class _EditUserSheetState extends ConsumerState<_EditUserSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.user.name);
  late final _lastName = TextEditingController(text: widget.user.lastName);
  late bool _active = widget.user.isActive;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    for (final controller in [_name, _lastName]) {
      controller.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _lastName.dispose();
    super.dispose();
  }

  bool get _changed =>
      _name.text.trim() != widget.user.name ||
      _lastName.text.trim() != widget.user.lastName ||
      _active != widget.user.isActive;

  String? _required(String? value) => value == null || value.trim().isEmpty
      ? 'Este campo es obligatorio.'
      : null;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final user = widget.user;
    final name = _name.text.trim(), lastName = _lastName.text.trim();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      // Solo se envía lo que cambió.
      await ref
          .read(userApiProvider)
          .updateUser(
            user.id,
            name: name == user.name ? null : name,
            lastName: lastName == user.lastName ? null : lastName,
            status: _active == user.isActive ? null : _active,
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
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: AppTheme.tint,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        _initials(widget.user),
                        style: const TextStyle(
                          color: AppTheme.green,
                          fontSize: 24,
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
                            '${widget.user.name} ${widget.user.lastName}',
                            style: const TextStyle(
                              color: AppTheme.ink,
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                            ),
                          ),
                          Text(
                            '${widget.user.email} · '
                            '${widget.user.role == 'admin' ? 'Administrador' : 'Cliente'}',
                            style: const TextStyle(
                              color: AppTheme.muted,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: SmTextField(
                        label: 'Nombre',
                        controller: _name,
                        enabled: !_saving,
                        textCapitalization: TextCapitalization.words,
                        maxLength: 100,
                        validator: _required,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: SmTextField(
                        label: 'Apellido',
                        controller: _lastName,
                        enabled: !_saving,
                        textCapitalization: TextCapitalization.words,
                        maxLength: 100,
                        validator: _required,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Cuenta activa',
                    style: TextStyle(
                      color: AppTheme.ink,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  subtitle: const Text(
                    'Si la desactivas, no podrá iniciar sesión',
                    style: TextStyle(color: AppTheme.muted, fontSize: 15),
                  ),
                  value: _active,
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _active = value),
                ),
                if (_error != null)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.dangerTint,
                      borderRadius: BorderRadius.circular(AppTheme.radiusS),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        color: AppTheme.danger,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _saving || !_changed ? null : _save,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(58),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: AppTheme.ink,
                          ),
                        )
                      : const Text('Guardar cambios'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NewUserInput {
  const _NewUserInput({
    required this.name,
    required this.lastName,
    required this.email,
    required this.password,
  });

  final String name;
  final String lastName;
  final String email;
  final String password;
}

class _NewUserDialog extends StatefulWidget {
  const _NewUserDialog();

  @override
  State<_NewUserDialog> createState() => _NewUserDialogState();
}

class _NewUserDialogState extends State<_NewUserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _required(String? value) => value == null || value.trim().isEmpty
      ? 'Este campo es obligatorio.'
      : null;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.person_add_alt_1, color: AppTheme.green),
      title: const Text('Nuevo usuario'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nombre'),
                textCapitalization: TextCapitalization.words,
                maxLength: 100,
                validator: _required,
              ),
              TextFormField(
                controller: _lastNameController,
                decoration: const InputDecoration(labelText: 'Apellido'),
                textCapitalization: TextCapitalization.words,
                maxLength: 100,
                validator: _required,
              ),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Correo'),
                keyboardType: TextInputType.emailAddress,
                maxLength: 255,
                validator: (value) {
                  final required = _required(value);
                  if (required != null) return required;
                  return value!.contains('@') ? null : 'Correo inválido.';
                },
              ),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Contraseña (mínimo 8 caracteres)',
                ),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.length < 8) {
                    return 'Usa al menos 8 caracteres.';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(
              context,
              _NewUserInput(
                name: _nameController.text.trim(),
                lastName: _lastNameController.text.trim(),
                email: _emailController.text.trim(),
                password: _passwordController.text,
              ),
            );
          },
          child: const Text('Crear'),
        ),
      ],
    );
  }
}
