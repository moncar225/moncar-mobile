// Badges de statut cohérents dans toute l'application (principe UX CDC).
library;

import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/app_providers.dart';
import '../application/sync_controller.dart';
import '../domain/models.dart';

extension ScanOutcomeStyle on ScanOutcome {
  Color get color => switch (this) {
    ScanOutcome.valide => MoncarColors.success,
    ScanOutcome.dejaScanne => MoncarColors.warn,
    ScanOutcome.annule => const Color(0xFF64748B),
    ScanOutcome.mauvaisVoyage ||
    ScanOutcome.mauvaiseGare ||
    ScanOutcome.invalide => MoncarColors.danger,
  };

  IconData get icon => switch (this) {
    ScanOutcome.valide => Icons.check_circle_rounded,
    ScanOutcome.dejaScanne => Icons.history_rounded,
    ScanOutcome.annule => Icons.block_rounded,
    ScanOutcome.mauvaisVoyage => Icons.alt_route_rounded,
    ScanOutcome.mauvaiseGare => Icons.wrong_location_rounded,
    ScanOutcome.invalide => Icons.gpp_bad_rounded,
  };
}

extension VoyageStatusStyle on VoyageStatus {
  MoncarBadgeTone get tone => switch (this) {
    VoyageStatus.programme => MoncarBadgeTone.neutral,
    VoyageStatus.embarquement => MoncarBadgeTone.warn,
    VoyageStatus.enCours => MoncarBadgeTone.success,
    VoyageStatus.arrive => MoncarBadgeTone.brand,
    VoyageStatus.cloture => MoncarBadgeTone.neutral,
    VoyageStatus.incident || VoyageStatus.annule => MoncarBadgeTone.danger,
  };
}

extension BagStatusStyle on BagStatus {
  MoncarBadgeTone get tone => switch (this) {
    BagStatus.enregistre => MoncarBadgeTone.neutral,
    BagStatus.aBord => MoncarBadgeTone.brand,
    BagStatus.aDecharger => MoncarBadgeTone.warn,
    BagStatus.remis => MoncarBadgeTone.success,
    BagStatus.incident => MoncarBadgeTone.danger,
  };
}

extension ParcelStatusStyle on ParcelStatus {
  MoncarBadgeTone get tone => switch (this) {
    ParcelStatus.charge || ParcelStatus.enTransit => MoncarBadgeTone.brand,
    ParcelStatus.aDecharger => MoncarBadgeTone.warn,
    ParcelStatus.decharge => MoncarBadgeTone.success,
    ParcelStatus.litige => MoncarBadgeTone.danger,
  };
}

extension NotifCategoryStyle on NotifCategory {
  Color get color => switch (this) {
    NotifCategory.critique => MoncarColors.danger,
    NotifCategory.alerte => MoncarColors.warn,
    NotifCategory.information => MoncarColors.info,
    NotifCategory.succes => MoncarColors.success,
  };

  IconData get icon => switch (this) {
    NotifCategory.critique => Icons.report_rounded,
    NotifCategory.alerte => Icons.warning_amber_rounded,
    NotifCategory.information => Icons.info_rounded,
    NotifCategory.succes => Icons.check_circle_rounded,
  };
}

extension IncidentSeverityStyle on IncidentSeverity {
  Color get color => switch (this) {
    IncidentSeverity.faible => MoncarColors.info,
    IncidentSeverity.moyenne => MoncarColors.warn,
    IncidentSeverity.critique => MoncarColors.danger,
  };
}

/// Pastille réseau + synchronisation (en-tête). Ouvre l'écran Synchro.
class SyncPill extends ConsumerWidget {
  const SyncPill({super.key, this.onDark = false});

  final bool onDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(networkProvider.select((n) => n.online));
    final sync = ref.watch(syncProvider);
    final pending = sync.pendingCount;

    final (icon, label, color) = !online
        ? (Icons.cloud_off_rounded, 'Hors ligne', MoncarColors.warn)
        : sync.flushing
        ? (Icons.sync_rounded, 'Synchro…', MoncarColors.info)
        : pending > 0
        ? (Icons.cloud_upload_rounded, '$pending en attente', MoncarColors.warn)
        : (Icons.cloud_done_rounded, 'À jour', MoncarColors.success);

    return Material(
      color: onDark
          ? Colors.white.withValues(alpha: 0.14)
          : color.withValues(alpha: MoncarColors.isDark ? 0.2 : 0.1),
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: () => context.push('/sync'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: onDark ? Colors.white : color),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: onDark ? Colors.white : color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
