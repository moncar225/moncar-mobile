import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/application/app_providers.dart';
import '../../../core/application/trip_controller.dart';
import '../../../core/domain/models.dart';
import '../../../core/ui/format.dart';
import '../../../core/ui/pro_kit.dart';
import '../../../core/ui/role_style.dart';

/// Chauffeur · Clôture du voyage (CHAUF-08) : kilométrage, incident
/// éventuel, confirmation définitive (glisser pour clôturer).
class CloseTripPage extends ConsumerStatefulWidget {
  const CloseTripPage({super.key});

  @override
  ConsumerState<CloseTripPage> createState() => _CloseTripPageState();
}

class _CloseTripPageState extends ConsumerState<CloseTripPage> {
  final _km = TextEditingController(text: '142 540');
  bool _incident = false;

  @override
  void dispose() {
    _km.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tripProvider);
    final v = t.voyage;
    final role = ProRole.chauffeur;
    final canClose = t.phase == DriverPhase.arriveDestination;
    final duration = v.departureActual == null
        ? null
        : DateTime.now().difference(v.departureActual!);

    return ProPage(
      title: 'Clôturer le voyage',
      subtitle: v.number,
      bottom: t.phase == DriverPhase.cloture
          ? BigActionButton(
              label: 'Retour à l’accueil',
              icon: Icons.home_rounded,
              color: MoncarColors.brand,
              onPressed: () => context.go('/home'),
            )
          : SwipeToConfirm(
              label: 'Glisser pour clôturer',
              color: MoncarColors.danger,
              icon: Icons.task_alt_rounded,
              enabled: canClose,
              onConfirmed: () async {
                final km =
                    int.tryParse(_km.text.replaceAll(RegExp(r'\D'), '')) ?? 0;
                ref
                    .read(tripProvider.notifier)
                    .closeTrip(km: km, withIncident: _incident);
                final online = ref.read(networkProvider).online;
                if (!context.mounted) return;
                showProToast(
                  context,
                  online
                      ? 'Voyage clôturé — rapport envoyé.'
                      : 'Clôture enregistrée hors ligne — envoi au retour du réseau.',
                  tone: online ? ToastTone.success : ToastTone.warning,
                );
                if (_incident) {
                  context.push('/incidents?nouveau=1');
                } else {
                  context.go('/home');
                }
              },
            ),
      children: [
        HeroCard(
          colors: role.gradient,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t.phase == DriverPhase.cloture ? 'VOYAGE CLÔTURÉ' : 'ARRIVÉE',
                style: const TextStyle(
                  fontSize: 12,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w800,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                v.line,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
              DetailRow(
                label: 'Heure d’arrivée',
                value: fmtTime(DateTime.now()),
                onDark: true,
              ),
              DetailRow(
                label: 'Départ réel',
                value: fmtTime(v.departureActual),
                onDark: true,
              ),
              if (duration != null)
                DetailRow(
                  label: 'Durée',
                  value:
                      '${duration.inHours} h ${two(duration.inMinutes % 60)}',
                  onDark: true,
                ),
              DetailRow(label: 'Véhicule', value: v.vehiclePlate, onDark: true),
            ],
          ),
        ),
        if (!canClose && t.phase != DriverPhase.cloture) ...[
          const SizedBox(height: 14),
          InfoBanner(
            icon: Icons.lock_clock_rounded,
            color: MoncarColors.warn,
            message:
                'La clôture est possible une fois l’arrivée à destination confirmée.',
          ),
        ],
        const SectionTitle('Compteur kilométrique'),
        TextField(
          controller: _km,
          enabled: canClose,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9 ]')),
          ],
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          decoration: const InputDecoration(
            suffixText: 'km',
            prefixIcon: Icon(Icons.speed_rounded),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Relevé tracé, contrôlé par le serveur.',
          style: TextStyle(fontSize: 12, color: MoncarColors.inkMut),
        ),
        const SectionTitle('Incident sur ce voyage'),
        MoncarCard(
          padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
          child: Material(
            type: MaterialType.transparency,
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _incident,
              onChanged: canClose ? (v) => setState(() => _incident = v) : null,
              title: const Text(
                'Un incident a eu lieu',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                _incident
                    ? 'Vous le détaillerez juste après la clôture.'
                    : 'Aucun incident à signaler.',
              ),
            ),
          ),
        ),
      ],
    );
  }
}
