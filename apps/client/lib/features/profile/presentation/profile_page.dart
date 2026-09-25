import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../shared/foundation.dart';

({String label, MoncarBadgeTone tone}) _tierMeta(LoyaltyTier t) => switch (t) {
  LoyaltyTier.standard => (
    label: 'Membre Standard',
    tone: MoncarBadgeTone.neutral,
  ),
  LoyaltyTier.argent => (label: 'Membre Argent', tone: MoncarBadgeTone.brand),
  LoyaltyTier.or => (label: 'Membre Or', tone: MoncarBadgeTone.warn),
  LoyaltyTier.vip => (label: 'Membre VIP', tone: MoncarBadgeTone.accent),
};

typedef _MenuItem = ({
  IconData icon,
  String label,
  String? desc,
  VoidCallback onTap,
});

/// Onglet Profil : carte d'identité, statistiques, menus groupés
/// (compte, activité, avantages, aide, réglages) et déconnexion.
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Se déconnecter ?'),
        content: const Text(
          'Vous devrez de nouveau saisir votre numéro de téléphone et votre OTP pour accéder à votre compte MON CAR.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: MoncarColors.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Se déconnecter'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    signOut(ref);
    showMoncarToast(context, 'Vous êtes déconnecté.', success: true);
  }

  Future<void> _callEmergency(BuildContext context) async {
    final uri = Uri(scheme: 'tel', path: '+225272030040');
    final launched = await launchUrl(uri);
    if (!launched && context.mounted) {
      showMoncarToast(
        context,
        'Appel impossible depuis cet appareil : +225 27 20 30 00 40',
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(mockStoreChangesProvider);
    final user = ref.watch(authProvider).user;
    final store = ref.read(mockStoreProvider);
    final photo = ref.watch(profilePhotoProvider);

    if (user == null) {
      return ColoredBox(
        color: MoncarColors.background,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const BrandTabHeader(bottomPadding: 20, child: SizedBox.shrink()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
              child: Column(
                children: [
                  Text(
                    'Session expirée.',
                    style: TextStyle(fontSize: 14, color: MoncarColors.inkMut),
                  ),
                  const SizedBox(height: 16),
                  MoncarButton(
                    label: "Retour à l'accueil",
                    variant: MoncarButtonVariant.primary,
                    size: MoncarButtonSize.lg,
                    onPressed: () => context.go('/home'),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final tier = _tierMeta(user.loyaltyTier);
    final devices = user.devices.length;

    final groups = <({String title, List<_MenuItem> items})>[
      (
        title: 'Compte',
        items: [
          (
            icon: Icons.person_outline,
            label: 'Informations personnelles',
            desc: 'Nom, téléphone, email',
            onTap: () => context.push('/profile/info'),
          ),
          (
            icon: Icons.shield_outlined,
            label: 'Sécurité',
            desc: 'Code PIN, biométrie, paiements',
            onTap: () => context.push('/profile/security'),
          ),
          (
            icon: Icons.smartphone,
            label: 'Appareils connectés',
            desc: '$devices actif${devices > 1 ? 's' : ''}',
            onTap: () => context.push('/profile/security'),
          ),
          (
            icon: Icons.tune,
            label: 'Préférences',
            desc: 'Langue, thème, notifications',
            onTap: () => context.push('/settings'),
          ),
        ],
      ),
      (
        title: 'Activité',
        items: [
          (
            icon: Icons.confirmation_number_outlined,
            label: 'Mes billets',
            desc: null,
            onTap: () => context.push('/history?tab=tickets'),
          ),
          (
            icon: Icons.inventory_2_outlined,
            label: 'Mes colis',
            desc: null,
            onTap: () => context.push('/history?tab=parcels'),
          ),
          (
            icon: Icons.bolt,
            label: 'Mes locations',
            desc: null,
            onTap: () => context.push('/location/mine'),
          ),
          (
            icon: Icons.history,
            label: 'Historique',
            desc: null,
            onTap: () => context.push('/history'),
          ),
          (
            icon: Icons.account_balance_wallet_outlined,
            label: 'Paiements',
            desc: null,
            onTap: () => context.push('/history?tab=payments'),
          ),
        ],
      ),
      (
        title: 'Avantages',
        items: [
          (
            icon: Icons.card_giftcard,
            label: 'Promotions',
            desc: null,
            onTap: () => context.push('/promotions'),
          ),
          (
            icon: Icons.emoji_events_outlined,
            label: 'Fidélité',
            desc: null,
            onTap: () => context.push('/loyalty'),
          ),
        ],
      ),
      (
        title: 'Aide',
        items: [
          (
            icon: Icons.headset_mic_outlined,
            label: 'Aide & support',
            desc: null,
            onTap: () => context.push('/help'),
          ),
          (
            icon: Icons.phone_outlined,
            label: "Contact d'urgence",
            desc: null,
            onTap: () => _callEmergency(context),
          ),
        ],
      ),
      (
        title: 'Réglages',
        items: [
          (
            icon: Icons.settings_outlined,
            label: 'Paramètres',
            desc: null,
            onTap: () => context.push('/settings'),
          ),
        ],
      ),
    ];

    return ColoredBox(
      color: MoncarColors.background,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const BrandTabHeader(bottomPadding: 12, child: SizedBox.shrink()),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MoncarCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          MoncarAvatar(
                            initials: user.initials,
                            size: 64,
                            image: photo == null ? null : MemoryImage(photo),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${user.firstName} ${user.lastName}',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: MoncarColors.ink,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                _InfoLine(
                                  icon: Icons.phone_outlined,
                                  text: user.phone,
                                ),
                                if (user.email.isNotEmpty)
                                  _InfoLine(
                                    icon: Icons.mail_outline,
                                    text: user.email,
                                  ),
                                _InfoLine(
                                  icon: Icons.place_outlined,
                                  text: '${user.city}, CI',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          MoncarBadge(
                            label: tier.label,
                            tone: tier.tone,
                            icon: Icons.emoji_events_outlined,
                          ),
                          const Spacer(),
                          Flexible(
                            child: Text(
                              'Membre depuis ${formatDateLong(user.cguAcceptedAt)}',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 11,
                                color: MoncarColors.inkFaint,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _StatCard(
                      label: 'Voyages',
                      value: '${store.bookings.length}',
                      icon: Icons.history,
                    ),
                    const SizedBox(width: 10),
                    _StatCard(
                      label: 'Points fidélité',
                      value: formatNumber(user.loyaltyPoints),
                      icon: Icons.emoji_events_outlined,
                    ),
                    const SizedBox(width: 10),
                    _StatCard(
                      label: 'Niveau',
                      value: user.loyaltyTier.label.toUpperCase(),
                      icon: Icons.card_giftcard,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                for (final g in groups) ...[
                  _GroupTitle(g.title),
                  MoncarCard(
                    padding: const EdgeInsets.all(6),
                    child: Column(
                      children: [
                        for (var i = 0; i < g.items.length; i++)
                          _MenuRow(
                            item: g.items[i],
                            last: i == g.items.length - 1,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                const _GroupTitle('Déconnexion'),
                MoncarCard(
                  padding: const EdgeInsets.all(6),
                  child: InkWell(
                    onTap: () => _confirmLogout(context, ref),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Row(
                        children: [
                          IconTile(
                            icon: Icons.logout,
                            color: MoncarColors.danger,
                            background: MoncarColors.dangerSoft,
                            size: 36,
                            radius: 18,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Déconnexion',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: MoncarColors.danger,
                                  ),
                                ),
                                Text(
                                  'Quitter votre session MON CAR',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: MoncarColors.inkMut,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            size: 16,
                            color: MoncarColors.inkFaint,
                          ),
                        ],
                      ),
                    ),
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

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Icon(icon, size: 12, color: MoncarColors.brand),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: MoncarColors.inkMut),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: MoncarCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            IconTile(
              icon: icon,
              background: MoncarColors.brandSoft,
              size: 32,
              radius: 16,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: MoncarColors.brand,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                height: 1.2,
                color: MoncarColors.inkMut,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupTitle extends StatelessWidget {
  const _GroupTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: OverlineText(title, color: MoncarColors.inkFaint),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.item, required this.last});

  final _MenuItem item;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: item.onTap,
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
              icon: item.icon,
              background: MoncarColors.brandSoft,
              size: 36,
              radius: 18,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: MoncarColors.ink,
                    ),
                  ),
                  if (item.desc != null)
                    Text(
                      item.desc!,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: MoncarColors.inkMut,
                      ),
                    ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 16, color: MoncarColors.inkFaint),
          ],
        ),
      ),
    );
  }
}
