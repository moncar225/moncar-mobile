import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/foundation.dart';
import '../application/auth_flow.dart';
import '../application/phone_auth.dart';
import '../widgets/auth_widgets.dart';

const _resendSeconds = 30;

/// Vérification OTP (parcours critique) : 6 cases, soumission auto,
/// secousse en cas d'erreur, renvoi après 30 s. Le code est vérifié
/// par Firebase Phone Auth (réel) — jamais par l'écran. Sert à
/// l'inscription ([OtpPurpose.signup]) et au mot de passe oublié
/// ([OtpPurpose.reset]).
class OtpPage extends ConsumerStatefulWidget {
  const OtpPage({
    super.key,
    required this.phone,
    this.purpose = OtpPurpose.signup,
  });

  final String phone;
  final OtpPurpose purpose;

  @override
  ConsumerState<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends ConsumerState<OtpPage>
    with SingleTickerProviderStateMixin {
  final _code = TextEditingController();
  final _focus = FocusNode();
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );
  Timer? _timer;
  int _resendIn = _resendSeconds;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.phone.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/auth/login');
      });
      return;
    }
    _startCountdown();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _resendIn = _resendSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _resendIn -= 1);
      if (_resendIn <= 0) t.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    _focus.dispose();
    _shake.dispose();
    super.dispose();
  }

  Future<void> _verify(String c) async {
    if (c.length != 6 || _loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    if (MoncarPhoneAuth.enabled) {
      // Réel : Firebase confirme le code (le code de test 123456 n'est
      // accepté que pour les numéros déclarés dans Firebase Console).
      final ok = await MoncarPhoneAuth.verifyCode(c);
      if (!mounted) return;
      if (ok) {
        await _complete();
        return;
      }
      _fail(MoncarPhoneAuth.lastError ?? 'Code OTP invalide ou expiré');
      return;
    }
    // ⚠️ MOCK (tests uniquement) : POST /auth/otp/verify simulé.
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    if (ref.read(mockStoreProvider).verifyOtp(widget.phone, c)) {
      await _complete();
      return;
    }
    _fail('Code OTP invalide ou expiré');
  }

  /// Numéro vérifié : suite du parcours (création du compte ou choix
  /// du nouveau mot de passe).
  Future<void> _complete() async {
    final error = await completePhoneVerification(
      context,
      ref,
      purpose: widget.purpose,
      phone: widget.phone,
    );
    if (!mounted || error == null) return;
    setState(() {
      _loading = false;
      _error = error;
      _code.clear();
    });
    showMoncarToast(context, error, error: true);
  }

  void _fail(String message) {
    setState(() {
      _loading = false;
      _error = message;
      _code.clear();
    });
    _shake.forward(from: 0);
    HapticFeedback.mediumImpact();
  }

  Future<void> _resend() async {
    if (_resendIn > 0 || _loading) return;
    _startCountdown();
    setState(() {
      _code.clear();
      _error = null;
    });
    if (MoncarPhoneAuth.enabled) {
      // Réel : redemande à Firebase d'envoyer un nouveau code.
      await MoncarPhoneAuth.sendCode(
        widget.phone,
        onCodeSent: () {},
        onSignedIn: () {
          if (mounted) _complete();
        },
        onError: (message) {
          if (!mounted) return;
          setState(() => _error = message);
        },
      );
      return;
    }
    // ⚠️ MOCK (tests uniquement).
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    final r = ref.read(mockStoreProvider).requestOtp(widget.phone);
    showDemoOtpCode(context, r.code, widget.phone);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.phone.isEmpty) return const Scaffold();
    final isReset = widget.purpose == OtpPurpose.reset;
    return Scaffold(
      backgroundColor: MoncarColors.background,
      appBar: TopBar(
        title: isReset ? 'Réinitialisation' : 'Vérification',
        showBack: true,
        showBell: false,
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isReset) ...[
                const ResetStepsIndicator(current: 2),
                const SizedBox(height: 28),
              ],
              Text(
                isReset ? 'Code de vérification' : 'Vérifiez votre numéro',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: MoncarColors.ink,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Saisissez le code à 6 chiffres reçu par SMS',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: MoncarColors.inkMut),
              ),
              const SizedBox(height: 2),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'au ',
                    style: TextStyle(fontSize: 14, color: MoncarColors.inkMut),
                  ),
                  GestureDetector(
                    onTap: () => context.mcBack(),
                    child: Text(
                      formatPhoneDisplay(widget.phone),
                      semanticsLabel: 'Modifier le numéro de téléphone',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: MoncarColors.brand,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              AnimatedBuilder(
                animation: _shake,
                builder: (context, child) {
                  final t = _shake.value;
                  final dx = math.sin(t * math.pi * 6) * 10 * (1 - t);
                  return Transform.translate(
                    offset: Offset(dx, 0),
                    child: child,
                  );
                },
                child: OtpBoxes(
                  controller: _code,
                  focusNode: _focus,
                  enabled: !_loading,
                  onChanged: (v) {
                    setState(() => _error = null);
                    if (v.length == 6) _verify(v);
                  },
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 28,
                child: Center(
                  child: _error != null
                      ? Text(
                          _error!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: MoncarColors.danger,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.verified_user_outlined,
                              size: 14,
                              color: MoncarColors.success,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Code sécurisé — ne le partagez avec personne.',
                              style: TextStyle(
                                fontSize: 11,
                                color: MoncarColors.inkFaint,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: _resendIn > 0
                    ? RichText(
                        text: TextSpan(
                          style: TextStyle(
                            fontSize: 13,
                            color: MoncarColors.inkMut,
                          ),
                          children: [
                            const TextSpan(text: 'Renvoyer le code dans '),
                            TextSpan(
                              text: '${_resendIn}s',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: MoncarColors.ink,
                              ),
                            ),
                          ],
                        ),
                      )
                    : TextButton(
                        onPressed: _loading ? null : _resend,
                        child: Text(
                          'Renvoyer le code',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: MoncarColors.accent,
                          ),
                        ),
                      ),
              ),
              const Spacer(),
              MoncarButton(
                label: isReset ? 'Continuer' : 'Vérifier et créer mon compte',
                variant: MoncarButtonVariant.primary,
                size: MoncarButtonSize.xl,
                expand: true,
                isLoading: _loading,
                onPressed: _code.text.length == 6 && !_loading
                    ? () => _verify(_code.text)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Six cases OTP adossées à un champ unique invisible (collage et
/// autofill SMS compris).
class OtpBoxes extends StatelessWidget {
  const OtpBoxes({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    this.enabled = true,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => focusNode.requestFocus(),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Champ réel, invisible mais focusable.
          Opacity(
            opacity: 0,
            child: SizedBox(
              width: 1,
              height: 1,
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                autofocus: true,
                enabled: enabled,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: onChanged,
              ),
            ),
          ),
          ListenableBuilder(
            listenable: Listenable.merge([controller, focusNode]),
            builder: (context, _) {
              final text = controller.text;
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < 6; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    _OtpSlot(
                      char: i < text.length ? text[i] : '',
                      active:
                          focusNode.hasFocus &&
                          (i == text.length || (i == 5 && text.length == 6)),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _OtpSlot extends StatelessWidget {
  const _OtpSlot({required this.char, required this.active});

  final String char;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 44,
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: MoncarColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: active
              ? MoncarColors.accent
              : MoncarColors.brand.withValues(alpha: 0.25),
          width: 2,
        ),
        boxShadow: [
          if (active)
            BoxShadow(
              color: MoncarColors.accent.withValues(alpha: 0.3),
              spreadRadius: 3,
            ),
        ],
      ),
      child: Text(
        char,
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: MoncarColors.ink,
        ),
      ),
    );
  }
}
