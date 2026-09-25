import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/application/app_providers.dart';
import '../../../core/application/session_controller.dart';
import '../../../core/application/sync_controller.dart';
import '../../../core/application/trip_controller.dart';
import '../../../core/domain/models.dart';
import '../../../core/ui/format.dart';
import '../../../core/ui/pro_kit.dart';
import '../../../core/ui/role_style.dart';
import '../../../core/ui/status_widgets.dart';

/// Catégories proposées selon le poste (CDC : panne, route bloquée,
/// retard pour le chauffeur ; billet/passager pour le contrôle…).
List<IncidentCategory> categoriesFor(ProRole role) => switch (role) {
  ProRole.chauffeur => const [
    IncidentCategory.panne,
    IncidentCategory.accident,
    IncidentCategory.retard,
    IncidentCategory.routeBloquee,
    IncidentCategory.securite,
    IncidentCategory.autre,
  ],
  ProRole.controleur => const [
    IncidentCategory.billet,
    IncidentCategory.passager,
    IncidentCategory.bagage,
    IncidentCategory.colis,
    IncidentCategory.securite,
    IncidentCategory.autre,
  ],
  ProRole.convoyeur => const [
    IncidentCategory.passager,
    IncidentCategory.bagage,
    IncidentCategory.colis,
    IncidentCategory.retard,
    IncidentCategory.securite,
    IncidentCategory.autre,
  ],
  ProRole.agentBusiness => const [
    IncidentCategory.accident,
    IncidentCategory.panne,
    IncidentCategory.retard,
    IncidentCategory.securite,
    IncidentCategory.autre,
  ],
};

/// Incidents du voyage + signalement (avec photo et position).
class IncidentsPage extends ConsumerStatefulWidget {
  const IncidentsPage({super.key, this.openReport = false});

  final bool openReport;

  @override
  ConsumerState<IncidentsPage> createState() => _IncidentsPageState();
}

class _IncidentsPageState extends ConsumerState<IncidentsPage> {
  @override
  void initState() {
    super.initState();
    if (widget.openReport) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _report());
    }
  }

  Future<void> _report() async {
    final role = ref.read(activeRoleProvider) ?? ProRole.convoyeur;
    final created = await showModalBottomSheet<Incident>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ReportSheet(role: role),
    );
    if (created == null || !mounted) return;
    final online = ref.read(networkProvider).online;
    showProToast(
      context,
      online
          ? 'Incident transmis — chef de gare et équipe notifiés.'
          : 'Incident enregistré hors ligne — envoi au retour du réseau.',
      tone: online ? ToastTone.success : ToastTone.warning,
    );
  }

  @override
  Widget build(BuildContext context) {
    final incidents = ref.watch(tripProvider).incidents;
    final sync = ref.watch(syncProvider);
    final role = ref.watch(activeRoleProvider) ?? ProRole.convoyeur;
    return ProPage(
      title: 'Incidents',
      subtitle: '${incidents.length} sur ce voyage',
      bottom: BigActionButton(
        label: 'Signaler un incident',
        icon: Icons.add_alert_rounded,
        color: MoncarColors.danger,
        onPressed: _report,
      ),
      children: [
        if (incidents.isEmpty)
          const EmptyCard(
            message: 'Aucun incident signalé.',
            icon: Icons.verified_user_rounded,
          )
        else
          for (final i in incidents)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: MoncarCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: i.severity.color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(i.category.icon, color: i.severity.color),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                i.category.label,
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: MoncarColors.ink,
                                ),
                              ),
                              Text(
                                '${fmtShortDateTime(i.createdAt)} · ${i.author}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: MoncarColors.inkMut,
                                ),
                              ),
                            ],
                          ),
                        ),
                        MoncarBadge(
                          label: i.status.label,
                          size: MoncarBadgeSize.sm,
                          tone: switch (i.status) {
                            IncidentStatus.ouvert => MoncarBadgeTone.danger,
                            IncidentStatus.enCours => MoncarBadgeTone.warn,
                            IncidentStatus.resolu => MoncarBadgeTone.success,
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      i.description,
                      style: TextStyle(color: MoncarColors.ink, height: 1.35),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        MoncarBadge(
                          label: 'Gravité ${i.severity.label.toLowerCase()}',
                          size: MoncarBadgeSize.sm,
                          backgroundColor: i.severity.color.withValues(
                            alpha: 0.12,
                          ),
                          textColor: i.severity.color,
                        ),
                        if (i.locationLabel != null)
                          MoncarBadge(
                            label: i.locationLabel!,
                            icon: Icons.place_rounded,
                            size: MoncarBadgeSize.sm,
                            tone: MoncarBadgeTone.neutral,
                          ),
                        if (i.withPhoto)
                          const MoncarBadge(
                            label: 'Photo jointe',
                            icon: Icons.photo_camera_rounded,
                            size: MoncarBadgeSize.sm,
                            tone: MoncarBadgeTone.neutral,
                          ),
                        MoncarBadge(
                          label: i.synced || sync.isDone('incident-${i.id}')
                              ? 'Synchronisé'
                              : 'En attente d’envoi',
                          icon: i.synced || sync.isDone('incident-${i.id}')
                              ? Icons.cloud_done_rounded
                              : Icons.cloud_upload_rounded,
                          size: MoncarBadgeSize.sm,
                          tone: i.synced || sync.isDone('incident-${i.id}')
                              ? MoncarBadgeTone.success
                              : MoncarBadgeTone.warn,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        const SizedBox(height: 4),
        Center(
          child: Text(
            'Profil ${role.label} · chaque signalement est horodaté et attribué.',
            style: TextStyle(fontSize: 12, color: MoncarColors.inkFaint),
          ),
        ),
      ],
    );
  }
}

class _ReportSheet extends ConsumerStatefulWidget {
  const _ReportSheet({required this.role});

  final ProRole role;

  @override
  ConsumerState<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends ConsumerState<_ReportSheet> {
  IncidentCategory? _cat;
  IncidentSeverity _sev = IncidentSeverity.moyenne;
  final _desc = TextEditingController();
  bool _photo = false;

  @override
  void dispose() {
    _desc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cats = categoriesFor(widget.role);
    final trip = ref.watch(tripProvider);
    final accent = widget.role.accent;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: MoncarColors.hairline,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Signaler un incident',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: MoncarColors.ink,
              ),
            ),
            const SizedBox(height: 14),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.15,
              children: [
                for (final c in cats)
                  Material(
                    color: _cat == c ? accent : MoncarColors.muted,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        haptic(HapticKind.tap);
                        setState(() => _cat = c);
                      },
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            c.icon,
                            color: _cat == c ? Colors.white : MoncarColors.ink,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            c.label,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 12.5,
                              color: _cat == c
                                  ? Colors.white
                                  : MoncarColors.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Gravité',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: MoncarColors.ink,
              ),
            ),
            const SizedBox(height: 8),
            SegmentedButton<IncidentSeverity>(
              segments: [
                for (final s in IncidentSeverity.values)
                  ButtonSegment(value: s, label: Text(s.label)),
              ],
              selected: {_sev},
              showSelectedIcon: false,
              onSelectionChanged: (v) => setState(() => _sev = v.first),
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith(
                  (st) => st.contains(WidgetState.selected) ? _sev.color : null,
                ),
                foregroundColor: WidgetStateProperty.resolveWith(
                  (st) => st.contains(WidgetState.selected)
                      ? Colors.white
                      : MoncarColors.ink,
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _desc,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Décrivez la situation…',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => setState(() => _photo = !_photo),
                    icon: Icon(
                      _photo
                          ? Icons.check_circle_rounded
                          : Icons.photo_camera_rounded,
                    ),
                    label: Text(_photo ? 'Photo jointe' : 'Ajouter une photo'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            InfoBanner(
              icon: Icons.my_location_rounded,
              message:
                  'Position jointe automatiquement : ${trip.voyage.currentStop.shortName} '
                  '(${trip.voyage.number}). Envoi immédiat ou différé si hors ligne.',
            ),
            const SizedBox(height: 16),
            BigActionButton(
              label: 'Envoyer le signalement',
              icon: Icons.send_rounded,
              color: MoncarColors.danger,
              onPressed: _cat == null
                  ? null
                  : () {
                      final inc = ref
                          .read(tripProvider.notifier)
                          .reportIncident(
                            category: _cat!,
                            severity: _sev,
                            description: _desc.text.trim().isEmpty
                                ? _cat!.label
                                : _desc.text.trim(),
                            withPhoto: _photo,
                          );
                      haptic(HapticKind.success);
                      Navigator.of(context).pop(inc);
                    },
            ),
          ],
        ),
      ),
    );
  }
}
