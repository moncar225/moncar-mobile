import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/foundation.dart';
import '../widgets/voyager_widgets.dart';

/// Onglet Voyager : formulaire de recherche, ou liste de résultats
/// lorsque l'URL porte `origin`/`destination` (ex-`voyager/results`).
class VoyagerPage extends StatelessWidget {
  const VoyagerPage({super.key});

  @override
  Widget build(BuildContext context) {
    final q = GoRouterState.of(context).uri.queryParameters;
    if (q.containsKey('origin') || q.containsKey('destination')) {
      return _ResultsView(
        key: ValueKey(q.toString()),
        origin: q['origin'] ?? 'Abidjan',
        destination: q['destination'] ?? 'Yamoussoukro',
        date: q['date'] ?? todayStr(),
        passengers: (int.tryParse(q['passengers'] ?? '') ?? 1).clamp(
          1,
          maxPassengers,
        ),
        tripType: tripTypeFromName(q['type'] ?? ''),
        returnDate: q['returnDate'],
        isReturn: q['leg'] == 'retour',
      );
    }
    return const _SearchView();
  }
}

// =================== RECHERCHE ===================

class _SearchView extends StatefulWidget {
  const _SearchView();

  @override
  State<_SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<_SearchView> {
  String _origin = 'Abidjan';
  String _destination = 'Yamoussoukro';
  String _date = dateOffset(1);
  int _passengers = 1;
  TripType _tripType = TripType.allerSimple;
  String _returnDate = dateOffset(1);

  static const _popularRoutes = [
    (origin: 'Abidjan', destination: 'Yamoussoukro', price: 5000),
    (origin: 'Abidjan', destination: 'Bouaké', price: 9000),
    (origin: 'Abidjan', destination: 'San-Pédro', price: 10000),
    (origin: 'Abidjan', destination: 'Korhogo', price: 15000),
  ];

  void _search() {
    final params = Uri(
      queryParameters: {
        'origin': _origin,
        'destination': _destination,
        'date': _date,
        'passengers': '$_passengers',
        'type': _tripType.apiName,
        if (_tripType == TripType.allerRetour) 'returnDate': _returnDate,
      },
    ).query;
    context.push('/voyager?$params');
  }

  Future<void> _pickCity({required bool origin}) async {
    final city = await CityPicker.show(
      context,
      title: origin ? 'Départ' : 'Destination',
      selectedName: origin ? _origin : _destination,
      excludeCity: origin ? _destination : _origin,
    );
    if (city == null) return;
    setState(() => origin ? _origin = city.name : _destination = city.name);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.parse(_date),
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() {
      _date = picked.toIso8601String().substring(0, 10);
      // Le retour ne peut pas précéder l'aller.
      if (_returnDate.compareTo(_date) < 0) _returnDate = _date;
    });
  }

  Future<void> _pickReturnDate() async {
    final outbound = DateTime.parse(_date);
    final picked = await showDatePicker(
      context: context,
      helpText: 'Date du retour',
      initialDate: DateTime.parse(_returnDate),
      firstDate: outbound,
      lastDate: outbound.add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() => _returnDate = picked.toIso8601String().substring(0, 10));
  }

  Widget _passengersPicker() {
    return PopupMenuButton<int>(
      initialValue: _passengers,
      onSelected: (n) => setState(() => _passengers = n),
      itemBuilder: (_) => [
        for (var n = 1; n <= maxPassengers; n++)
          PopupMenuItem(
            value: n,
            child: Text('$n ${n == 1 ? 'passager' : 'passagers'}'),
          ),
      ],
      child: _SelectBox(
        icon: Icons.group_outlined,
        iconColor: MoncarColors.brand,
        label: 'Passagers',
        value: '$_passengers ${_passengers == 1 ? 'passager' : 'passagers'}',
        small: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: MoncarColors.background,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          // En-tête + carte dans un même bloc : la carte chevauche
          // l'en-tête (translation) et doit recevoir les taps sur toute
          // sa hauteur — séparées dans le ListView, la zone chevauchée
          // était attribuée à l'en-tête (boutons Aller simple / retour
          // inactifs).
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BrandTabHeader(
                bottomPadding: 80,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Où allez-vous ?',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Trouvez le trajet parfait parmi nos compagnies partenaires.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              Transform.translate(
                offset: const Offset(0, -48),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: MoncarCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            _TripTypeButton(
                              label: 'Aller simple',
                              active: _tripType == TripType.allerSimple,
                              onTap: () => setState(
                                () => _tripType = TripType.allerSimple,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _TripTypeButton(
                              label: 'Aller-retour',
                              active: _tripType == TripType.allerRetour,
                              onTap: () => setState(
                                () => _tripType = TripType.allerRetour,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Stack(
                          alignment: Alignment.centerRight,
                          children: [
                            Column(
                              children: [
                                _SelectBox(
                                  icon: Icons.place_outlined,
                                  iconColor: MoncarColors.brand,
                                  label: 'Départ',
                                  value: _origin,
                                  trailing: Icons.keyboard_arrow_down,
                                  onTap: () => _pickCity(origin: true),
                                ),
                                const SizedBox(height: 8),
                                _SelectBox(
                                  icon: Icons.place_outlined,
                                  iconColor: MoncarColors.accent,
                                  label: 'Destination',
                                  value: _destination,
                                  trailing: Icons.keyboard_arrow_down,
                                  onTap: () => _pickCity(origin: false),
                                ),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: _SwapButton(
                                onTap: () => setState(() {
                                  final o = _origin;
                                  _origin = _destination;
                                  _destination = o;
                                }),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _SelectBox(
                                icon: Icons.calendar_today_outlined,
                                iconColor: MoncarColors.brand,
                                label: _tripType == TripType.allerRetour
                                    ? 'Aller'
                                    : 'Date',
                                value: formatDateNumeric(_date),
                                small: true,
                                onTap: _pickDate,
                              ),
                            ),
                            if (_tripType == TripType.allerRetour) ...[
                              const SizedBox(width: 8),
                              Expanded(
                                child: _SelectBox(
                                  icon: Icons.event_repeat_outlined,
                                  iconColor: MoncarColors.accent,
                                  label: 'Retour',
                                  value: formatDateNumeric(_returnDate),
                                  small: true,
                                  onTap: _pickReturnDate,
                                ),
                              ),
                            ],
                            if (_tripType != TripType.allerRetour) ...[
                              const SizedBox(width: 8),
                              Expanded(child: _passengersPicker()),
                            ],
                          ],
                        ),
                        // Aller-retour : trois cases sur une ligne seraient
                        // illisibles sur petit écran — passagers en dessous.
                        if (_tripType == TripType.allerRetour) ...[
                          const SizedBox(height: 8),
                          _passengersPicker(),
                        ],
                        const SizedBox(height: 12),
                        MoncarButton(
                          label: 'Rechercher un voyage',
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
            offset: const Offset(0, -28),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const MoncarSectionHeader(title: 'Trajets populaires'),
                  for (final r in _popularRoutes) ...[
                    MoncarCard(
                      padding: const EdgeInsets.all(12),
                      onTap: () => setState(() {
                        _origin = r.origin;
                        _destination = r.destination;
                      }),
                      child: Row(
                        children: [
                          IconTile(
                            icon: Icons.directions_bus_outlined,
                            background: MoncarColors.brandSoft,
                            size: 44,
                            radius: 22,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        r.origin,
                                        overflow: TextOverflow.ellipsis,
                                        style: _routeStyle,
                                      ),
                                    ),
                                    Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 6,
                                      ),
                                      child: Icon(
                                        Icons.arrow_forward,
                                        size: 12,
                                        color: MoncarColors.accent,
                                      ),
                                    ),
                                    Flexible(
                                      child: Text(
                                        r.destination,
                                        overflow: TextOverflow.ellipsis,
                                        style: _routeStyle,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  'À partir de ${formatXOF(r.price)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: MoncarColors.inkMut,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            size: 16,
                            color: MoncarColors.inkFaint,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  const SizedBox(height: 12),
                  const MoncarSectionHeader(
                    title: 'Pourquoi voyager avec MON CAR ?',
                  ),
                  Row(
                    children: [
                      _WhyCard(
                        icon: Icons.bolt,
                        title: 'Réservation rapide',
                        color: MoncarColors.accent,
                        bg: MoncarColors.accentSoft,
                      ),
                      SizedBox(width: 8),
                      _WhyCard(
                        icon: Icons.star_border,
                        title: 'Compagnies vérifiées',
                        color: MoncarColors.brand,
                        bg: MoncarColors.brandSoft,
                      ),
                      SizedBox(width: 8),
                      _WhyCard(
                        icon: Icons.directions_bus_outlined,
                        title: 'Billet QR sécurisé',
                        color: MoncarColors.success,
                        bg: MoncarColors.successSoft,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static final _routeStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: MoncarColors.ink,
  );
}

class _TripTypeButton extends StatelessWidget {
  const _TripTypeButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? MoncarColors.brandSoft : MoncarColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: active ? MoncarColors.brand : MoncarColors.hairline,
              width: 2,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: active ? MoncarColors.brand : MoncarColors.inkMut,
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectBox extends StatelessWidget {
  const _SelectBox({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.trailing,
    this.onTap,
    this.small = false,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final IconData? trailing;
  final VoidCallback? onTap;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final box = Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: MoncarColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MoncarColors.hairline),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: MoncarColors.inkMut,
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: small ? 13 : 15,
                    fontWeight: FontWeight.w600,
                    color: MoncarColors.ink,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null)
            Icon(trailing, size: 16, color: MoncarColors.inkFaint),
        ],
      ),
    );
    if (onTap == null) return box;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: box,
    );
  }
}

class _SwapButton extends StatelessWidget {
  const _SwapButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Inverser',
      child: Material(
        color: MoncarColors.surface,
        elevation: 1,
        shape: CircleBorder(
          side: BorderSide(color: MoncarColors.accent, width: 2),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 36,
            height: 36,
            child: Icon(Icons.swap_vert, size: 18, color: MoncarColors.accent),
          ),
        ),
      ),
    );
  }
}

class _WhyCard extends StatelessWidget {
  const _WhyCard({
    required this.icon,
    required this.title,
    required this.color,
    required this.bg,
  });

  final IconData icon;
  final String title;
  final Color color;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: MoncarColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: MoncarColors.hairline),
        ),
        child: Column(
          children: [
            IconTile(icon: icon, color: color, background: bg, radius: 20),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                height: 1.2,
                fontWeight: FontWeight.w600,
                color: MoncarColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =================== RÉSULTATS ===================

class _ResultsView extends ConsumerStatefulWidget {
  const _ResultsView({
    super.key,
    required this.origin,
    required this.destination,
    required this.date,
    required this.passengers,
    required this.tripType,
    this.returnDate,
    this.isReturn = false,
  });

  final String origin;
  final String destination;
  final String date;
  final int passengers;
  final TripType tripType;

  /// Date du retour (aller-retour, recherche de l'aller).
  final String? returnDate;

  /// `true` pendant le choix du trajet retour d'un aller-retour.
  final bool isReturn;

  @override
  ConsumerState<_ResultsView> createState() => _ResultsViewState();
}

class _ResultsViewState extends ConsumerState<_ResultsView> {
  static const _defaultFilters = TripFilters();

  TripFilters _filters = _defaultFilters;
  final List<String> _compare = [];
  List<Trip>? _trips;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Le nombre de passagers choisi à la recherche est conservé jusqu'au
    // plan de sièges (via le brouillon de réservation).
    Future.microtask(
      () => ref
          .read(bookingDraftProvider.notifier)
          .update(
            (d) => widget.isReturn
                ? d
                : d.copyWith(
                    passengerCount: widget.passengers,
                    tripType: widget.tripType,
                    returnDate: widget.returnDate,
                  ),
          ),
    );
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _trips = null;
      _error = null;
    });
    // ⚠️ MOCK : GET /trips/search (latence simulée).
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;
    final trips = ref
        .read(mockStoreProvider)
        .searchTrips(
          origin: widget.origin,
          destination: widget.destination,
          date: widget.date,
        );
    ref
        .read(favoritesProvider.notifier)
        .addRecent(
          origin: widget.origin,
          destination: widget.destination,
          date: widget.date,
          passengers: widget.passengers,
        );
    setState(() => _trips = trips);
  }

  List<({String id, String name, String color})> get _companies {
    final seen = <String>{};
    return [
      for (final t in _trips ?? const <Trip>[])
        if (seen.add(t.companyId))
          (id: t.companyId, name: t.companyName, color: t.companyColor),
    ];
  }

  ({int min, int max}) get _priceRange {
    final trips = _trips ?? const <Trip>[];
    if (trips.isEmpty) return (min: 0, max: 10000);
    final prices = trips.map((t) => t.priceXOF);
    return (
      min: prices.reduce((a, b) => a < b ? a : b),
      max: prices.reduce((a, b) => a > b ? a : b),
    );
  }

  List<Trip> get _sorted {
    final f = _filters;
    final list = (_trips ?? const <Trip>[]).where((t) {
      if (f.timeOfDay != TimeOfDayFilter.all) {
        final h = int.parse(t.departureTime.substring(0, 2));
        final ok = switch (f.timeOfDay) {
          TimeOfDayFilter.morning => h >= 5 && h < 12,
          TimeOfDayFilter.afternoon => h >= 12 && h < 18,
          TimeOfDayFilter.evening => h >= 18 || h < 5,
          TimeOfDayFilter.all => true,
        };
        if (!ok) return false;
      }
      if (f.maxPrice != null && t.priceXOF > f.maxPrice!) return false;
      if (f.companies.isNotEmpty && !f.companies.contains(t.companyId)) {
        return false;
      }
      if (f.directOnly && !t.direct) return false;
      if (t.seatsAvailable < f.minSeats) return false;
      return true;
    }).toList();
    list.sort(
      (a, b) => switch (f.sort) {
        TripSort.price => a.priceXOF.compareTo(b.priceXOF),
        TripSort.duration => a.durationMin.compareTo(b.durationMin),
        TripSort.departure => a.departureTime.compareTo(b.departureTime),
      },
    );
    return list;
  }

  int get _activeFilterCount =>
      (_filters.timeOfDay != TimeOfDayFilter.all ? 1 : 0) +
      (_filters.maxPrice != null ? 1 : 0) +
      _filters.companies.length +
      (_filters.directOnly ? 1 : 0) +
      (_filters.minSeats > 1 ? 1 : 0);

  TripFilters _with({TripSort? sort, TimeOfDayFilter? timeOfDay}) =>
      TripFilters(
        sort: sort ?? _filters.sort,
        timeOfDay: timeOfDay ?? _filters.timeOfDay,
        maxPrice: _filters.maxPrice,
        companies: _filters.companies,
        directOnly: _filters.directOnly,
        minSeats: _filters.minSeats,
      );

  Future<void> _openFilters() async {
    final result = await FilterSheet.show(
      context,
      filters: _filters,
      companies: _companies,
      priceRange: _priceRange,
      resultCount: _sorted.length,
    );
    if (result != null) setState(() => _filters = result);
  }

  String get _legQuery => widget.isReturn ? '?leg=retour' : '';

  void _toggleCompare(String id) {
    setState(() {
      if (_compare.contains(id)) {
        _compare.remove(id);
      } else if (_compare.length < 3) {
        _compare.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final sorted = _sorted;
    final p = widget.passengers;
    return Scaffold(
      backgroundColor: MoncarColors.background,
      appBar: TopBar(
        title: '${widget.origin} → ${widget.destination}',
        subtitle:
            '${formatDateWithDay(widget.date)} · $p ${p == 1 ? 'passager' : 'passagers'}',
        showBack: true,
        showBell: false,
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Container(
                color: MoncarColors.surface,
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  children: [
                    SizedBox(
                      height: 36,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          for (final (k, label) in const [
                            (TripSort.price, 'Prix'),
                            (TripSort.duration, 'Durée'),
                            (TripSort.departure, 'Départ'),
                          ]) ...[
                            MoncarChip(
                              label: label,
                              active: _filters.sort == k,
                              onTap: () =>
                                  setState(() => _filters = _with(sort: k)),
                            ),
                            const SizedBox(width: 8),
                          ],
                          _FilterChipButton(
                            count: _activeFilterCount,
                            onTap: _openFilters,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 36,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          for (final (k, label) in const [
                            (TimeOfDayFilter.all, 'Tous'),
                            (TimeOfDayFilter.morning, 'Matin'),
                            (TimeOfDayFilter.afternoon, 'Après-midi'),
                            (TimeOfDayFilter.evening, 'Soir'),
                          ]) ...[
                            MoncarChip(
                              label: label,
                              active: _filters.timeOfDay == k,
                              onTap: () => setState(
                                () => _filters = _with(timeOfDay: k),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: MoncarColors.hairline),
              Expanded(
                child: _trips == null
                    ? const Padding(
                        padding: EdgeInsets.all(16),
                        child: MoncarListSkeleton(count: 4),
                      )
                    : _error != null
                    ? MoncarErrorState(message: _error!, onRetry: _load)
                    : sorted.isEmpty
                    ? MoncarEmptyState(
                        icon: Icons.directions_bus_outlined,
                        title: widget.isReturn
                            ? 'Aucun trajet retour'
                            : 'Aucun trajet trouvé',
                        message:
                            'Aucun voyage ${widget.origin} → ${widget.destination} pour cette date.',
                        actionLabel: 'Modifier la recherche',
                        onAction: () => context.mcBack(),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.separated(
                          padding: EdgeInsets.fromLTRB(
                            16,
                            12,
                            16,
                            _compare.length >= 2 ? 100 : 24,
                          ),
                          itemCount: sorted.length + 1,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, i) {
                            if (i == 0) {
                              final n = sorted.length;
                              final s = n > 1 ? 's' : '';
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (widget.tripType ==
                                      TripType.allerRetour) ...[
                                    RoundTripBanner(
                                      isReturn: widget.isReturn,
                                      outbound: ref
                                          .read(bookingDraftProvider)
                                          .outboundLeg,
                                    ),
                                    const SizedBox(height: 12),
                                  ],
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    child: Text(
                                      '$n trajet$s trouvé$s',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: MoncarColors.inkMut,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }
                            final trip = sorted[i - 1];
                            return TripCard(
                              trip: trip,
                              compared: _compare.contains(trip.id),
                              onSelect: () => context.push(
                                '/voyager/trip/${trip.id}$_legQuery',
                              ),
                              onCompare: () => _toggleCompare(trip.id),
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
          if (_compare.length >= 2)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: SafeArea(
                top: false,
                child: _CompareBar(
                  count: _compare.length,
                  onCompare: () => context.push(
                    '/voyager/compare?ids=${_compare.join(',')}'
                    '${widget.isReturn ? '&leg=retour' : ''}',
                  ),
                  onClear: () => setState(_compare.clear),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterChipButton extends StatelessWidget {
  const _FilterChipButton({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final active = count > 0;
    return Semantics(
      button: true,
      label: 'Filtres avancés',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: active ? MoncarColors.accent : MoncarColors.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: active ? MoncarColors.accent : MoncarColors.hairline,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.filter_alt_outlined,
                size: 14,
                color: active ? Colors.white : MoncarColors.inkMut,
              ),
              const SizedBox(width: 6),
              Text(
                'Filtres',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: active ? Colors.white : MoncarColors.inkMut,
                ),
              ),
              if (active) ...[
                const SizedBox(width: 4),
                Container(
                  constraints: const BoxConstraints(minWidth: 16),
                  height: 16,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: MoncarColors.surface,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: MoncarColors.accent,
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

class _CompareBar extends StatelessWidget {
  const _CompareBar({
    required this.count,
    required this.onCompare,
    required this.onClear,
  });

  final int count;
  final VoidCallback onCompare;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: brandGradientDecoration(radius: BorderRadius.circular(16))
              .copyWith(
                boxShadow: [
                  BoxShadow(
                    color: MoncarColors.brand.withValues(alpha: 0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Comparer $count trajets',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                    const Text(
                      'Voir la comparaison',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              MoncarButton(
                label: 'Comparer →',
                variant: MoncarButtonVariant.primary,
                size: MoncarButtonSize.sm,
                onPressed: onCompare,
              ),
            ],
          ),
        ),
        Positioned(
          top: -8,
          right: -8,
          child: Material(
            color: MoncarColors.surface,
            shape: const CircleBorder(),
            elevation: 2,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onClear,
              child: SizedBox(
                width: 28,
                height: 28,
                child: Icon(Icons.close, size: 16, color: MoncarColors.brand),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Carte de résultat de recherche.
class TripCard extends StatelessWidget {
  const TripCard({
    super.key,
    required this.trip,
    required this.onSelect,
    required this.onCompare,
    required this.compared,
  });

  final Trip trip;
  final VoidCallback onSelect;
  final VoidCallback onCompare;
  final bool compared;

  MoncarBadgeTone _tagTone(String tag) => switch (tag) {
    'Promo' => MoncarBadgeTone.accent,
    'Premium' || 'VIP' => MoncarBadgeTone.brand,
    _ => MoncarBadgeTone.neutral,
  };

  @override
  Widget build(BuildContext context) {
    return MoncarCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          InkWell(
            onTap: onSelect,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      CompanyLogo(
                        name: trip.companyName,
                        color: trip.companyColor,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              trip.companyName,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: MoncarColors.ink,
                              ),
                            ),
                            Text(
                              trip.vehicleModel,
                              style: TextStyle(
                                fontSize: 10,
                                color: MoncarColors.inkFaint,
                              ),
                            ),
                          ],
                        ),
                      ),
                      for (final tag in trip.tags.take(2))
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: MoncarBadge(
                            label: tag,
                            tone: _tagTone(tag),
                            size: MoncarBadgeSize.sm,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _TimeCol(
                        time: trip.departureTime,
                        city: trip.originCityName,
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Column(
                            children: [
                              Text(
                                formatDurationShort(trip.durationMin),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: MoncarColors.inkFaint,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  _Dot(color: MoncarColors.brand),
                                  Expanded(child: DashedLine()),
                                  Icon(
                                    Icons.directions_bus,
                                    size: 14,
                                    color: MoncarColors.accent,
                                  ),
                                  Expanded(child: DashedLine()),
                                  _Dot(color: MoncarColors.accent),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                trip.direct ? 'Direct' : 'Avec arrêts',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: MoncarColors.inkFaint,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      _TimeCol(
                        time: trip.arrivalTime,
                        city: trip.destinationCityName,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Divider(height: 1, color: MoncarColors.hairline),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      for (final a in trip.amenities.take(4))
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Icon(
                            amenityIcon(a),
                            size: 14,
                            color: MoncarColors.inkMut,
                          ),
                        ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${trip.seatsAvailable} places',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: MoncarColors.inkMut,
                          ),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'à partir de',
                            style: TextStyle(
                              fontSize: 10,
                              color: MoncarColors.inkFaint,
                            ),
                          ),
                          Text(
                            formatXOF(trip.priceFromXOF),
                            style: TextStyle(
                              fontSize: 18,
                              height: 1,
                              fontWeight: FontWeight.w700,
                              color: MoncarColors.accent,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          InkWell(
            onTap: onCompare,
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(20),
            ),
            child: Container(
              height: 36,
              decoration: BoxDecoration(
                color: compared ? MoncarColors.brandSoft : MoncarColors.surface,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(20),
                ),
                border: Border(
                  top: BorderSide(
                    color: compared
                        ? MoncarColors.brand
                        : MoncarColors.hairline,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    compared ? Icons.close : Icons.tune,
                    size: 14,
                    color: compared ? MoncarColors.brand : MoncarColors.inkMut,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    compared ? 'Retirer' : 'Comparer',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: compared
                          ? MoncarColors.brand
                          : MoncarColors.inkMut,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeCol extends StatelessWidget {
  const _TimeCol({required this.time, required this.city});

  final String time;
  final String city;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          time,
          style: TextStyle(
            fontSize: 20,
            height: 1,
            fontWeight: FontWeight.w700,
            color: MoncarColors.ink,
          ),
        ),
        const SizedBox(height: 4),
        Text(city, style: TextStyle(fontSize: 11, color: MoncarColors.inkMut)),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
