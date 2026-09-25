import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/foundation.dart';
import '../application/auth_flow.dart';
import '../application/phone_auth.dart';
import '../widgets/auth_widgets.dart';

/// Mot de passe oublié — étape 1 : saisie du numéro, envoi d'un code
/// OTP par SMS pour prouver la possession du numéro.
class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key, this.initialPhone});

  final String? initialPhone;

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  late final _phone = TextEditingController(
    text: widget.initialPhone == null
        ? ''
        : localPhoneInput(widget.initialPhone!),
  );
  String? _error;
  bool _noAccount = false;
  bool _loading = false;

  bool get _isValid => _phone.text.replaceAll(RegExp(r'\D'), '').length == 10;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = message;
      _noAccount = message == MoncarPhoneAuth.noAccountMessage;
    });
  }

  Future<void> _submit() async {
    if (!_isValid || _loading) return;
    FocusScope.of(context).unfocus();
    final fullPhone = fullCiPhone(_phone.text);
    ref.read(verifiedResetPhoneProvider.notifier).state = null;
    setState(() {
      _error = null;
      _noAccount = false;
      _loading = true;
    });
    final otpRoute =
        '/auth/otp?phone=${Uri.encodeComponent(fullPhone)}&purpose=reset';
    if (MoncarPhoneAuth.enabled) {
      await MoncarPhoneAuth.sendCode(
        fullPhone,
        onCodeSent: () {
          if (!mounted) return;
          setState(() => _loading = false);
          context.push(otpRoute);
        },
        onSignedIn: () async {
          // Vérification automatique Android : pas de code à saisir.
          if (!mounted) return;
          final error = await completePhoneVerification(
            context,
            ref,
            purpose: OtpPurpose.reset,
            phone: fullPhone,
          );
          if (error != null) _fail(error);
        },
        onError: _fail,
      );
      return;
    }
    // ⚠️ MOCK (tests uniquement) : POST /auth/password/forgot simulé.
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    final store = ref.read(mockStoreProvider);
    if (!store.hasAccount(fullPhone)) {
      _fail(MoncarPhoneAuth.noAccountMessage);
      return;
    }
    final r = store.requestOtp(fullPhone);
    setState(() => _loading = false);
    showDemoOtpCode(context, r.code, fullPhone);
    context.push(otpRoute);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MoncarColors.background,
      appBar: const TopBar(
        title: 'Réinitialisation',
        showBack: true,
        showBell: false,
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          children: [
            const ResetStepsIndicator(current: 1),
            const SizedBox(height: 28),
            const AuthHeader(
              icon: Icons.lock_reset,
              title: 'Mot de passe oublié ?',
              subtitle:
                  'Entrez le numéro associé à votre compte. Nous vous '
                  'enverrons un code de vérification par SMS.',
            ),
            const SizedBox(height: 28),
            if (_error != null) ...[
              AuthErrorBanner(_error!),
              if (_noAccount)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => context.go('/auth/inscription'),
                    child: Text(
                      'Créer un compte',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: MoncarColors.brand,
                      ),
                    ),
                  ),
                )
              else
                const SizedBox(height: 16),
            ],
            const MoncarLabel('Numéro de téléphone'),
            PhoneField(
              controller: _phone,
              autofocus: widget.initialPhone == null,
              hasError: _error != null,
              textInputAction: TextInputAction.done,
              onChanged: (_) => setState(() => _error = null),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 24),
            MoncarButton(
              label: 'Recevoir le code',
              icon: Icons.sms_outlined,
              variant: MoncarButtonVariant.primary,
              size: MoncarButtonSize.xl,
              expand: true,
              isLoading: _loading,
              onPressed: _isValid && !_loading ? _submit : null,
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _loading ? null : () => context.mcBack(),
              child: Text(
                'Je me souviens de mon mot de passe',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: MoncarColors.inkMut,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mot de passe oublié — étape 3 : choix du nouveau mot de passe,
/// accessible uniquement après la vérification OTP du numéro.
class NewPasswordPage extends ConsumerStatefulWidget {
  const NewPasswordPage({super.key});

  @override
  ConsumerState<NewPasswordPage> createState() => _NewPasswordPageState();
}

class _NewPasswordPageState extends ConsumerState<NewPasswordPage> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _confirmTouched = false;
  bool _saving = false;
  bool _done = false;
  String? _error;

  late final String? _phone = ref.read(verifiedResetPhoneProvider);

  bool get _matches => _password.text == _confirm.text;
  bool get _canSubmit =>
      isPasswordValid(_password.text) && _matches && !_saving;

  @override
  void initState() {
    super.initState();
    if (_phone == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/auth/login');
      });
    }
  }

  @override
  void dispose() {
    // Parcours abandonné : la session Firebase ouverte par l'OTP est
    // refermée (l'app n'a pas ouvert de session).
    if (!_done && MoncarPhoneAuth.enabled) MoncarPhoneAuth.signOut();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final phone = _phone;
    if (!_canSubmit || phone == null) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    String? error;
    if (MoncarPhoneAuth.enabled) {
      error = await MoncarPhoneAuth.resetPassword(phone, _password.text);
    } else {
      // ⚠️ MOCK (tests uniquement) : POST /auth/password/reset simulé.
      await Future<void>.delayed(const Duration(milliseconds: 600));
      ref.read(mockStoreProvider).setPassword(phone, _password.text);
    }
    if (!mounted) return;
    if (error != null) {
      HapticFeedback.mediumImpact();
      setState(() {
        _saving = false;
        _error = error;
      });
      return;
    }
    _done = true;
    TextInput.finishAutofillContext();
    ref.read(verifiedResetPhoneProvider.notifier).state = null;
    openAppSession(ref);
    showMoncarToast(
      context,
      'Mot de passe mis à jour. Vous êtes connecté.',
      success: true,
    );
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final phone = _phone;
    if (phone == null) return const Scaffold();
    // Pas d'erreur tant que la confirmation est en cours de saisie.
    final confirmError =
        _confirmTouched &&
            _confirm.text.length >= _password.text.length &&
            !_matches
        ? 'Les mots de passe ne correspondent pas.'
        : null;
    return Scaffold(
      backgroundColor: MoncarColors.background,
      appBar: const TopBar(
        title: 'Réinitialisation',
        showBack: true,
        showBell: false,
      ),
      body: SafeArea(
        top: false,
        child: AutofillGroup(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            children: [
              const ResetStepsIndicator(current: 3),
              const SizedBox(height: 28),
              AuthHeader(
                icon: Icons.lock_outline,
                title: 'Nouveau mot de passe',
                subtitle:
                    'Numéro vérifié : ${formatPhoneDisplay(phone)}.\n'
                    "Choisissez un mot de passe que vous n'utilisez pas ailleurs.",
              ),
              const SizedBox(height: 28),
              if (_error != null) ...[
                AuthErrorBanner(_error!),
                const SizedBox(height: 16),
              ],
              PasswordField(
                controller: _password,
                label: 'Nouveau mot de passe',
                hint: 'Au moins 8 caractères',
                isNew: true,
                autofocus: true,
                textInputAction: TextInputAction.next,
                onChanged: (_) => setState(() => _error = null),
              ),
              PasswordStrengthMeter(password: _password.text),
              const SizedBox(height: 20),
              PasswordField(
                controller: _confirm,
                label: 'Confirmer le mot de passe',
                hint: 'Saisissez-le à nouveau',
                isNew: true,
                error: confirmError,
                textInputAction: TextInputAction.done,
                onChanged: (_) => setState(() {
                  _confirmTouched = true;
                  _error = null;
                }),
                onSubmitted: (_) => _submit(),
              ),
              if (confirmError == null &&
                  _confirm.text.isNotEmpty &&
                  _matches &&
                  isPasswordValid(_password.text))
                const PasswordMatchHint(),
              const SizedBox(height: 28),
              MoncarButton(
                label: 'Enregistrer et me connecter',
                variant: MoncarButtonVariant.primary,
                size: MoncarButtonSize.xl,
                expand: true,
                isLoading: _saving,
                onPressed: _canSubmit ? _submit : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
