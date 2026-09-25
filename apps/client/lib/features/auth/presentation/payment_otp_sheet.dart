import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/foundation.dart';
import 'otp_page.dart' show OtpBoxes;

/// Confirmation d'un paiement par code SMS, si l'option « Confirmer les
/// paiements par OTP » est active (Profil → Sécurité). Renvoie `true`
/// quand le paiement peut être lancé.
Future<bool> confirmPaymentWithOtp(
  BuildContext context,
  WidgetRef ref, {
  required int amountXOF,
}) async {
  if (!ref.read(securitySettingsProvider).otpPayments) return true;
  final user = ref.read(authProvider).user;
  if (user == null) return false;
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: MoncarColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _PaymentOtpSheet(phone: user.phone, amountXOF: amountXOF),
  );
  return ok == true;
}

class _PaymentOtpSheet extends ConsumerStatefulWidget {
  const _PaymentOtpSheet({required this.phone, required this.amountXOF});

  final String phone;
  final int amountXOF;

  @override
  ConsumerState<_PaymentOtpSheet> createState() => _PaymentOtpSheetState();
}

class _PaymentOtpSheetState extends ConsumerState<_PaymentOtpSheet> {
  final _code = TextEditingController();
  final _focus = FocusNode();
  String? _demoCode;
  String? _error;

  @override
  void initState() {
    super.initState();
    _send();
  }

  @override
  void dispose() {
    _code.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// ⚠️ MOCK : POST /payments/otp — le code est affiché à l'écran en dev.
  void _send() {
    final r = ref.read(mockStoreProvider).requestOtp(widget.phone);
    setState(() {
      _demoCode = r.code;
      _error = null;
      _code.clear();
    });
  }

  void _verify(String code) {
    final ok = ref.read(mockStoreProvider).verifyOtp(widget.phone, code);
    if (ok) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _error = 'Code incorrect ou expiré.';
      _code.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            Icons.verified_user_outlined,
            size: 36,
            color: MoncarColors.brand,
          ),
          const SizedBox(height: 8),
          Text(
            'Confirmez votre paiement',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: MoncarColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Saisissez le code envoyé par SMS au ${widget.phone} pour payer ${formatXOF(widget.amountXOF)}.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: MoncarColors.inkMut),
          ),
          const SizedBox(height: 20),
          OtpBoxes(
            controller: _code,
            focusNode: _focus,
            onChanged: (v) {
              if (_error != null) setState(() => _error = null);
              if (v.length == 6) _verify(v);
            },
          ),
          SizedBox(
            height: 28,
            child: Center(
              child: _error == null
                  ? null
                  : Text(
                      _error!,
                      style: TextStyle(
                        fontSize: 12,
                        color: MoncarColors.danger,
                      ),
                    ),
            ),
          ),
          if (_demoCode != null)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: MoncarColors.brandSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'CODE DE DÉMO : $_demoCode (environnement de dev uniquement)',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: MoncarColors.brand,
                ),
              ),
            ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Annuler'),
              ),
              TextButton(
                onPressed: _send,
                child: const Text('Renvoyer le code'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
