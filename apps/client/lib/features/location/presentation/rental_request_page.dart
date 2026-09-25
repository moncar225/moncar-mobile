import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/foundation.dart';
import '../widgets/location_widgets.dart';

/// DEMANDER UNE RÉSERVATION (§36) : récapitulatif de la demande, pièces
/// exigées pour une location sans chauffeur (§32), puis envoi au
/// fournisseur. Aucun paiement à cette étape.
class RentalRequestPage extends ConsumerStatefulWidget {
  const RentalRequestPage({
    super.key,
    required this.vehicleId,
    this.optionIds = const [],
  });

  final String vehicleId;
  final List<String> optionIds;

  @override
  ConsumerState<RentalRequestPage> createState() => _RentalRequestPageState();
}

class _RentalRequestPageState extends ConsumerState<RentalRequestPage> {
  final _license = TextEditingController();
  final _idDoc = TextEditingController();
  bool _submitted = false;
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _license.dispose();
    _idDoc.dispose();
    super.dispose();
  }

  Future<void> _send(RentalVehicle v, RentalCriteria criteria) async {
    setState(() {
      _submitted = true;
      _error = null;
    });
    if (!criteria.withDriver &&
        (_license.text.trim().isEmpty || _idDoc.text.trim().isEmpty)) {
      return;
    }
    setState(() => _sending = true);
    // ⚠️ MOCK : POST /rentals (latence simulée).
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    final r = ref
        .read(mockStoreProvider)
        .createRentalRequest(
          vehicleId: v.id,
          criteria: criteria,
          optionIds: widget.optionIds,
          licenseNumber: _license.text.trim(),
          idDocumentNumber: _idDoc.text.trim(),
        );
    setState(() => _sending = false);
    final rental = r.rental;
    if (!r.ok || rental == null) {
      setState(() => _error = r.error ?? 'Demande impossible.');
      return;
    }
    showMoncarToast(
      context,
      'Demande envoyée à ${rental.providerName}',
      success: true,
    );
    context.go('/location/rental/${rental.id}');
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.read(mockStoreProvider);
    final v = store.findRentalVehicle(widget.vehicleId);
    final user = ref.watch(authProvider).user;
    if (v == null) {
      return Scaffold(
        appBar: const TopBar(title: 'Demande de réservation', showBack: true),
        body: MoncarEmptyState(
          icon: Icons.directions_car_outlined,
          title: 'Véhicule introuvable',
          message: "Ce véhicule n'est plus proposé à la location.",
          actionLabel: 'Retour',
          onAction: () => context.mcBack(),
        ),
      );
    }
    final criteria = ref.watch(rentalSearchProvider).toCriteria();
    final quote = store.quoteRental(v, criteria, optionIds: widget.optionIds);
    final options = [
      for (final o in v.options)
        if (widget.optionIds.contains(o.id)) o.label,
    ];
    String? required(TextEditingController c) =>
        _submitted && c.text.trim().isEmpty ? 'Champ obligatoire.' : null;

    return Scaffold(
      backgroundColor: MoncarColors.background,
      appBar: const TopBar(
        title: 'Demande de réservation',
        showBack: true,
        showBell: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          MoncarCard(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                VehiclePhoto(vehicle: v, size: 64, iconSize: 28, radius: 12),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        v.summary,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: MoncarColors.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              v.partner,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: MoncarColors.inkMut,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          ProviderKindBadge(v.providerKind),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const MoncarSectionHeader(title: 'Votre demande'),
          MoncarCard(
            padding: const EdgeInsets.all(14),
            child: InfoGrid(
              items: [
                (
                  Icons.person_outline,
                  'Client',
                  user == null ? '—' : '${user.firstName} ${user.lastName}',
                ),
                (Icons.place_outlined, 'Prise en charge', criteria.pickupLabel),
                (
                  Icons.swap_horiz,
                  'Déplacement',
                  criteria.area == RentalArea.exterieur
                      ? 'Extérieur'
                      : 'Intérieur',
                ),
                (Icons.flag_outlined, 'Destination', criteria.destination),
                (
                  Icons.calendar_today_outlined,
                  'Heure prévue',
                  formatRentalIso(criteria.start),
                ),
                (
                  Icons.event_available_outlined,
                  'Fin prévue',
                  formatRentalIso(criteria.end),
                ),
                (Icons.schedule, 'Durée', quote.billableLabel),
                (Icons.group_outlined, 'Personnes', '${criteria.persons}'),
                (Icons.event_note_outlined, 'Motif', criteria.purpose.label),
                (
                  Icons.person_pin_outlined,
                  'Chauffeur',
                  criteria.withDriver ? 'Avec chauffeur' : 'Sans chauffeur',
                ),
                if (options.isNotEmpty)
                  (Icons.add_circle_outline, 'Options', options.join(', ')),
              ],
            ),
          ),
          if (!criteria.withDriver) ...[
            const SizedBox(height: 16),
            const MoncarSectionHeader(title: 'Pièces exigées'),
            MoncarCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Location sans chauffeur : le fournisseur vérifie votre '
                    'permis et votre pièce d\'identité à la remise.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: MoncarColors.inkMut,
                    ),
                  ),
                  const SizedBox(height: 12),
                  MoncarTextField(
                    label: 'N° de permis de conduire',
                    controller: _license,
                    hint: 'ex. CI-B-2019-004512',
                    prefixIcon: Icons.badge_outlined,
                    textCapitalization: TextCapitalization.characters,
                    error: required(_license),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  MoncarTextField(
                    label: "N° de pièce d'identité (CNI ou passeport)",
                    controller: _idDoc,
                    hint: 'ex. C0012345678',
                    prefixIcon: Icons.perm_identity,
                    textCapitalization: TextCapitalization.characters,
                    error: required(_idDoc),
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          const MoncarSectionHeader(title: 'Montant estimé'),
          RentalInvoiceCard(quote: quote),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: MoncarColors.brandSoft.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 16, color: MoncarColors.brand),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Vous ne payez rien maintenant. ${v.partner} confirme '
                    "d'abord la disponibilité ; vous serez notifié pour "
                    'procéder au paiement.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.45,
                      color: MoncarColors.inkMut,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            MoncarInlineError(message: _error!),
          ],
        ],
      ),
      bottomNavigationBar: StickyBottomBar(
        child: MoncarButton(
          label: 'Envoyer la demande',
          icon: Icons.send_outlined,
          variant: MoncarButtonVariant.primary,
          size: MoncarButtonSize.xl,
          expand: true,
          isLoading: _sending,
          onPressed: _sending ? null : () => _send(v, criteria),
        ),
      ),
    );
  }
}
