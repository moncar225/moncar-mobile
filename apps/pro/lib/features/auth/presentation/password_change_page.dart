import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/application/app_providers.dart';
import '../../../core/application/session_controller.dart';
import '../../../core/data/pro_api.dart';
import '../../../core/ui/pro_kit.dart';
import '../widgets/auth_widgets.dart';

/// Nouveau mot de passe, dans deux cas :
/// - [reset] = false : mot de passe temporaire à changer à la 1re
///   connexion (CDC — comptes créés par l'administration) ;
/// - [reset] = true : fin du parcours « mot de passe oublié ».
/// Politique définitive fixée par le serveur (⚠ T-8).
class PasswordChangePage extends ConsumerStatefulWidget {
  const PasswordChangePage({super.key, this.reset = false});

  final bool reset;

  @override
  ConsumerState<PasswordChangePage> createState() => _PasswordChangePageState();
}

class _PasswordChangePageState extends ConsumerState<PasswordChangePage> {
  final _p1 = TextEditingController();
  final _p2 = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _p1.addListener(() => setState(() => _error = null));
    _p2.addListener(() => setState(() => _error = null));
  }

  @override
  void dispose() {
    _p1.dispose();
    _p2.dispose();
    super.dispose();
  }

  bool get _valid => isPasswordValid(_p1.text) && _p1.text == _p2.text;

  Future<void> _save() async {
    setState(() => _loading = true);
    final api = ref.read(proApiProvider);
    try {
      if (widget.reset) {
        final phone = ref.read(pendingAuthProvider)?.phone ?? '';
        await api.resetPassword(phone: phone, password: _p1.text);
        if (!mounted) return;
        ref.read(pendingAuthProvider.notifier).clear();
        showProToast(
          context,
          'Mot de passe modifié. Connectez-vous.',
          tone: ToastTone.success,
        );
        context.go('/login');
      } else {
        final phone = ref.read(sessionProvider).user?.phone ?? '';
        await api.changeTemporaryPassword(phone: phone, newPassword: _p1.text);
        if (!mounted) return;
        haptic(HapticKind.success);
        showProToast(
          context,
          'Mot de passe mis à jour.',
          tone: ToastTone.success,
        );
        ref.read(sessionProvider.notifier).passwordChanged();
      }
    } on ProApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(sessionProvider).user;
    return Scaffold(
      backgroundColor: MoncarColors.background,
      body: SafeArea(
        child: Column(
          children: [
            if (widget.reset) const ProHeader(title: 'Nouveau mot de passe'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: MoncarColors.accentSoft,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      Icons.key_rounded,
                      color: MoncarColors.accent,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Choisissez votre mot de passe',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: MoncarColors.ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.reset
                        ? 'Votre numéro est vérifié. Choisissez un nouveau mot de passe.'
                        : 'Bonjour ${user?.firstName ?? ''}, votre compte a été créé par '
                              'votre compagnie avec un mot de passe temporaire. '
                              'Remplacez-le pour continuer.',
                    style: TextStyle(color: MoncarColors.inkMut, height: 1.4),
                  ),
                  const SizedBox(height: 24),
                  if (_error != null) ...[
                    AuthErrorBanner(_error!),
                    const SizedBox(height: 12),
                  ],
                  PasswordField(
                    controller: _p1,
                    hint: 'Nouveau mot de passe',
                    isNew: true,
                  ),
                  const SizedBox(height: 12),
                  PasswordField(
                    controller: _p2,
                    hint: 'Confirmer le mot de passe',
                    isNew: true,
                  ),
                  const SizedBox(height: 14),
                  PasswordChecklist(password: _p1.text, confirm: _p2.text),
                  const SizedBox(height: 24),
                  MoncarButton(
                    label: 'Enregistrer et continuer',
                    icon: Icons.check_rounded,
                    variant: MoncarButtonVariant.primary,
                    size: MoncarButtonSize.xl,
                    expand: true,
                    isLoading: _loading,
                    onPressed: _valid ? _save : null,
                  ),
                  if (!widget.reset)
                    TextButton(
                      onPressed: () =>
                          ref.read(sessionProvider.notifier).signOut(),
                      child: const Text('Se déconnecter'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
