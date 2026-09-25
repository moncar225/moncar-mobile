import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/application/app_providers.dart';
import '../../../core/application/trip_controller.dart';
import '../../../core/domain/models.dart';
import '../../../core/ui/format.dart';
import '../../../core/ui/pro_kit.dart';
import '../../../core/ui/role_style.dart';
import '../../../core/ui/status_widgets.dart';
import '../widgets/scan_result_view.dart';

/// Contrôleur · Saisie manuelle d'une référence (CTRL-02), tracée.
class ManualEntryPage extends ConsumerStatefulWidget {
  const ManualEntryPage({super.key});

  @override
  ConsumerState<ManualEntryPage> createState() => _ManualEntryPageState();
}

class _ManualEntryPageState extends ConsumerState<ManualEntryPage> {
  final _c = TextEditingController();
  ScanResult? _result;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _verify() {
    final code = _c.text.trim();
    if (code.isEmpty) {
      showProToast(
        context,
        'Saisissez une référence de billet.',
        tone: ToastTone.error,
      );
      return;
    }
    FocusScope.of(context).unfocus();
    setState(
      () =>
          _result = ref.read(tripProvider.notifier).verify(code, manual: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    if (r != null) {
      return Scaffold(
        body: ScanResultView(
          key: ValueKey(r.at),
          result: r,
          onNext: () => setState(() {
            _result = null;
            _c.clear();
          }),
        ),
      );
    }
    final accent = ProRole.controleur.accent;
    final online = ref.watch(networkProvider.select((n) => n.online));
    final manual = ref
        .watch(tripProvider)
        .scans
        .where((s) => s.manual)
        .take(8)
        .toList();
    return ProPage(
      title: 'Saisie manuelle',
      subtitle: 'Quand le QR est illisible',
      children: [
        const InfoBanner(
          icon: Icons.policy_rounded,
          message:
              'Chaque saisie manuelle est tracée (agent, heure terrain, appareil). '
              'Le serveur reste seul juge lors de la synchronisation.',
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _c,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          onSubmitted: (_) => _verify(),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          decoration: const InputDecoration(
            hintText: 'BIL-0427-014',
            prefixIcon: Icon(Icons.confirmation_number_rounded),
          ),
        ),
        const SizedBox(height: 14),
        BigActionButton(
          label: 'Vérifier le billet',
          icon: Icons.search_rounded,
          color: accent,
          onPressed: _verify,
        ),
        if (!online) ...[
          const SizedBox(height: 10),
          InfoBanner(
            icon: Icons.cloud_off_rounded,
            color: MoncarColors.warn,
            message:
                'Hors ligne : vérification sur le manifeste téléchargé, '
                'envoi au serveur au retour du réseau.',
          ),
        ],
        if (kDemoMode) ...[
          const SectionTitle('Références de test'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in const [
                'BIL-0427-014',
                'BIL-0427-002',
                'BIL-0427-018',
                'BIL-0430-118',
              ])
                ActionChip(label: Text(c), onPressed: () => _c.text = c),
            ],
          ),
        ],
        const SectionTitle('Saisies récentes'),
        if (manual.isEmpty)
          const EmptyCard(
            message: 'Aucune saisie manuelle sur ce voyage.',
            icon: Icons.keyboard_rounded,
          )
        else
          for (final s in manual)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: MoncarCard(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(s.outcome.icon, color: s.outcome.color),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        s.code,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: MoncarColors.ink,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    Text(
                      '${s.outcome.title} · ${fmtTime(s.at)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: s.outcome.color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}
