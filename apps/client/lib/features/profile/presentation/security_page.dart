import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/foundation.dart';

/// Sécurité : méthode de connexion (OTP), code PIN de verrouillage
/// (demandé au retour dans l'app), biométrie, confirmation OTP des
/// paiements et appareils connectés. Réglages persistés sur l'appareil.
class SecurityPage extends ConsumerWidget {
  const SecurityPage({super.key});

  // ----------------------------- Code PIN -----------------------------

  Future<void> _createPin(BuildContext context, WidgetRef ref) async {
    final pin = await _PinSheet.show(
      context,
      title: 'Choisissez un code PIN',
      subtitle: 'Il vous sera demandé à chaque ouverture de MON CAR.',
      validate: (code) =>
          _isWeak(code) ? 'Code trop simple, choisissez-en un autre.' : null,
    );
    if (pin == null || !context.mounted) return;
    final confirmed = await _PinSheet.show(
      context,
      title: 'Confirmez votre code PIN',
      subtitle: 'Saisissez à nouveau le même code.',
      validate: (code) =>
          code == pin ? null : 'Les codes ne correspondent pas.',
    );
    if (confirmed == null || !context.mounted) return;
    ref.read(securitySettingsProvider.notifier).setPin(pin);
    showMoncarToast(context, 'Code PIN activé.', success: true);
  }

  Future<bool> _checkCurrentPin(BuildContext context, WidgetRef ref) async {
    final security = ref.read(securitySettingsProvider.notifier);
    final ok = await _PinSheet.show(
      context,
      title: 'Code PIN actuel',
      subtitle: 'Confirmez votre identité pour continuer.',
      validate: (code) =>
          security.verifyPin(code) ? null : 'Code PIN incorrect.',
    );
    return ok != null;
  }

  Future<void> _changePin(BuildContext context, WidgetRef ref) async {
    if (!await _checkCurrentPin(context, ref) || !context.mounted) return;
    await _createPin(context, ref);
  }

  Future<void> _removePin(BuildContext context, WidgetRef ref) async {
    if (!await _checkCurrentPin(context, ref) || !context.mounted) return;
    ref.read(securitySettingsProvider.notifier).clearPin();
    showMoncarToast(context, 'Code PIN désactivé.', success: true);
  }

  Future<void> _toggleBiometric(
    BuildContext context,
    WidgetRef ref,
    bool enable,
  ) async {
    final security = ref.read(securitySettingsProvider.notifier);
    if (!enable) {
      security.setBiometric(false);
      showMoncarToast(context, 'Déverrouillage biométrique désactivé.');
      return;
    }
    if (!await Biometrics.available()) {
      if (context.mounted) {
        showMoncarToast(
          context,
          'Aucune empreinte ou reconnaissance faciale configurée sur ce téléphone.',
          error: true,
        );
      }
      return;
    }
    // On vérifie tout de suite que le capteur reconnaît l'utilisateur.
    final ok = await Biometrics.authenticate(
      'Confirmez pour activer le déverrouillage biométrique',
    );
    if (!context.mounted) return;
    if (!ok) {
      showMoncarToast(
        context,
        'Vérification biométrique annulée.',
        error: true,
      );
      return;
    }
    security.setBiometric(true);
    showMoncarToast(
      context,
      'Déverrouillage biométrique activé.',
      success: true,
    );
  }

  static bool _isWeak(String code) {
    if (code.split('').toSet().length == 1) return true; // 0000, 1111…
    const seqs = ['0123456789', '9876543210'];
    return seqs.any((s) => s.contains(code));
  }

  // ----------------------------- Appareils -----------------------------

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String body,
    required String action,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: MoncarColors.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(action),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _revokeDevice(
    BuildContext context,
    WidgetRef ref,
    UserDevice device,
  ) async {
    final ok = await _confirm(
      context,
      title: 'Déconnecter cet appareil ?',
      body:
          '« ${device.label} » devra se reconnecter avec un code SMS pour accéder à votre compte.',
      action: 'Déconnecter',
    );
    final user = ref.read(authProvider).user;
    if (!ok || user == null || !context.mounted) return;
    // ⚠️ MOCK : DELETE /users/me/devices/{id}
    ref
        .read(authProvider.notifier)
        .updateUser(
          user.copyWith(
            devices: user.devices.where((d) => d.id != device.id).toList(),
          ),
        );
    showMoncarToast(context, '${device.label} déconnecté.', success: true);
  }

  Future<void> _revokeOthers(BuildContext context, WidgetRef ref) async {
    final ok = await _confirm(
      context,
      title: 'Déconnecter les autres appareils ?',
      body:
          'Tous les appareils sauf celui-ci seront déconnectés de votre compte MON CAR.',
      action: 'Tout déconnecter',
    );
    final user = ref.read(authProvider).user;
    if (!ok || user == null || !context.mounted) return;
    // ⚠️ MOCK : POST /users/me/devices/revoke-others
    ref
        .read(authProvider.notifier)
        .updateUser(
          user.copyWith(devices: user.devices.where((d) => d.current).toList()),
        );
    showMoncarToast(
      context,
      'Les autres appareils ont été déconnectés.',
      success: true,
    );
  }

  // ----------------------------- UI -----------------------------

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final security = ref.watch(securitySettingsProvider);

    if (user == null) {
      return Scaffold(
        backgroundColor: MoncarColors.background,
        appBar: const TopBar(
          title: 'Sécurité',
          showBack: true,
          showBell: false,
        ),
        body: Center(
          child: Text(
            'Session expirée.',
            style: TextStyle(fontSize: 14, color: MoncarColors.inkMut),
          ),
        ),
      );
    }

    final others = user.devices.where((d) => !d.current).length;

    return Scaffold(
      backgroundColor: MoncarColors.background,
      appBar: const TopBar(title: 'Sécurité', showBack: true, showBell: false),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _StatusCard(hasPin: security.hasPin),
          const SizedBox(height: 20),

          const _SectionTitle('Connexion'),
          MoncarCard(
            padding: const EdgeInsets.all(6),
            child: _Row(
              icon: Icons.sms_outlined,
              title: 'Code SMS (OTP)',
              desc: 'Envoyé au ${user.phone} à chaque connexion',
              trailing: const MoncarBadge(
                label: 'Actif',
                tone: MoncarBadgeTone.success,
                size: MoncarBadgeSize.sm,
              ),
              last: true,
            ),
          ),
          const SizedBox(height: 20),

          const _SectionTitle("Verrouillage de l'application"),
          MoncarCard(
            padding: const EdgeInsets.all(6),
            child: Column(
              children: [
                _Row(
                  icon: Icons.pin_outlined,
                  title: 'Code PIN',
                  desc: security.hasPin
                      ? 'Demandé au retour dans l’app après 30 s'
                      : 'Protégez l’accès à vos billets',
                  trailing: security.hasPin
                      ? null
                      : MoncarButton(
                          label: 'Créer',
                          variant: MoncarButtonVariant.soft,
                          size: MoncarButtonSize.sm,
                          onPressed: () => _createPin(context, ref),
                        ),
                  last: !security.hasPin,
                ),
                if (security.hasPin) ...[
                  _Row(
                    icon: Icons.edit_outlined,
                    title: 'Modifier le code PIN',
                    onTap: () => _changePin(context, ref),
                  ),
                  _Row(
                    icon: Icons.fingerprint,
                    title: 'Déverrouillage biométrique',
                    desc: 'Empreinte ou reconnaissance faciale',
                    trailing: Switch(
                      value: security.biometric,
                      activeTrackColor: MoncarColors.accent,
                      onChanged: (v) => _toggleBiometric(context, ref, v),
                    ),
                  ),
                  _Row(
                    icon: Icons.lock_open_outlined,
                    title: 'Désactiver le code PIN',
                    danger: true,
                    onTap: () => _removePin(context, ref),
                    last: true,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          const _SectionTitle('Paiements'),
          MoncarCard(
            padding: const EdgeInsets.all(6),
            child: _Row(
              icon: Icons.verified_user_outlined,
              title: 'Confirmer les paiements par OTP',
              desc: 'Un code SMS est demandé avant chaque paiement',
              trailing: Switch(
                value: security.otpPayments,
                activeTrackColor: MoncarColors.accent,
                onChanged: (v) => ref
                    .read(securitySettingsProvider.notifier)
                    .setOtpPayments(v),
              ),
              last: true,
            ),
          ),
          const SizedBox(height: 20),

          _SectionTitle('Appareils connectés (${user.devices.length})'),
          MoncarCard(
            padding: const EdgeInsets.all(6),
            child: Column(
              children: [
                for (var i = 0; i < user.devices.length; i++)
                  _DeviceRow(
                    device: user.devices[i],
                    last: i == user.devices.length - 1,
                    onRevoke: () =>
                        _revokeDevice(context, ref, user.devices[i]),
                  ),
              ],
            ),
          ),
          if (others > 0) ...[
            const SizedBox(height: 12),
            MoncarButton(
              label: 'Déconnecter les autres appareils',
              icon: Icons.logout,
              variant: MoncarButtonVariant.outline,
              size: MoncarButtonSize.md,
              expand: true,
              onPressed: () => _revokeOthers(context, ref),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 4),
              Icon(Icons.info_outline, size: 12, color: MoncarColors.inkFaint),
              SizedBox(width: 4),
              Expanded(
                child: Text(
                  'MON CAR ne vous demandera jamais votre code SMS ou votre '
                  'code PIN par téléphone, SMS ou WhatsApp.',
                  style: TextStyle(fontSize: 11, color: MoncarColors.inkFaint),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.hasPin});

  final bool hasPin;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: hasPin
          ? brandGradientDecoration(radius: BorderRadius.circular(20))
          : BoxDecoration(
              color: MoncarColors.warnSoft,
              borderRadius: BorderRadius.circular(20),
            ),
      child: Row(
        children: [
          Icon(
            hasPin ? Icons.verified_user : Icons.shield_outlined,
            size: 36,
            color: hasPin ? Colors.white : MoncarColors.warn,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasPin ? 'Compte bien protégé' : 'Renforcez votre sécurité',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: hasPin ? Colors.white : MoncarColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hasPin
                      ? 'Code SMS à la connexion et code PIN à l’ouverture.'
                      : 'Ajoutez un code PIN pour protéger vos billets si '
                            'votre téléphone est perdu.',
                  style: TextStyle(
                    fontSize: 12,
                    color: hasPin
                        ? Colors.white.withValues(alpha: 0.85)
                        : MoncarColors.inkMut,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: OverlineText(title, color: MoncarColors.inkFaint),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    this.desc,
    this.trailing,
    this.onTap,
    this.danger = false,
    this.last = false,
  });

  final IconData icon;
  final String title;
  final String? desc;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool danger;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final color = danger ? MoncarColors.danger : MoncarColors.brand;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: last
              ? null
              : Border(
                  bottom: BorderSide(
                    color: MoncarColors.hairline.withValues(alpha: 0.7),
                  ),
                ),
        ),
        child: Row(
          children: [
            IconTile(
              icon: icon,
              color: color,
              background: danger
                  ? MoncarColors.dangerSoft
                  : MoncarColors.brandSoft,
              size: 36,
              radius: 18,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: danger ? MoncarColors.danger : MoncarColors.ink,
                    ),
                  ),
                  if (desc != null)
                    Text(
                      desc!,
                      style: TextStyle(
                        fontSize: 11,
                        color: MoncarColors.inkMut,
                      ),
                    ),
                ],
              ),
            ),
            if (trailing != null)
              trailing!
            else if (onTap != null)
              Icon(Icons.chevron_right, size: 16, color: MoncarColors.inkFaint),
          ],
        ),
      ),
    );
  }
}

class _DeviceRow extends StatelessWidget {
  const _DeviceRow({
    required this.device,
    required this.last,
    required this.onRevoke,
  });

  final UserDevice device;
  final bool last;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) {
    final isApple = device.label.toLowerCase().contains('iphone');
    return _Row(
      icon: isApple ? Icons.phone_iphone : Icons.phone_android,
      title: device.label,
      desc: device.current
          ? 'Cet appareil · actif maintenant'
          : 'Dernière activité ${timeAgo(device.lastActive)}',
      trailing: device.current
          ? const MoncarBadge(
              label: 'Actuel',
              tone: MoncarBadgeTone.brand,
              size: MoncarBadgeSize.sm,
            )
          : TextButton(
              onPressed: onRevoke,
              style: TextButton.styleFrom(foregroundColor: MoncarColors.danger),
              child: const Text('Déconnecter'),
            ),
      last: last,
    );
  }
}

/// Feuille de saisie d'un code PIN à 4 chiffres avec pavé numérique.
/// Renvoie le code saisi quand [validate] ne renvoie pas d'erreur.
class _PinSheet extends StatefulWidget {
  const _PinSheet({
    required this.title,
    required this.subtitle,
    required this.validate,
  });

  final String title;
  final String subtitle;
  final String? Function(String code) validate;

  static Future<String?> show(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String? Function(String code) validate,
  }) => showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: MoncarColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) =>
        _PinSheet(title: title, subtitle: subtitle, validate: validate),
  );

  @override
  State<_PinSheet> createState() => _PinSheetState();
}

class _PinSheetState extends State<_PinSheet> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: MoncarColors.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: MoncarColors.inkMut),
          ),
          const SizedBox(height: 24),
          PinPad(
            onCompleted: (code) async {
              final error = widget.validate(code);
              if (error != null) return error;
              await Future<void>.delayed(const Duration(milliseconds: 120));
              if (context.mounted) Navigator.of(context).pop(code);
              return null;
            },
          ),
        ],
      ),
    );
  }
}
