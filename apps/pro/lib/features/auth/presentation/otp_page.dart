import 'dart:async';
import 'dart:math' as math;

import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/application/app_providers.dart';
import '../../../core/application/session_controller.dart';
import '../../../core/data/mock_data.dart';
import '../../../core/data/pro_api.dart';
import '../../../core/ui/pro_kit.dart';
import '../widgets/auth_widgets.dart';

/// Vérification du numéro par code SMS à 6 chiffres (inscription ou mot
/// de passe oublié). Renvoi possible après 45 s.
class OtpPage extends ConsumerStatefulWidget {
  const OtpPage({super.key});

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
  int _resendIn = 45;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startTimer();
    if (kDemoMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          showProToast(context, 'Démo : code SMS ${MockProApi.demoOtp}');
        }
      });
    }
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _resendIn = 45);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_resendIn <= 1) t.cancel();
      setState(() => _resendIn--);
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

  Future<void> _verify(String code) async {
    final pending = ref.read(pendingAuthProvider);
    if (pending == null || _loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final api = ref.read(proApiProvider);
    try {
      switch (pending.purpose) {
        case OtpPurpose.signup:
          final user = await api.confirmSignup(
            phone: pending.phone,
            code: code,
          );
          if (!mounted) return;
          haptic(HapticKind.success);
          ref.read(pendingAuthProvider.notifier).clear();
          showProToast(
            context,
            'Bienvenue ${user.firstName} ! Votre compte ${user.roles.first.label} est créé.',
            tone: ToastTone.success,
          );
          ref.read(sessionProvider.notifier).signIn(user);
        case OtpPurpose.reset:
          await api.verifyResetOtp(phone: pending.phone, code: code);
          if (!mounted) return;
          haptic(HapticKind.success);
          ref.read(pendingAuthProvider.notifier).markVerified();
          context.pushReplacement('/nouveau-mot-de-passe');
      }
    } on ProApiException catch (e) {
      haptic(HapticKind.error);
      _shake.forward(from: 0);
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _code.clear();
      });
      _focus.requestFocus();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    final pending = ref.read(pendingAuthProvider);
    if (pending == null) return;
    await ref.read(proApiProvider).requestOtp(pending.phone);
    if (!mounted) return;
    _startTimer();
    showProToast(context, 'Nouveau code envoyé par SMS.');
  }

  @override
  Widget build(BuildContext context) {
    final pending = ref.watch(pendingAuthProvider);
    if (pending == null) return const SizedBox.shrink();
    final isReset = pending.purpose == OtpPurpose.reset;
    return Scaffold(
      backgroundColor: MoncarColors.background,
      body: SafeArea(
        child: Column(
          children: [
            ProHeader(title: isReset ? 'Mot de passe oublié' : 'Vérification'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                children: [
                  Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: MoncarColors.brandSoft,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.sms_rounded,
                        color: MoncarColors.brand,
                        size: 34,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    isReset ? 'Code de vérification' : 'Vérifiez votre numéro',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: MoncarColors.ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Saisissez le code à 6 chiffres reçu par SMS au',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: MoncarColors.inkMut),
                  ),
                  Center(
                    child: TextButton(
                      onPressed: () => context.pop(),
                      child: Text(
                        formatCiPhone(pending.phone),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: MoncarColors.brand,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
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
                      hasError: _error != null,
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
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: MoncarColors.danger,
                              ),
                            )
                          : Text(
                              'Code sécurisé — ne le partagez avec personne.',
                              style: TextStyle(
                                fontSize: 12,
                                color: MoncarColors.inkFaint,
                              ),
                            ),
                    ),
                  ),
                  Center(
                    child: _resendIn > 0
                        ? Text(
                            'Renvoyer le code dans ${_resendIn}s',
                            style: TextStyle(
                              fontSize: 13,
                              color: MoncarColors.inkMut,
                            ),
                          )
                        : TextButton(
                            onPressed: _loading ? null : _resend,
                            child: Text(
                              'Renvoyer le code',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: MoncarColors.accent,
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: MoncarButton(
                label: isReset ? 'Continuer' : 'Vérifier et créer mon compte',
                variant: MoncarButtonVariant.primary,
                size: MoncarButtonSize.xl,
                expand: true,
                isLoading: _loading,
                onPressed: _code.text.length == 6 && !_loading
                    ? () => _verify(_code.text)
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
