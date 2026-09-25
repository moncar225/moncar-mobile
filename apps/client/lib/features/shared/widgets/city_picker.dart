import 'package:flutter/material.dart';

import 'package:core_ui/core_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/providers.dart';
import '../domain/models.dart';
import '../utils/format.dart';

/// Sélecteur de ville (portage du `CityPicker` web) : bottom sheet
/// avec recherche, villes populaires et exclusion de la ville opposée.
class CityPicker {
  CityPicker._();

  /// Ouvre la feuille et renvoie la ville choisie (null si fermée).
  static Future<City?> show(
    BuildContext context, {
    String title = 'Départ',
    String? selectedName,
    String? excludeCity,
  }) {
    return showModalBottomSheet<City>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: MoncarColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _CityPickerSheet(
        title: title,
        selectedName: selectedName,
        excludeCity: excludeCity,
      ),
    );
  }
}

class _CityPickerSheet extends StatefulWidget {
  const _CityPickerSheet({
    required this.title,
    this.selectedName,
    this.excludeCity,
  });

  final String title;
  final String? selectedName;
  final String? excludeCity;

  @override
  State<_CityPickerSheet> createState() => _CityPickerSheetState();
}

class _CityPickerSheetState extends State<_CityPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return ConsumerBuilderWidget(
      builder: (context, cities) {
        final popular = cities.where((c) => c.popular).toList();
        final q = normalizeSearch(_query.trim());
        final filtered = q.isEmpty
            ? cities
            : cities
                  .where(
                    (c) =>
                        normalizeSearch(c.name).contains(q) ||
                        normalizeSearch(c.region).contains(q),
                  )
                  .toList();

        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.85,
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title == 'Destination'
                                ? 'Choisir la destination'
                                : 'Choisir la ville de départ',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: MoncarColors.ink,
                            ),
                          ),
                          Text(
                            "${cities.length} villes disponibles en Côte d'Ivoire",
                            style: TextStyle(
                              fontSize: 12,
                              color: MoncarColors.inkMut,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _CloseButton(onTap: () => Navigator.of(context).pop()),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: TextField(
                  autofocus: true,
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: 'Rechercher une ville…',
                    prefixIcon: Icon(
                      Icons.search,
                      size: 20,
                      color: MoncarColors.inkFaint,
                    ),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close, size: 16),
                            onPressed: () => setState(() => _query = ''),
                          ),
                  ),
                ),
              ),
              if (popular.isNotEmpty && _query.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 20, bottom: 12),
                  child: SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: popular.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, i) {
                        final c = popular[i];
                        final disabled = widget.excludeCity == c.name;
                        return Opacity(
                          opacity: disabled ? 0.4 : 1,
                          child: MoncarChip(
                            label: c.name,
                            icon: Icons.star,
                            onTap: disabled ? null : () => _select(c),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              Flexible(
                child: filtered.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Column(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: MoncarColors.muted,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.search,
                                size: 24,
                                color: MoncarColors.inkFaint,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Aucune ville',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: MoncarColors.ink,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Essayez un autre nom de ville ou région.',
                              style: TextStyle(
                                fontSize: 12,
                                color: MoncarColors.inkMut,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                        itemCount: filtered.length,
                        itemBuilder: (context, i) {
                          final city = filtered[i];
                          final selected = city.name == widget.selectedName;
                          final excluded = city.name == widget.excludeCity;
                          return ListTile(
                            enabled: !excluded,
                            onTap: excluded ? null : () => _select(city),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            tileColor: selected
                                ? MoncarColors.accentSoft
                                : null,
                            leading: CircleAvatar(
                              radius: 18,
                              backgroundColor: selected
                                  ? MoncarColors.accent
                                  : excluded
                                  ? MoncarColors.muted
                                  : MoncarColors.brandSoft,
                              child: Icon(
                                Icons.location_on_outlined,
                                size: 18,
                                color: selected
                                    ? Colors.white
                                    : excluded
                                    ? MoncarColors.inkFaint
                                    : MoncarColors.brand,
                              ),
                            ),
                            title: Text(
                              city.name,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: selected
                                    ? MoncarColors.accentInk
                                    : MoncarColors.ink,
                              ),
                            ),
                            subtitle: Text(
                              excluded
                                  ? (widget.title == 'Destination'
                                        ? 'Ville de départ'
                                        : 'Ville de destination')
                                  : "${city.region} · Côte d'Ivoire",
                              style: TextStyle(
                                fontSize: 11,
                                color: MoncarColors.inkMut,
                              ),
                            ),
                            trailing: selected
                                ? CircleAvatar(
                                    radius: 14,
                                    backgroundColor: MoncarColors.accent,
                                    child: Icon(
                                      Icons.check,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                  )
                                : Icon(
                                    Icons.chevron_right,
                                    size: 18,
                                    color: MoncarColors.inkFaint,
                                  ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _select(City city) => Navigator.of(context).pop(city);
}

/// Petit pont Riverpod → StatefulWidget pour lire le store mock.
class ConsumerBuilderWidget extends ConsumerWidget {
  const ConsumerBuilderWidget({super.key, required this.builder});

  final Widget Function(BuildContext, List<City>) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(mockStoreChangesProvider);
    final store = ref.read(mockStoreProvider);
    return builder(context, store.cities);
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: MoncarColors.brandSoft.withValues(alpha: 0.6),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(Icons.close, size: 16, color: MoncarColors.brand),
        ),
      ),
    );
  }
}
