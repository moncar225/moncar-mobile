import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/foundation.dart';
import '../application/device_location.dart';
import '../widgets/location_widgets.dart';

/// Onglet « Louer un véhicule » — critères de la demande (§26 à §32) :
/// point de prise en charge (GPS), intérieur/extérieur, destination,
/// motif, nombre de personnes, type de véhicule, date/durée, chauffeur.
class LocationPage extends ConsumerStatefulWidget {
  const LocationPage({super.key});

  @override
  ConsumerState<LocationPage> createState() => _LocationPageState();
}

class _LocationPageState extends ConsumerState<LocationPage> {
  bool _locating = false;
  String? _gpsError;

  RentalSearch get _s => ref.read(rentalSearchProvider);

  void _update(RentalSearch Function(RentalSearch) fn) =>
      ref.read(rentalSearchProvider.notifier).update(fn);

  @override
  void initState() {
    super.initState();
    // §26 : la position actuelle est proposée automatiquement.
    if (!_s.usedGps && DeviceLocation.enabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _locate());
    }
  }

  Future<void> _locate() async {
    setState(() {
      _locating = true;
      _gpsError = null;
    });
    final cities = ref.read(mockStoreProvider).cities;
    final r = await DeviceLocation.nearestCity(cities);
    if (!mounted) return;
    setState(() {
      _locating = false;
      _gpsError = r.error;
    });
    final city = r.city;
    if (city != null) {
      _update(
        (s) => s.copyWith(
          pickupCity: city.name,
          pickupLabel: 'Ma position actuelle · ${city.name}',
          usedGps: true,
        ),
      );
    }
  }

  Future<void> _pickPickupCity() async {
    final city = await CityPicker.show(
      context,
      title: 'Point de prise en charge',
      selectedName: _s.pickupCity,
    );
    if (city == null) return;
    _update(
      (s) => s.copyWith(
        pickupCity: city.name,
        pickupLabel: city.name,
        usedGps: false,
      ),
    );
  }

  Future<void> _pickDestination() async {
    final city = await CityPicker.show(
      context,
      title: 'Lieu de destination',
      selectedName: _s.destinationCity,
      excludeCity: _s.pickupCity,
    );
    if (city == null) return;
    _update((s) => s.copyWith(destinationCity: city.name));
  }

  Future<void> _pickPurpose() async {
    final purpose = await showModalBottomSheet<RentalPurpose>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: MoncarColors.surface,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Text(
                'Motif du déplacement',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: MoncarColors.ink,
                ),
              ),
            ),
            for (final p in RentalPurpose.values)
              ListTile(
                title: Text(p.label),
                trailing: p == _s.purpose
                    ? Icon(Icons.check, color: MoncarColors.brand)
                    : null,
                onTap: () => Navigator.pop(context, p),
              ),
          ],
        ),
      ),
    );
    if (purpose != null) _update((s) => s.copyWith(purpose: purpose));
  }

  Future<void> _pickStart() async {
    final d = await pickRentalDateTime(context, _s.start);
    if (d != null) _update((s) => s.copyWith(start: d));
  }

  Future<void> _pickCustomEnd() async {
    final d = await pickRentalDateTime(
      context,
      _s.end,
      first: _s.start.add(const Duration(hours: 1)),
    );
    if (d != null) _update((s) => s.copyWith(customEnd: d));
  }

  void _search() {
    final error = _s.validationError;
    if (error != null) {
      showMoncarToast(context, error, error: true);
      return;
    }
    context.push('/location/results');
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(rentalSearchProvider);
    ref.watch(mockStoreChangesProvider);
    final myRentals = ref.read(mockStoreProvider).rentals;
    final ongoing = myRentals
        .where(
          (r) =>
              r.status != RentalStatus.terminee &&
              r.status != RentalStatus.annulee &&
              r.status != RentalStatus.refusee,
        )
        .length;
    final types = switch (s.collective) {
      true => collectiveVehicleTypes,
      false => privateVehicleTypes,
      null => [...privateVehicleTypes, ...collectiveVehicleTypes],
    };

    return ColoredBox(
      color: MoncarColors.background,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          // En-tête + carte dans un même bloc (zone chevauchée tactile).
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BrandTabHeader(
                bottomPadding: 64,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Louer un véhicule',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Agences, compagnies et particuliers vérifiés.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _MyRentalsButton(
                      count: ongoing,
                      onTap: () => context.push('/location/mine'),
                    ),
                  ],
                ),
              ),
              Transform.translate(
                offset: const Offset(0, -40),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: MoncarCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _SectionLabel('Point de prise en charge'),
                        _TapField(
                          icon: s.usedGps
                              ? Icons.my_location
                              : Icons.place_outlined,
                          iconColor: MoncarColors.brand,
                          value: _locating
                              ? 'Recherche de votre position…'
                              : s.pickupLabel,
                          onTap: _pickPickupCity,
                          trailing: 'Modifier',
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            TextButton.icon(
                              onPressed: _locating ? null : _locate,
                              icon: const Icon(Icons.my_location, size: 14),
                              label: const Text('Ma position actuelle'),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          _gpsError ??
                              (s.usedGps
                                  ? 'Position détectée automatiquement.'
                                  : 'Utilisez votre position ou choisissez une localité.'),
                          style: TextStyle(
                            fontSize: 11,
                            color: _gpsError != null
                                ? MoncarColors.danger
                                : MoncarColors.inkFaint,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const _SectionLabel('Déplacement'),
                        _Segmented<RentalArea>(
                          values: RentalArea.values,
                          selected: s.area,
                          label: (a) => a.label,
                          onChanged: (a) => _update((x) => x.copyWith(area: a)),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          s.area == RentalArea.interieur
                              ? 'Le déplacement reste dans la localité de ${s.pickupCity}.'
                              : 'Vous quittez ${s.pickupCity} : la destination est obligatoire.',
                          style: TextStyle(
                            fontSize: 11,
                            color: MoncarColors.inkFaint,
                          ),
                        ),
                        if (s.area == RentalArea.exterieur) ...[
                          const SizedBox(height: 10),
                          _TapField(
                            icon: Icons.flag_outlined,
                            iconColor: MoncarColors.accent,
                            label: 'Lieu de destination',
                            value:
                                s.destinationCity ?? 'Choisir la destination',
                            placeholder: s.destinationCity == null,
                            onTap: _pickDestination,
                          ),
                        ],
                        const SizedBox(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const _SectionLabel('Motif'),
                                  _TapField(
                                    icon: Icons.event_note_outlined,
                                    iconColor: MoncarColors.brand,
                                    value: s.purpose.label,
                                    onTap: _pickPurpose,
                                    dense: true,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              width: 128,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const _SectionLabel('Personnes'),
                                  _Stepper(
                                    value: s.persons,
                                    min: 1,
                                    max: 60,
                                    onChanged: (n) =>
                                        _update((x) => x.copyWith(persons: n)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const _SectionLabel('Type de véhicule'),
                        _Segmented<bool?>(
                          values: const [null, false, true],
                          selected: s.collective,
                          label: (c) => switch (c) {
                            null => 'Tous',
                            false => 'Particulier',
                            true => 'Collectif',
                          },
                          onChanged: (c) => _update(
                            (x) => x.copyWith(
                              collective: c,
                              clearCollective: c == null,
                              clearType: true,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            MoncarChip(
                              label: 'Tous types',
                              active: s.type == null,
                              onTap: () =>
                                  _update((x) => x.copyWith(clearType: true)),
                            ),
                            for (final t in types)
                              MoncarChip(
                                label: vehicleLabel(t),
                                icon: vehicleIcon(t),
                                active: s.type == t,
                                onTap: () => _update(
                                  (x) => x.copyWith(
                                    type: t,
                                    withDriver: t == VehicleType.vtc
                                        ? true
                                        : null,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const _SectionLabel('Prise en charge prévue'),
                        _TapField(
                          icon: Icons.calendar_today_outlined,
                          iconColor: MoncarColors.brand,
                          value: formatRentalDateTime(s.start),
                          onTap: _pickStart,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Le début réel de la location correspond à la remise effective du véhicule.',
                          style: TextStyle(
                            fontSize: 11,
                            color: MoncarColors.inkFaint,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const _SectionLabel('Durée'),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final d in RentalDurationPreset.values)
                              MoncarChip(
                                label: d.label,
                                active: s.durationPreset == d,
                                onTap: () => _update(
                                  (x) => x.copyWith(
                                    durationPreset: d,
                                    count:
                                        d == RentalDurationPreset.plusieursJours
                                        ? 2
                                        : d ==
                                              RentalDurationPreset
                                                  .plusieursSemaines
                                        ? 2
                                        : null,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (s.durationPreset ==
                                RentalDurationPreset.plusieursJours ||
                            s.durationPreset ==
                                RentalDurationPreset.plusieursSemaines) ...[
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  s.durationPreset ==
                                          RentalDurationPreset.plusieursJours
                                      ? 'Nombre de jours'
                                      : 'Nombre de semaines',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: MoncarColors.inkMut,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 128,
                                child: _Stepper(
                                  value: s.count,
                                  min: 2,
                                  max:
                                      s.durationPreset ==
                                          RentalDurationPreset.plusieursJours
                                      ? 6
                                      : 4,
                                  onChanged: (n) =>
                                      _update((x) => x.copyWith(count: n)),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (s.durationPreset ==
                            RentalDurationPreset.personnalisee) ...[
                          const SizedBox(height: 10),
                          _TapField(
                            icon: Icons.event_available_outlined,
                            iconColor: MoncarColors.accent,
                            label: 'Fin prévue',
                            value: formatRentalDateTime(s.end),
                            onTap: _pickCustomEnd,
                          ),
                        ] else ...[
                          const SizedBox(height: 8),
                          Text(
                            'Fin prévue : ${formatRentalDateTime(s.end)}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: MoncarColors.inkMut,
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        const _SectionLabel('Chauffeur'),
                        _Segmented<bool>(
                          values: const [true, false],
                          selected: s.effectiveWithDriver,
                          disabled: s.driverForced ? {false} : const {},
                          label: (w) => w ? 'Avec chauffeur' : 'Sans chauffeur',
                          onChanged: (w) =>
                              _update((x) => x.copyWith(withDriver: w)),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          s.driverForced
                              ? 'Un VTC est toujours fourni avec chauffeur.'
                              : s.effectiveWithDriver
                              ? 'Le fournisseur met le véhicule et le chauffeur à disposition.'
                              : 'Vous conduisez : permis et pièce d\'identité exigés.',
                          style: TextStyle(
                            fontSize: 11,
                            color: MoncarColors.inkFaint,
                          ),
                        ),
                        const SizedBox(height: 18),
                        MoncarButton(
                          label: 'Voir les véhicules disponibles',
                          icon: Icons.search,
                          variant: MoncarButtonVariant.primary,
                          size: MoncarButtonSize.xl,
                          expand: true,
                          onPressed: _search,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          Transform.translate(
            offset: const Offset(0, -24),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: _HowItWorks(),
            ),
          ),
        ],
      ),
    );
  }
}

class _MyRentalsButton extends StatelessWidget {
  const _MyRentalsButton({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.receipt_long_outlined,
                size: 16,
                color: Colors.white,
              ),
              const SizedBox(width: 6),
              const Text(
                'Mes locations',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: MoncarColors.accent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: OverlineText(text, color: MoncarColors.inkMut),
    );
  }
}

class _TapField extends StatelessWidget {
  const _TapField({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.onTap,
    this.label,
    this.trailing,
    this.placeholder = false,
    this.dense = false,
  });

  final IconData icon;
  final Color iconColor;
  final String value;
  final String? label;
  final String? trailing;
  final bool placeholder;
  final bool dense;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: 12,
          vertical: dense ? 12 : 14,
        ),
        decoration: BoxDecoration(
          color: MoncarColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: MoncarColors.hairline),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: iconColor),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (label != null)
                    Text(
                      label!,
                      style: TextStyle(
                        fontSize: 11,
                        color: MoncarColors.inkMut,
                      ),
                    ),
                  Text(
                    value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: dense ? 13 : 14,
                      fontWeight: FontWeight.w600,
                      color: placeholder
                          ? MoncarColors.inkFaint
                          : MoncarColors.ink,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null)
              Text(
                trailing!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: MoncarColors.brand,
                ),
              )
            else
              Icon(
                Icons.keyboard_arrow_down,
                size: 18,
                color: MoncarColors.inkFaint,
              ),
          ],
        ),
      ),
    );
  }
}

class _Segmented<T> extends StatelessWidget {
  const _Segmented({
    required this.values,
    required this.selected,
    required this.label,
    required this.onChanged,
    this.disabled = const {},
  });

  final List<T> values;
  final T selected;
  final String Function(T) label;
  final ValueChanged<T> onChanged;
  final Set<T> disabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: MoncarColors.muted,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          for (final v in values)
            Expanded(
              child: Semantics(
                button: true,
                selected: v == selected,
                enabled: !disabled.contains(v),
                child: GestureDetector(
                  onTap: disabled.contains(v) ? null : () => onChanged(v),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: v == selected
                          ? MoncarColors.surface
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
                      boxShadow: v == selected
                          ? [
                              BoxShadow(
                                color: MoncarColors.ink.withValues(alpha: 0.08),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Text(
                      label(v),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: disabled.contains(v)
                            ? MoncarColors.inkFaint.withValues(alpha: 0.5)
                            : v == selected
                            ? MoncarColors.brand
                            : MoncarColors.inkMut,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget btn(IconData icon, bool enabled, int next, String tooltip) =>
        IconButton(
          tooltip: tooltip,
          visualDensity: VisualDensity.compact,
          onPressed: enabled ? () => onChanged(next) : null,
          icon: Icon(icon, size: 18),
          color: MoncarColors.brand,
        );
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MoncarColors.hairline),
      ),
      child: Row(
        children: [
          btn(Icons.remove, value > min, value - 1, 'Moins'),
          Expanded(
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: MoncarColors.ink,
              ),
            ),
          ),
          btn(Icons.add, value < max, value + 1, 'Plus'),
        ],
      ),
    );
  }
}

/// Explique le principe : on ne paie qu'après confirmation (§36-39).
class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  @override
  Widget build(BuildContext context) {
    const steps = [
      (
        Icons.send_outlined,
        'Demande',
        'Vous demandez une réservation, sans payer.',
      ),
      (
        Icons.verified_outlined,
        'Confirmation',
        'Le fournisseur confirme la disponibilité.',
      ),
      (
        Icons.lock_outline,
        'Paiement sécurisé',
        'Vous payez ; les fonds sont protégés par MON CAR.',
      ),
      (
        Icons.key_outlined,
        'Remise',
        'Vous vérifiez le véhicule, puis la location démarre.',
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const MoncarSectionHeader(title: 'Comment ça marche ?'),
        MoncarCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              for (var i = 0; i < steps.length; i++)
                Padding(
                  padding: EdgeInsets.only(
                    bottom: i == steps.length - 1 ? 0 : 12,
                  ),
                  child: Row(
                    children: [
                      IconTile(
                        icon: steps[i].$1,
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
                              '${i + 1}. ${steps[i].$2}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: MoncarColors.ink,
                              ),
                            ),
                            Text(
                              steps[i].$3,
                              style: TextStyle(
                                fontSize: 12,
                                color: MoncarColors.inkMut,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
