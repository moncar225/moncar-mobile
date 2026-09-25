import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/foundation.dart';

/// Accueil : en-tête de marque, recherche de trajet, promotions,
/// accès rapides, derniers trajets, fidélité et assistance.
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  String _origin = 'Abidjan';
  String _destination = 'Yamoussoukro';
  String _date = dateOffset(1);
  int _passengers = 1;

  void _swap() => setState(() {
    final o = _origin;
    _origin = _destination;
    _destination = o;
  });

  void _search() {
    final params = Uri(
      queryParameters: {
        'origin': _origin,
        'destination': _destination,
        'date': _date,
        'passengers': '$_passengers',
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
    setState(() => _date = picked.toIso8601String().substring(0, 10));
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Bonjour';
    if (h < 18) return 'Bon après-midi';
    return 'Bonsoir';
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(mockStoreChangesProvider);
    final store = ref.read(mockStoreProvider);
    final user = ref.watch(authProvider).user;
    final promos = [
      ...store.promotions.where((p) => p.featured),
      ...store.promotions.where((p) => !p.featured),
    ].take(5).toList();
    final upcoming = store.bookings
        .where(
          (b) =>
              b.status == BookingStatus.paye ||
              b.status == BookingStatus.enAttente,
        )
        .take(3)
        .toList();
    final unread = store.notifications.where((n) => !n.read).length;

    return ColoredBox(
      color: MoncarColors.background,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          _Hero(
            greeting: _greeting,
            name: user != null
                ? '${user.firstName} ${user.lastName}'
                : 'Voyageur',
            unread: unread,
          ),
          Transform.translate(
            offset: const Offset(0, -16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _SearchCard(
                origin: _origin,
                destination: _destination,
                date: _date,
                passengers: _passengers,
                onPickOrigin: () => _pickCity(origin: true),
                onPickDestination: () => _pickCity(origin: false),
                onSwap: _swap,
                onPickDate: _pickDate,
                onPassengers: (n) => setState(() => _passengers = n),
                onSearch: _search,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: MoncarSectionHeader(
              title: 'Promotions du moment',
              action: 'Voir tout',
              onAction: () => context.push('/promotions'),
            ),
          ),
          if (promos.isNotEmpty) PromoCarousel(promos: promos),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const MoncarSectionHeader(title: 'Accès rapides'),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _QuickAction(
                      icon: Icons.confirmation_number_outlined,
                      label: 'Mes billets',
                      badge: '1',
                      onTap: () => context.push('/history?tab=tickets'),
                    ),
                    _QuickAction(
                      icon: Icons.inventory_2_outlined,
                      label: 'Mes colis',
                      badge: '1',
                      onTap: () => context.push('/history?tab=parcels'),
                    ),
                    _QuickAction(
                      icon: Icons.emoji_events_outlined,
                      label: 'Fidélité',
                      onTap: () => context.push('/loyalty'),
                    ),
                    _QuickAction(
                      icon: Icons.card_giftcard,
                      label: 'Promos',
                      badge: '2',
                      onTap: () => context.push('/promotions'),
                    ),
                    _QuickAction(
                      icon: Icons.history,
                      label: 'Historique',
                      onTap: () => context.push('/history'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MoncarSectionHeader(
                  title: 'Mes derniers trajets',
                  action: 'Historique',
                  onAction: () => context.push('/history'),
                ),
                if (upcoming.isEmpty)
                  MoncarCard(
                    padding: const EdgeInsets.symmetric(
                      vertical: 24,
                      horizontal: 16,
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Aucun trajet à venir.',
                          style: TextStyle(
                            fontSize: 13,
                            color: MoncarColors.inkMut,
                          ),
                        ),
                        const SizedBox(height: 8),
                        MoncarButton(
                          label: 'Réserver mon premier trajet',
                          variant: MoncarButtonVariant.soft,
                          size: MoncarButtonSize.sm,
                          onPressed: () => context.go('/voyager'),
                        ),
                      ],
                    ),
                  )
                else
                  for (final b in upcoming) ...[
                    _BookingTile(booking: b),
                    const SizedBox(height: 8),
                  ],
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => context.push('/loyalty'),
                  child: _LoyaltyCard(loyalty: store.loyalty),
                ),
                const SizedBox(height: 20),
                const MoncarSectionHeader(title: "Besoin d'aide ?"),
                Row(
                  children: [
                    Expanded(
                      child: _SupportCard(
                        icon: Icons.headset_mic_outlined,
                        color: MoncarColors.brand,
                        background: MoncarColors.brandSoft,
                        title: 'Support',
                        subtitle: 'FAQ & contact',
                        onTap: () => context.push('/help'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _SupportCard(
                        icon: Icons.bolt,
                        color: MoncarColors.danger,
                        background: MoncarColors.dangerSoft,
                        title: 'Urgence',
                        subtitle: 'Assistance 24/7',
                        onTap: () => context.push('/help'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.greeting,
    required this.name,
    required this.unread,
  });

  final String greeting;
  final String name;
  final int unread;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: brandGradientDecoration(
        radius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            top: -40,
            right: -40,
            child: _GlowCircle(
              size: 160,
              color: MoncarColors.accent.withValues(alpha: 0.2),
            ),
          ),
          Positioned(
            bottom: -64,
            left: -40,
            child: _GlowCircle(
              size: 176,
              color: Colors.white.withValues(alpha: 0.05),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              MediaQuery.paddingOf(context).top + 12,
              16,
              40,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const MonCarLogo(size: 38),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'MON CAR',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Voyagez en toute confiance',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Semantics(
                      button: true,
                      label: 'Notifications',
                      child: InkWell(
                        onTap: () => context.push('/notifications'),
                        customBorder: const CircleBorder(),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.15),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              const Icon(
                                Icons.notifications_none,
                                size: 20,
                                color: Colors.white,
                              ),
                              if (unread > 0)
                                Positioned(
                                  top: 6,
                                  right: 6,
                                  child: _CountBadge(label: '$unread'),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  '$greeting,',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
                Text(
                  '$name 👋',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.place_outlined,
                      size: 12,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "Abidjan, Côte d'Ivoire",
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowCircle extends StatelessWidget {
  const _GlowCircle({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [BoxShadow(color: color, blurRadius: 40, spreadRadius: 8)],
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 16),
      height: 16,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: MoncarColors.accent,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _SearchCard extends StatelessWidget {
  const _SearchCard({
    required this.origin,
    required this.destination,
    required this.date,
    required this.passengers,
    required this.onPickOrigin,
    required this.onPickDestination,
    required this.onSwap,
    required this.onPickDate,
    required this.onPassengers,
    required this.onSearch,
  });

  final String origin;
  final String destination;
  final String date;
  final int passengers;
  final VoidCallback onPickOrigin;
  final VoidCallback onPickDestination;
  final VoidCallback onSwap;
  final VoidCallback onPickDate;
  final ValueChanged<int> onPassengers;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return MoncarCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 16, color: MoncarColors.accent),
              SizedBox(width: 8),
              Text(
                'Où allez-vous ?',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: MoncarColors.ink,
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
                  _Field(
                    icon: Icons.place_outlined,
                    iconColor: MoncarColors.brand,
                    label: 'Départ',
                    value: origin,
                    onTap: onPickOrigin,
                  ),
                  const SizedBox(height: 8),
                  _Field(
                    icon: Icons.place_outlined,
                    iconColor: MoncarColors.accent,
                    label: 'Destination',
                    value: destination,
                    onTap: onPickDestination,
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Semantics(
                  button: true,
                  label: 'Inverser',
                  child: Material(
                    color: MoncarColors.surface,
                    shape: CircleBorder(
                      side: BorderSide(color: MoncarColors.accent, width: 2),
                    ),
                    elevation: 1,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: onSwap,
                      child: SizedBox(
                        width: 36,
                        height: 36,
                        child: Icon(
                          Icons.swap_vert,
                          size: 18,
                          color: MoncarColors.accent,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _Field(
                  icon: Icons.calendar_today_outlined,
                  iconColor: MoncarColors.brand,
                  label: 'Date',
                  value: formatDateNumeric(date),
                  compact: true,
                  onTap: onPickDate,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: PopupMenuButton<int>(
                  initialValue: passengers,
                  onSelected: onPassengers,
                  itemBuilder: (_) => [
                    for (var n = 1; n <= maxPassengers; n++)
                      PopupMenuItem(
                        value: n,
                        child: Text('$n ${n == 1 ? 'Passager' : 'Passagers'}'),
                      ),
                  ],
                  child: _Field(
                    icon: Icons.person_outline,
                    iconColor: MoncarColors.brand,
                    label: 'Passagers',
                    value:
                        '$passengers ${passengers == 1 ? 'Passager' : 'Passagers'}',
                    compact: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          MoncarButton(
            label: 'Rechercher un voyage',
            icon: Icons.search,
            variant: MoncarButtonVariant.primary,
            size: MoncarButtonSize.xl,
            expand: true,
            onPressed: onSearch,
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.onTap,
    this.compact = false,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MoncarColors.brandSoft.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MoncarColors.hairline),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: iconColor),
          SizedBox(width: compact ? 10 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: MoncarColors.inkMut,
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: compact ? 13 : 15,
                    fontWeight: FontWeight.w600,
                    color: MoncarColors.ink,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: content,
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: MoncarColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: MoncarColors.hairline),
                      boxShadow: [
                        BoxShadow(
                          color: MoncarColors.brand.withValues(alpha: 0.06),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(icon, size: 20, color: MoncarColors.brand),
                  ),
                  if (badge != null)
                    Positioned(
                      top: -4,
                      right: -4,
                      child: _CountBadge(label: badge!),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  height: 1.2,
                  fontWeight: FontWeight.w500,
                  color: MoncarColors.inkMut,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookingTile extends StatelessWidget {
  const _BookingTile({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final parts = b.tripSummary.split(' → ');
    final paid = b.status == BookingStatus.paye;
    return MoncarCard(
      padding: const EdgeInsets.all(14),
      onTap: () => context.push('/voyager/ticket/${b.ticketId ?? b.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              MoncarBadge(
                label: paid ? 'Confirmé' : 'En attente',
                tone: paid ? MoncarBadgeTone.success : MoncarBadgeTone.warn,
              ),
              const Spacer(),
              Text(
                b.reference,
                style: TextStyle(fontSize: 11, color: MoncarColors.inkFaint),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(parts.first, style: _routeStyle),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6),
                          child: Icon(
                            Icons.arrow_forward,
                            size: 12,
                            color: MoncarColors.accent,
                          ),
                        ),
                        Flexible(
                          child: Text(
                            parts.length > 1 ? parts[1] : '',
                            overflow: TextOverflow.ellipsis,
                            style: _routeStyle,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        formatDateWithDay(b.date),
                        b.departureTime,
                        if (b.seats.isNotEmpty) 'Siège ${b.seats.join(', ')}',
                      ].join(' • '),
                      style: TextStyle(
                        fontSize: 11,
                        color: MoncarColors.inkMut,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 16, color: MoncarColors.inkFaint),
            ],
          ),
        ],
      ),
    );
  }

  static final _routeStyle = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: MoncarColors.ink,
  );
}

class _LoyaltyCard extends StatelessWidget {
  const _LoyaltyCard({required this.loyalty});

  final Loyalty loyalty;

  @override
  Widget build(BuildContext context) {
    final colors = switch (loyalty.tier) {
      LoyaltyTier.argent when MoncarColors.isDark => [
        MoncarColors.muted,
        MoncarColors.surface,
      ],
      LoyaltyTier.or when MoncarColors.isDark => [
        MoncarColors.warnSoft,
        MoncarColors.surface,
      ],
      LoyaltyTier.argent => const [Color(0xFFE5E7EB), Color(0xFFF3F4F6)],
      LoyaltyTier.or => const [Color(0xFFFEF3C7), Color(0xFFFFFBEB)],
      LoyaltyTier.vip => [MoncarColors.accentSoft, MoncarColors.accentSoft],
      LoyaltyTier.standard => [MoncarColors.brandSoft, MoncarColors.brandSoft],
    };
    final next = loyalty.nextTier?.label;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MoncarColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.emoji_events_outlined,
                size: 20,
                color: MoncarColors.accent,
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const OverlineText('Fidélité'),
                  Text(
                    'Membre ${loyalty.tier.label}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: MoncarColors.ink,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Icon(Icons.chevron_right, size: 16, color: MoncarColors.inkFaint),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const OverlineText('Points'),
                  Text(
                    formatNumber(loyalty.points),
                    style: TextStyle(
                      fontSize: 24,
                      height: 1,
                      fontWeight: FontWeight.w800,
                      color: MoncarColors.brand,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const OverlineText('Prochain palier'),
                  Text(
                    next ?? '—',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: MoncarColors.ink,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Container(
              height: 8,
              color: Colors.white.withValues(alpha: 0.7),
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: (loyalty.progressPct / 100).clamp(0, 1).toDouble(),
                child: Container(decoration: accentGradientDecoration()),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Plus que ${loyalty.pointsToNextTier} pts pour passer ${next ?? ''}',
            style: TextStyle(fontSize: 10, color: MoncarColors.inkMut),
          ),
        ],
      ),
    );
  }
}

class _SupportCard extends StatelessWidget {
  const _SupportCard({
    required this.icon,
    required this.color,
    required this.background,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final Color background;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MoncarCard(
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: background,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: MoncarColors.ink,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 11, color: MoncarColors.inkMut),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
