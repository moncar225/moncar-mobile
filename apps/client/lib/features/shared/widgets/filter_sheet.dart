import 'package:flutter/material.dart';

import 'package:core_ui/core_ui.dart';

import '../utils/format.dart';

/// Filtres de recherche de trajets (portage du `FilterSheet` web).
class TripFilters {
  const TripFilters({
    this.sort = TripSort.price,
    this.timeOfDay = TimeOfDayFilter.all,
    this.maxPrice,
    this.companies = const [],
    this.directOnly = false,
    this.minSeats = 1,
  });

  final TripSort sort;
  final TimeOfDayFilter timeOfDay;

  /// Prix maximum en FCFA ; null = tous les prix.
  final int? maxPrice;
  final List<String> companies; // ids de compagnies sélectionnées
  final bool directOnly;
  final int minSeats;
}

enum TripSort { price, duration, departure }

enum TimeOfDayFilter { all, morning, afternoon, evening }

/// Feuille de filtres avancés (portage du `FilterSheet` web) :
/// tri, plage horaire, prix max, compagnies, direct uniquement,
/// places minimum. Bouton « Afficher X trajets » collé en bas.
class FilterSheet {
  FilterSheet._();

  static Future<TripFilters?> show(
    BuildContext context, {
    required TripFilters filters,
    required List<({String id, String name, String color})> companies,
    required ({int min, int max}) priceRange,
    int? resultCount,
  }) {
    return showModalBottomSheet<TripFilters>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: MoncarColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _FilterSheetBody(
        initial: filters,
        companies: companies,
        priceRange: priceRange,
        resultCount: resultCount,
      ),
    );
  }
}

class _FilterSheetBody extends StatefulWidget {
  const _FilterSheetBody({
    required this.initial,
    required this.companies,
    required this.priceRange,
    this.resultCount,
  });

  final TripFilters initial;
  final List<({String id, String name, String color})> companies;
  final ({int min, int max}) priceRange;
  final int? resultCount;

  @override
  State<_FilterSheetBody> createState() => _FilterSheetBodyState();
}

class _FilterSheetBodyState extends State<_FilterSheetBody> {
  late TripFilters _draft = widget.initial;

  double get _sliderMax =>
      (widget.priceRange.max > widget.priceRange.min
              ? widget.priceRange.max
              : widget.priceRange.min + 1)
          .toDouble();

  @override
  Widget build(BuildContext context) {
    final isAtMax = _draft.maxPrice == null || _draft.maxPrice! >= _sliderMax;
    final footerLabel = widget.resultCount != null
        ? 'Afficher ${widget.resultCount} trajet${widget.resultCount! > 1 ? 's' : ''}'
        : 'Afficher les trajets';

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.9,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 6,
            decoration: BoxDecoration(
              color: MoncarColors.hairline,
              borderRadius: BorderRadius.all(Radius.circular(999)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Filtres',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: MoncarColors.ink,
                        ),
                      ),
                      Text(
                        'Affinez vos résultats',
                        style: TextStyle(
                          fontSize: 12,
                          color: MoncarColors.inkMut,
                        ),
                      ),
                    ],
                  ),
                ),
                Material(
                  color: MoncarColors.brandSoft.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(999),
                  child: InkWell(
                    onTap: () => setState(() => _draft = const TripFilters()),
                    borderRadius: BorderRadius.circular(999),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.restart_alt,
                            size: 14,
                            color: MoncarColors.brand,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Réinitialiser',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: MoncarColors.brand,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: MoncarColors.muted,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    child: SizedBox(
                      width: 36,
                      height: 36,
                      child: Icon(
                        Icons.close,
                        size: 16,
                        color: MoncarColors.inkMut,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              shrinkWrap: true,
              children: [
                _section(
                  'Trier par',
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final s in TripSort.values)
                        MoncarChip(
                          label: switch (s) {
                            TripSort.price => 'Prix',
                            TripSort.duration => 'Durée',
                            TripSort.departure => 'Départ',
                          },
                          active: _draft.sort == s,
                          onTap: () => setState(
                            () => _draft = TripFilters(
                              sort: s,
                              timeOfDay: _draft.timeOfDay,
                              maxPrice: _draft.maxPrice,
                              companies: _draft.companies,
                              directOnly: _draft.directOnly,
                              minSeats: _draft.minSeats,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                _section(
                  'Heure de départ',
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          for (final t in TimeOfDayFilter.values)
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(
                                  () => _draft = TripFilters(
                                    sort: _draft.sort,
                                    timeOfDay: t,
                                    maxPrice: _draft.maxPrice,
                                    companies: _draft.companies,
                                    directOnly: _draft.directOnly,
                                    minSeats: _draft.minSeats,
                                  ),
                                ),
                                child: Container(
                                  height: 60,
                                  margin: const EdgeInsets.only(right: 6),
                                  decoration: BoxDecoration(
                                    color: _draft.timeOfDay == t
                                        ? MoncarColors.brandSoft
                                        : MoncarColors.surface,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: _draft.timeOfDay == t
                                          ? MoncarColors.brand
                                          : MoncarColors.hairline,
                                      width: 2,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        switch (t) {
                                          TimeOfDayFilter.all =>
                                            Icons.wb_twilight,
                                          TimeOfDayFilter.morning =>
                                            Icons.wb_sunny,
                                          TimeOfDayFilter.afternoon =>
                                            Icons.wb_cloudy,
                                          TimeOfDayFilter.evening =>
                                            Icons.dark_mode_outlined,
                                        },
                                        size: 16,
                                        color: _draft.timeOfDay == t
                                            ? MoncarColors.brand
                                            : MoncarColors.inkMut,
                                      ),
                                      Text(
                                        switch (t) {
                                          TimeOfDayFilter.all => 'Tous',
                                          TimeOfDayFilter.morning => 'Matin',
                                          TimeOfDayFilter.afternoon =>
                                            'Après-midi',
                                          TimeOfDayFilter.evening => 'Soir',
                                        },
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: _draft.timeOfDay == t
                                              ? MoncarColors.brand
                                              : MoncarColors.inkMut,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Matin 5–12h · Après-midi 12–18h · Soir 18h–5h',
                        style: TextStyle(
                          fontSize: 11,
                          color: MoncarColors.inkFaint,
                        ),
                      ),
                    ],
                  ),
                ),
                _section(
                  'Prix maximum',
                  value: isAtMax
                      ? 'Tous les prix'
                      : '≤ ${formatXOF(_draft.maxPrice ?? _sliderMax.round())}',
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: MoncarColors.accent,
                          inactiveTrackColor: MoncarColors.hairline,
                          thumbColor: MoncarColors.accent,
                          trackHeight: 6,
                        ),
                        child: Slider(
                          min: widget.priceRange.min.toDouble(),
                          max: _sliderMax,
                          divisions:
                              ((_sliderMax - widget.priceRange.min) / 500)
                                  .round()
                                  .clamp(1, 1000),
                          value: (_draft.maxPrice ?? _sliderMax)
                              .clamp(
                                widget.priceRange.min.toDouble(),
                                _sliderMax,
                              )
                              .toDouble(),
                          onChanged: (v) => setState(() {
                            _draft = TripFilters(
                              sort: _draft.sort,
                              timeOfDay: _draft.timeOfDay,
                              maxPrice: v >= _sliderMax ? null : v.round(),
                              companies: _draft.companies,
                              directOnly: _draft.directOnly,
                              minSeats: _draft.minSeats,
                            );
                          }),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            formatXOF(widget.priceRange.min),
                            style: TextStyle(
                              fontSize: 11,
                              color: MoncarColors.inkMut,
                            ),
                          ),
                          Text(
                            formatXOF(_sliderMax.round()),
                            style: TextStyle(
                              fontSize: 11,
                              color: MoncarColors.inkMut,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (widget.companies.isNotEmpty)
                  _section(
                    'Compagnies',
                    Column(
                      children: [
                        for (final c in widget.companies)
                          InkWell(
                            onTap: () => setState(() {
                              final set = _draft.companies.toSet();
                              set.contains(c.id)
                                  ? set.remove(c.id)
                                  : set.add(c.id);
                              _draft = TripFilters(
                                sort: _draft.sort,
                                timeOfDay: _draft.timeOfDay,
                                maxPrice: _draft.maxPrice,
                                companies: set.toList(),
                                directOnly: _draft.directOnly,
                                minSeats: _draft.minSeats,
                              );
                            }),
                            borderRadius: BorderRadius.circular(10),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  Checkbox(
                                    value: _draft.companies.contains(c.id),
                                    onChanged: (_) => setState(() {
                                      final set = _draft.companies.toSet();
                                      set.contains(c.id)
                                          ? set.remove(c.id)
                                          : set.add(c.id);
                                      _draft = TripFilters(
                                        sort: _draft.sort,
                                        timeOfDay: _draft.timeOfDay,
                                        maxPrice: _draft.maxPrice,
                                        companies: set.toList(),
                                        directOnly: _draft.directOnly,
                                        minSeats: _draft.minSeats,
                                      );
                                    }),
                                  ),
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: Color(
                                        int.parse(
                                          'FF${c.color.substring(1)}',
                                          radix: 16,
                                        ),
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      c.name,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight:
                                            _draft.companies.contains(c.id)
                                            ? FontWeight.w600
                                            : FontWeight.w400,
                                        color: _draft.companies.contains(c.id)
                                            ? MoncarColors.ink
                                            : MoncarColors.inkMut,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Trajet direct uniquement',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: MoncarColors.ink,
                            ),
                          ),
                          Text(
                            'Sans arrêts intermédiaires',
                            style: TextStyle(
                              fontSize: 11,
                              color: MoncarColors.inkMut,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _draft.directOnly,
                      onChanged: (v) => setState(
                        () => _draft = TripFilters(
                          sort: _draft.sort,
                          timeOfDay: _draft.timeOfDay,
                          maxPrice: _draft.maxPrice,
                          companies: _draft.companies,
                          directOnly: v,
                          minSeats: _draft.minSeats,
                        ),
                      ),
                    ),
                  ],
                ),
                _section(
                  'Places minimum',
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Disponibles pour ce trajet',
                          style: TextStyle(
                            fontSize: 12,
                            color: MoncarColors.inkMut,
                          ),
                        ),
                      ),
                      _SeatStepper(
                        value: _draft.minSeats,
                        onChanged: (n) => setState(
                          () => _draft = TripFilters(
                            sort: _draft.sort,
                            timeOfDay: _draft.timeOfDay,
                            maxPrice: _draft.maxPrice,
                            companies: _draft.companies,
                            directOnly: _draft.directOnly,
                            minSeats: n,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: MoncarColors.hairline)),
            ),
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              16 + MediaQuery.paddingOf(context).bottom * 0,
            ),
            child: MoncarButton(
              label: footerLabel,
              variant: MoncarButtonVariant.primary,
              size: MoncarButtonSize.lg,
              expand: true,
              onPressed: () => Navigator.of(context).pop(_draft),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, Widget child, {String? value}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: MoncarColors.inkMut,
                  ),
                ),
              ),
              if (value != null)
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: MoncarColors.accent,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _SeatStepper extends StatelessWidget {
  const _SeatStepper({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _stepButton(
          icon: Icons.remove,
          enabled: value > 1,
          onTap: () => onChanged(value - 1),
          accent: false,
        ),
        SizedBox(
          width: 32,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: MoncarColors.ink,
            ),
          ),
        ),
        _stepButton(
          icon: Icons.add,
          enabled: value < 10,
          onTap: () => onChanged(value + 1),
          accent: true,
        ),
      ],
    );
  }

  Widget _stepButton({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
    required bool accent,
  }) {
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Material(
        color: accent ? MoncarColors.accentSoft : MoncarColors.surface,
        shape: CircleBorder(
          side: BorderSide(
            color: accent ? MoncarColors.accent : MoncarColors.hairline,
            width: 2,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(
              icon,
              size: 16,
              color: accent ? MoncarColors.accent : MoncarColors.brand,
            ),
          ),
        ),
      ),
    );
  }
}
