import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/application/app_providers.dart';
import '../../../core/application/sync_controller.dart';
import '../../../core/domain/models.dart';
import '../../../core/ui/format.dart';
import '../../../core/ui/pro_kit.dart';

/// File d'actions terrain et synchronisation (zéro doublon grâce à
/// l'Idempotency-Key, heure terrain conservée).
class SyncPage extends ConsumerWidget {
  const SyncPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sync = ref.watch(syncProvider);
    final net = ref.watch(networkProvider);
    final (color, icon, title, sub) = !net.online
        ? (
            MoncarColors.warn,
            Icons.cloud_off_rounded,
            'Hors ligne',
            net.forcedOffline
                ? 'Mode hors ligne activé (essai terrain).'
                : 'Pas de réseau : les actions sont conservées sur le téléphone.',
          )
        : sync.flushing
        ? (
            MoncarColors.info,
            Icons.sync_rounded,
            'Synchronisation…',
            'Envoi des actions en attente.',
          )
        : sync.pendingCount > 0
        ? (
            MoncarColors.warn,
            Icons.cloud_upload_rounded,
            '${sync.pendingCount} action(s) en attente',
            'Nouvel essai automatique.',
          )
        : (
            MoncarColors.success,
            Icons.cloud_done_rounded,
            'Tout est synchronisé',
            sync.lastSyncAt == null
                ? 'Aucune action à envoyer.'
                : 'Dernière synchro ${fmtAgo(sync.lastSyncAt!)}.',
          );

    return ProPage(
      title: 'Synchronisation',
      subtitle: 'Actions terrain',
      bottom: BigActionButton(
        label: 'Synchroniser maintenant',
        icon: Icons.sync_rounded,
        color: MoncarColors.brand,
        loading: sync.flushing,
        onPressed: net.online && sync.pendingCount > 0
            ? () => ref.read(syncProvider.notifier).flush()
            : null,
      ),
      children: [
        MoncarCard(
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, color: color, size: 30),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: MoncarColors.ink,
                      ),
                    ),
                    Text(
                      sub,
                      style: TextStyle(
                        fontSize: 13,
                        color: MoncarColors.inkMut,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: MiniStat(
                value: '${sync.pendingCount - sync.errorCount}',
                label: 'En attente',
                color: MoncarColors.warn,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: MiniStat(
                value: '${sync.errorCount}',
                label: 'À réessayer',
                color: MoncarColors.danger,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: MiniStat(
                value: '${sync.doneCount}',
                label: 'Envoyées',
                color: MoncarColors.success,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        MoncarCard(
          padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
          child: Material(
            type: MaterialType.transparency,
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: net.forcedOffline,
              onChanged: (v) =>
                  ref.read(networkProvider.notifier).setForcedOffline(v),
              title: const Text(
                'Mode hors ligne',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                net.deviceOnline
                    ? 'Réseau du téléphone : disponible'
                    : 'Réseau du téléphone : absent',
              ),
            ),
          ),
        ),
        SectionTitle(
          'Journal des actions',
          trailing: sync.doneCount > 0
              ? TextButton(
                  onPressed: () => ref.read(syncProvider.notifier).clearDone(),
                  child: const Text('Purger les envoyées'),
                )
              : null,
        ),
        if (sync.ops.isEmpty)
          const EmptyCard(
            message: 'Aucune action enregistrée pour le moment.',
            icon: Icons.inbox_rounded,
          )
        else
          for (final op in sync.ops.take(60))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _OpTile(op: op),
            ),
      ],
    );
  }
}

class _OpTile extends StatelessWidget {
  const _OpTile({required this.op});

  final SyncOp op;

  @override
  Widget build(BuildContext context) {
    final (c, i, label) = switch (op.status) {
      SyncOpStatus.pending => (
        MoncarColors.warn,
        Icons.schedule_rounded,
        'En attente',
      ),
      SyncOpStatus.syncing => (MoncarColors.info, Icons.sync_rounded, 'Envoi…'),
      SyncOpStatus.done => (
        MoncarColors.success,
        Icons.check_circle_rounded,
        'Envoyée',
      ),
      SyncOpStatus.error => (
        MoncarColors.danger,
        Icons.error_rounded,
        'À réessayer',
      ),
    };
    return MoncarCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(i, color: c, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  op.summary,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: MoncarColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${op.kind} · heure terrain ${fmtTime(op.createdAt)} · clé ${op.idempotencyKey.length > 8 ? op.idempotencyKey.substring(0, 8) : op.idempotencyKey}',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: MoncarColors.inkFaint,
                  ),
                ),
                if (op.lastError != null)
                  Text(
                    op.lastError!,
                    style: TextStyle(fontSize: 12, color: MoncarColors.danger),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: c,
            ),
          ),
        ],
      ),
    );
  }
}
