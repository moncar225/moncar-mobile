import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/foundation.dart';

IconData _categoryIcon(NotificationCategory c) => switch (c) {
  NotificationCategory.voyager => Icons.directions_bus_outlined,
  NotificationCategory.colis => Icons.inventory_2_outlined,
  NotificationCategory.location => Icons.directions_car_outlined,
  NotificationCategory.paiement => Icons.account_balance_wallet_outlined,
  NotificationCategory.securite => Icons.verified_user_outlined,
  NotificationCategory.promotion => Icons.card_giftcard,
  NotificationCategory.systeme => Icons.settings_outlined,
};

/// Centre de notifications : filtres par catégorie, « Tout marquer
/// lu », ouverture de la cible liée (billet, colis, suivi, promo).
class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  NotificationCategory? _filter;

  void _open(AppNotification n) {
    final store = ref.read(mockStoreProvider);
    if (!n.read) store.markNotificationRead(n.id);
    final lt = n.linkTarget;
    if (lt == null) return;
    final route = switch (lt.type) {
      'billet' => '/voyager/ticket/${lt.id}',
      'colis' => '/colis/${lt.id}',
      'voyage' => '/tracking/${lt.id}',
      'promo' => '/promotions/${lt.id}',
      _ => null,
    };
    if (route != null) context.push(route);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(mockStoreChangesProvider);
    final store = ref.read(mockStoreProvider);
    final all = store.notifications;
    final filtered = _filter == null
        ? all
        : all.where((n) => n.category == _filter).toList();
    final unread = all.where((n) => !n.read).length;
    final filterLabel = _filter == null
        ? ''
        : NOTIF_CATEGORIES.firstWhere((c) => c.category == _filter).label;

    return Scaffold(
      backgroundColor: MoncarColors.background,
      appBar: const TopBar(
        title: 'Notifications',
        showBack: true,
        showBell: false,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                Text(
                  '$unread non ${unread > 1 ? 'lues' : 'lue'}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: MoncarColors.inkMut,
                  ),
                ),
                if (unread > 0)
                  TextButton.icon(
                    onPressed: () {
                      store.markAllNotificationsRead();
                      showMoncarToast(
                        context,
                        'Toutes les notifications ont été marquées comme lues.',
                        success: true,
                      );
                    },
                    icon: const Icon(Icons.done_all, size: 14),
                    label: const Text('Tout marquer lu'),
                    style: TextButton.styleFrom(
                      foregroundColor: MoncarColors.accent,
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              children: [
                MoncarChip(
                  label: 'Tous',
                  active: _filter == null,
                  onTap: () => setState(() => _filter = null),
                ),
                for (final c in NOTIF_CATEGORIES) ...[
                  const SizedBox(width: 8),
                  MoncarChip(
                    label: c.label,
                    active: _filter == c.category,
                    onTap: () => setState(() => _filter = c.category),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? MoncarEmptyState(
                    icon: Icons.notifications_none,
                    title: 'Aucune notification',
                    message: _filter == null
                        ? 'Vous serez informé(e) ici de vos prochains trajets, colis et paiements.'
                        : 'Aucune notification dans la catégorie $filterLabel.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _NotificationCard(
                      n: filtered[i],
                      onTap: () => _open(filtered[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.n, required this.onTap});

  final AppNotification n;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = hexColor(n.iconColor);
    final locked =
        n.category == NotificationCategory.securite ||
        n.category == NotificationCategory.paiement;
    // Bordure uniforme arrondie + barre d'accent gauche découpée (Flutter
    // ne peint pas de coins arrondis sur des bordures de couleurs mixtes).
    return Material(
      color: MoncarColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: MoncarColors.hairline.withValues(alpha: 0.7)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 4,
                color: n.read ? MoncarColors.hairline : MoncarColors.accent,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconTile(
                        icon: _categoryIcon(n.category),
                        color: color,
                        background: color.withValues(alpha: 0.13),
                        size: 40,
                        radius: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    n.title,
                                    style: TextStyle(
                                      fontSize: 14,
                                      height: 1.3,
                                      fontWeight: n.read
                                          ? FontWeight.w600
                                          : FontWeight.w700,
                                      color: MoncarColors.ink,
                                    ),
                                  ),
                                ),
                                if (!n.read)
                                  Semantics(
                                    label: 'Non lu',
                                    child: Container(
                                      margin: const EdgeInsets.only(
                                        top: 4,
                                        left: 6,
                                      ),
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: MoncarColors.accent,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              n.body,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.5,
                                height: 1.35,
                                color: MoncarColors.inkMut,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Text(
                                  timeAgo(n.createdAt),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: MoncarColors.inkFaint,
                                  ),
                                ),
                                if (locked) ...[
                                  const SizedBox(width: 8),
                                  MoncarBadge(
                                    label: 'Non muable',
                                    tone: MoncarBadgeTone.neutral,
                                    size: MoncarBadgeSize.sm,
                                    icon: Icons.lock_outline,
                                    backgroundColor: MoncarColors.muted,
                                    textColor: MoncarColors.inkMut,
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
