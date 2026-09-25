import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/application/app_providers.dart';
import '../../../core/application/session_controller.dart';
import '../../../core/data/pro_api.dart';
import '../../../core/ui/pro_kit.dart';
import '../widgets/auth_widgets.dart';

/// Connexion agent : numéro (+225) + mot de passe, accès au parcours
/// « mot de passe oublié » et à la création de compte (même parcours
/// que l'app client). Le poste est celui choisi à l'inscription.
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _phone = TextEditingController();
  final _password = TextEditingController();
  String? _error;
  bool _loading = false;

  String get _digits => phoneDigits(_phone.text);
  bool get _canSubmit =>
      _digits.length == 10 && _password.text.isNotEmpty && !_loading;

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  void _changed(String _) => setState(() => _error = null);

  Future<void> _submit() async {
    if (!_canSubmit) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      final user = await ref
          .read(proApiProvider)
          .login(phone: _digits, password: _password.text);
      if (!mounted) return;
      TextInput.finishAutofillContext();
      haptic(HapticKind.success);
      showProToast(
        context,
        'Bon retour, ${user.firstName} !',
        tone: ToastTone.success,
      );
      ref.read(sessionProvider.notifier).signIn(user);
    } on ProApiException catch (e) {
      haptic(HapticKind.error);
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _password.clear();
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _forgot() {
    context.push(
      _digits.length == 10
          ? '/mot-de-passe-oublie?tel=$_digits'
          : '/mot-de-passe-oublie',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MoncarColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
                  child: AutofillGroup(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Center(child: ProLogo(size: 76, ring: true)),
                        const SizedBox(height: 16),
                        const Center(child: ProWordmark(fontSize: 22)),
                        const SizedBox(height: 18),
                        Text(
                          'Connexion',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: MoncarColors.ink,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Heureux de vous revoir ! Connectez-vous avec '
                          'votre numéro et votre mot de passe.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.45,
                            color: MoncarColors.inkMut,
                          ),
                        ),
                        const SizedBox(height: 28),
                        if (_error != null) ...[
                          AuthErrorBanner(_error!),
                          const SizedBox(height: 16),
                        ],
                        const FieldLabel('Numéro de téléphone'),
                        PhoneField(
                          controller: _phone,
                          hasError: _error != null,
                          textInputAction: TextInputAction.next,
                          onChanged: _changed,
                        ),
                        const SizedBox(height: 16),
                        const FieldLabel('Mot de passe'),
                        PasswordField(
                          controller: _password,
                          textInputAction: TextInputAction.done,
                          onChanged: _changed,
                          onSubmitted: (_) => _submit(),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _loading ? null : _forgot,
                            child: Text(
                              'Mot de passe oublié ?',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: MoncarColors.brand,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        MoncarButton(
                          label: 'Se connecter',
                          variant: MoncarButtonVariant.primary,
                          size: MoncarButtonSize.xl,
                          expand: true,
                          isLoading: _loading,
                          onPressed: _canSubmit ? _submit : null,
                        ),
                        const SizedBox(height: 26),
                        Row(
                          children: [
                            Expanded(
                              child: Divider(color: MoncarColors.hairline),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: Text(
                                'Nouvel agent ?',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: MoncarColors.inkFaint,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Divider(color: MoncarColors.hairline),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        MoncarButton(
                          label: 'Créer mon compte agent',
                          variant: MoncarButtonVariant.outline,
                          size: MoncarButtonSize.xl,
                          expand: true,
                          onPressed: _loading
                              ? null
                              : () => context.push('/inscription'),
                        ),
                        if (kDemoMode) ...[
                          const SizedBox(height: 18),
                          const _DemoAccounts(),
                        ],
                        const Spacer(),
                        const SizedBox(height: 24),
                        const TermsNotice(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DemoAccounts extends StatelessWidget {
  const _DemoAccounts();

  @override
  Widget build(BuildContext context) {
    return InfoBanner(
      icon: Icons.science_rounded,
      color: MoncarColors.accent,
      message:
          'Démo — mot de passe « ${MockProApi.demoPassword} » :\n'
          '07 00 00 00 01 Contrôleur · 02 Convoyeur · 03 Chauffeur · '
          '04 Agent BUSINESS · 05 Multi-postes.\n'
          '« Temp1234 » simule un mot de passe temporaire. Code SMS : '
          '${MockProApi.demoOtp}.',
    );
  }
}
