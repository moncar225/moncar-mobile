import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/foundation.dart';
import '../application/auth_flow.dart';
import '../application/phone_auth.dart';
import '../widgets/auth_widgets.dart';

/// Connexion numéro (+225) + mot de passe, avec accès au parcours
/// « mot de passe oublié » (réinitialisation par OTP SMS).
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key, this.initialPhone});

  /// Numéro pré-rempli (« +2250700112233 »), ex. après une inscription
  /// sur un numéro déjà enregistré.
  final String? initialPhone;

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  late final _phone = TextEditingController(
    text: widget.initialPhone == null
        ? ''
        : localPhoneInput(widget.initialPhone!),
  );
  final _password = TextEditingController();
  String? _error;
  bool _loading = false;

  String get _digits => _phone.text.replaceAll(RegExp(r'\D'), '');
  bool get _canSubmit =>
      _digits.length == 10 && _password.text.isNotEmpty && !_loading;

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  void _clearError() {
    if (_error != null) setState(() => _error = null);
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    FocusScope.of(context).unfocus();
    final fullPhone = fullCiPhone(_phone.text);
    setState(() {
      _error = null;
      _loading = true;
    });
    String? error;
    if (MoncarPhoneAuth.enabled) {
      error = await MoncarPhoneAuth.signInWithPassword(
        fullPhone,
        _password.text,
      );
    } else {
      // ⚠️ MOCK (tests uniquement) : POST /auth/login simulé.
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (!ref
          .read(mockStoreProvider)
          .checkPassword(fullPhone, _password.text)) {
        error = 'Numéro ou mot de passe incorrect.';
      }
    }
    if (!mounted) return;
    if (error != null) {
      HapticFeedback.mediumImpact();
      setState(() {
        _loading = false;
        _error = error;
        _password.clear();
      });
      return;
    }
    TextInput.finishAutofillContext();
    openAppSession(ref);
    final firstName = ref.read(authProvider).user?.firstName;
    showMoncarToast(
      context,
      firstName == null ? 'Vous êtes connecté.' : 'Bon retour, $firstName !',
      success: true,
    );
    context.go('/home');
  }

  void _forgotPassword() {
    final phone = _digits.length == 10
        ? '?phone=${Uri.encodeComponent(fullCiPhone(_digits))}'
        : '';
    context.push('/auth/forgot$phone');
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
                  padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
                  child: AutofillGroup(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Center(child: MonCarLogo(size: 64)),
                        const SizedBox(height: 16),
                        Text(
                          'Connexion',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
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
                        const SizedBox(height: 32),
                        // Pas d'AnimatedSize ici : ses hauteurs intrinsèques faussent
                        // IntrinsicHeight (débordement quand le bandeau apparaît).
                        if (_error != null) ...[
                          AuthErrorBanner(_error!),
                          const SizedBox(height: 16),
                        ],
                        const MoncarLabel('Numéro de téléphone'),
                        PhoneField(
                          controller: _phone,
                          hasError: _error != null,
                          textInputAction: TextInputAction.next,
                          onChanged: (_) {
                            _clearError();
                            setState(() {});
                          },
                        ),
                        const SizedBox(height: 16),
                        PasswordField(
                          controller: _password,
                          label: 'Mot de passe',
                          textInputAction: TextInputAction.done,
                          onChanged: (_) {
                            _clearError();
                            setState(() {});
                          },
                          onSubmitted: (_) => _submit(),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _loading ? null : _forgotPassword,
                            child: Text(
                              'Mot de passe oublié ?',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: MoncarColors.brand,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        MoncarButton(
                          label: 'Se connecter',
                          variant: MoncarButtonVariant.primary,
                          size: MoncarButtonSize.xl,
                          expand: true,
                          isLoading: _loading,
                          onPressed: _canSubmit ? _submit : null,
                        ),
                        const SizedBox(height: 28),
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
                                'Nouveau sur MON CAR ?',
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
                          label: 'Créer un compte',
                          variant: MoncarButtonVariant.outline,
                          size: MoncarButtonSize.xl,
                          expand: true,
                          onPressed: _loading
                              ? null
                              : () => context.push('/auth/inscription'),
                        ),
                        const Spacer(),
                        const SizedBox(height: 32),
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
