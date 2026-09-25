import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/foundation.dart';
import '../widgets/colis_widgets.dart';

enum _Tab { all, ongoing, delivered, disputes }

/// Onglet Colis : envoi / suivi par numéro, et liste filtrable des
/// colis de l'utilisateur.
class ColisPage extends ConsumerStatefulWidget {
  const ColisPage({super.key});

  @override
  ConsumerState<ColisPage> createState() => _ColisPageState();
}

class _ColisPageState extends ConsumerState<ColisPage> {
  _Tab _tab = _Tab.all;
  bool _showSearch = false;
  final _track = TextEditingController();

  @override
  void dispose() {
    _track.dispose();
    super.dispose();
  }

  void _onTrack() {
    final v = _track.text.trim();
    if (v.isEmpty) {
      showMoncarToast(context, 'Entrez un numéro de suivi.', error: true);
      return;
    }
    context.push('/colis/${Uri.encodeComponent(v)}');
  }

  List<Parcel> _filter(List<Parcel> parcels) => switch (_tab) {
    _Tab.ongoing =>
      parcels
          .where(
            (p) => const [
              ParcelStatus.depose,
              ParcelStatus.enTransit,
              ParcelStatus.arriveGare,
              ParcelStatus.attenteRetrait,
            ].contains(p.status),
          )
          .toList(),
    _Tab.delivered =>
      parcels.where((p) => p.status == ParcelStatus.livre).toList(),
    _Tab.disputes =>
      parcels
          .where(
            (p) =>
                p.status == ParcelStatus.litige ||
                p.status == ParcelStatus.annule,
          )
          .toList(),
    _Tab.all => parcels,
  };

  @override
  Widget build(BuildContext context) {
    ref.watch(mockStoreChangesProvider);
    final filtered = _filter(ref.read(mockStoreProvider).parcels);

    return ColoredBox(
      color: MoncarColors.background,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          BrandTabHeader(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MoncarBadge(
                  label: 'Service Colis',
                  icon: Icons.inventory_2_outlined,
                  size: MoncarBadgeSize.sm,
                  backgroundColor: Colors.white.withValues(alpha: 0.15),
                  textColor: Colors.white,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Envoyer un colis',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Expédiez en toute sécurité — paiement Mobile Money, suivi en temps réel.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _HeroAction(
                        icon: Icons.send_outlined,
                        title: 'Envoyer',
                        subtitle: 'Nouveau colis',
                        primary: true,
                        onTap: () => context.push('/colis/new'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _HeroAction(
                        icon: Icons.search,
                        title: 'Suivre',
                        subtitle: 'Numéro de suivi',
                        onTap: () => setState(() => _showSearch = !_showSearch),
                      ),
                    ),
                  ],
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                  child: _showSearch
                      ? Container(
                          margin: const EdgeInsets.only(top: 12),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: MoncarColors.surface,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _track,
                                  autofocus: true,
                                  textCapitalization:
                                      TextCapitalization.characters,
                                  onSubmitted: (_) => _onTrack(),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontFamily: 'monospace',
                                    color: MoncarColors.ink,
                                  ),
                                  decoration: const InputDecoration(
                                    hintText: 'MON-COL-XXXX',
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                  ),
                                ),
                              ),
                              MoncarButton(
                                label: 'Suivre',
                                variant: MoncarButtonVariant.primary,
                                size: MoncarButtonSize.md,
                                onPressed: _onTrack,
                              ),
                            ],
                          ),
                        )
                      : const SizedBox(width: double.infinity),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final (t, label) in const [
                  (_Tab.all, 'Tous'),
                  (_Tab.ongoing, 'En cours'),
                  (_Tab.delivered, 'Livrés'),
                  (_Tab.disputes, 'Litiges'),
                ]) ...[
                  MoncarChip(
                    label: label,
                    active: _tab == t,
                    onTap: () => setState(() => _tab = t),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: filtered.isEmpty
                ? MoncarEmptyState(
                    icon: Icons.inventory_2_outlined,
                    title: _tab == _Tab.all ? 'Aucun colis' : 'Rien ici',
                    message: switch (_tab) {
                      _Tab.all =>
                        "Vous n'avez encore envoyé aucun colis. Créez votre premier envoi en quelques secondes.",
                      _Tab.disputes => 'Aucun colis en litige ou annulé.',
                      _ => 'Aucun colis dans cette catégorie.',
                    },
                    actionLabel: 'Envoyer un colis',
                    onAction: () => context.push('/colis/new'),
                  )
                : Column(
                    children: [
                      for (final p in filtered) ...[
                        ParcelCard(
                          parcel: p,
                          onTap: () => context.push('/colis/${p.id}'),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _HeroAction extends StatelessWidget {
  const _HeroAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.primary = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: primary
            ? accentGradientDecoration(radius: BorderRadius.circular(14))
            : BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
              ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: Colors.white),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Carte de colis (liste Colis et historique).
class ParcelCard extends StatelessWidget {
  const ParcelCard({super.key, required this.parcel, required this.onTap});

  final Parcel parcel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = parcel;
    return MoncarCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.trackingNumber,
                      style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        color: MoncarColors.inkMut,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.place_outlined,
                          size: 14,
                          color: MoncarColors.brand,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            p.originCity,
                            overflow: TextOverflow.ellipsis,
                            style: _routeStyle,
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(
                            Icons.arrow_forward,
                            size: 12,
                            color: MoncarColors.accent,
                          ),
                        ),
                        Flexible(
                          child: Text(
                            p.destinationCity,
                            overflow: TextOverflow.ellipsis,
                            style: _routeStyle,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              MoncarBadge(
                label: parcelStatusLabel(p.status),
                tone: parcelStatusTone(p.status),
                size: MoncarBadgeSize.sm,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.person_outline, size: 12, color: MoncarColors.inkMut),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  p.recipientName,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: MoncarColors.inkMut),
                ),
              ),
              const SizedBox(width: 12),
              Icon(Icons.scale_outlined, size: 12, color: MoncarColors.inkMut),
              const SizedBox(width: 4),
              Text(
                '${_kg(p.weightKg)} kg',
                style: TextStyle(fontSize: 12, color: MoncarColors.inkMut),
              ),
              const Spacer(),
              Text(
                formatXOF(p.amountXOF),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: MoncarColors.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const OverlineText('Progression'),
              const Spacer(),
              OverlineText('${parcelProgressPct(p)}%'),
            ],
          ),
          const SizedBox(height: 4),
          ParcelProgressBar(parcel: p),
        ],
      ),
    );
  }

  static String _kg(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  static final _routeStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: MoncarColors.ink,
  );
}
