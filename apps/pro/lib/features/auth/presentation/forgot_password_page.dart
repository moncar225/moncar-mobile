import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/application/app_providers.dart';
import '../../../core/application/session_controller.dart';
import '../../../core/data/pro_api.dart';
import '../../../core/ui/pro_kit.dart';
import '../widgets/auth_widgets.dart';

/// Mot de passe oublié — étape 1 : numéro du compte, puis code SMS et
/// nouveau mot de passe.
class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key, this.initialPhone});

  /// Numéro local pré-rempli depuis l'écran de connexion.
  final String? initialPhone;

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  late final _phone = TextEditingController(
    text: groupLocalPhone(widget.initialPhone ?? ''),
  );
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  String get _digits => phoneDigits(_phone.text);

  Future<void> _send() async {
    if (_digits.length != 10 || _loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(proApiProvider).requestOtp(_digits, mustExist: true);
      if (!mounted) return;
      ref.read(pendingAuthProvider.notifier).start(OtpPurpose.reset, _digits);
      context.push('/otp');
    } on ProApiException catch (e) {
      haptic(HapticKind.error);
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ProPage(
      title: 'Mot de passe oublié',
      bottom: MoncarButton(
        label: 'Recevoir un code SMS',
        icon: Icons.sms_rounded,
        variant: MoncarButtonVariant.primary,
        size: MoncarButtonSize.xl,
        expand: true,
        isLoading: _loading,
        onPressed: _digits.length == 10 ? _send : null,
      ),
      children: [
        const SizedBox(height: 12),
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: MoncarColors.brandSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.lock_reset_rounded,
              color: MoncarColors.brand,
              size: 34,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Réinitialiser votre mot de passe',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: MoncarColors.ink,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Saisissez le numéro de votre compte agent : nous vous envoyons '
          'un code pour choisir un nouveau mot de passe.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            height: 1.45,
            color: MoncarColors.inkMut,
          ),
        ),
        const SizedBox(height: 26),
        if (_error != null) ...[
          AuthErrorBanner(_error!),
          const SizedBox(height: 14),
        ],
        const FieldLabel('Numéro de téléphone'),
        PhoneField(
          controller: _phone,
          hasError: _error != null,
          textInputAction: TextInputAction.done,
          onChanged: (_) => setState(() => _error = null),
          onSubmitted: (_) => _send(),
        ),
      ],
    );
  }
}
