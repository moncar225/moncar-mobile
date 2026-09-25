import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/application/notifications_controller.dart';
import '../../../core/domain/models.dart';
import '../../../core/ui/format.dart';
import '../../../core/ui/pro_kit.dart';
import '../../../core/ui/status_widgets.dart';

/// Alertes et notifications (catégorie + priorité, lu/non lu persistant).
class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  NotifCategory? _f;

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(notificationsProvider);
    final unread = all.where((n) => !n.read).length;
    final list = all.where((n) => _f == null || n.category == _f).toList();
    return ProPage(
      title: 'Alertes',
      subtitle: unread == 0
          ? 'Tout est lu'
          : '$unread non lue${unread > 1 ? 's' : ''}',
      actions: [
        if (unread > 0)
          TextButton(
            onPressed: () =>
                ref.read(notificationsProvider.notifier).markAllRead(),
            child: const Text('Tout lire'),
          ),
      ],
      children: [
        FilterBar<NotifCategory?>(
          accent: MoncarColors.brand,
          selected: _f,
          onSelected: (v) => setState(() => _f = v),
          options: [
            FilterOption(null, 'Toutes', count: all.length),
            for (final c in NotifCategory.values)
              if (all.any((n) => n.category == c))
                FilterOption(
                  c,
                  c.label,
                  count: all.where((n) => n.category == c).length,
                ),
          ],
        ),
        const SizedBox(height: 14),
        if (list.isEmpty)
          const EmptyCard(
            message: 'Aucune alerte.',
            icon: Icons.notifications_off_rounded,
          )
        else
          for (final n in list)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: MoncarCard(
                padding: const EdgeInsets.all(12),
                color: n.read
                    ? null
                    : n.category.color.withValues(
                        alpha: MoncarColors.isDark ? 0.10 : 0.04,
                      ),
                onTap: () {
                  ref.read(notificationsProvider.notifier).markRead(n.id);
                  final r = n.route;
                  if (r != null) context.push(r);
                },
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: n.category.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        n.category.icon,
                        color: n.category.color,
                        size: 21,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  n.title,
                                  style: TextStyle(
                                    fontWeight: n.read
                                        ? FontWeight.w600
                                        : FontWeight.w900,
                                    color: MoncarColors.ink,
                                  ),
                                ),
                              ),
                              Text(
                                fmtAgo(n.at),
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: MoncarColors.inkFaint,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            n.body,
                            style: TextStyle(
                              fontSize: 13,
                              color: MoncarColors.inkMut,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!n.read) ...[
                      const SizedBox(width: 8),
                      Container(
                        width: 9,
                        height: 9,
                        margin: const EdgeInsets.only(top: 6),
                        decoration: BoxDecoration(
                          color: n.category.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
      ],
    );
  }
}
