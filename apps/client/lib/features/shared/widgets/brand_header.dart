import 'package:flutter/material.dart';

import 'package:core_ui/core_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/providers.dart';
import 'moncar_logo.dart';
import 'ui_kit.dart';

/// En-tête dégradé navy des onglets principaux : logo + cloche
/// (compteur de notifications non lues), puis contenu libre.
class BrandTabHeader extends ConsumerWidget {
  const BrandTabHeader({
    super.key,
    required this.child,
    this.bottomPadding = 24,
  });

  final Widget child;
  final double bottomPadding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(mockStoreChangesProvider);
    final unread = ref
        .read(mockStoreProvider)
        .notifications
        .where((n) => !n.read)
        .length;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: brandGradientDecoration(
        radius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -48,
            right: -48,
            child: _Glow(
              size: 176,
              color: MoncarColors.accent.withValues(alpha: 0.2),
            ),
          ),
          Positioned(
            bottom: -64,
            left: -40,
            child: _Glow(
              size: 192,
              color: Colors.white.withValues(alpha: 0.05),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              MediaQuery.paddingOf(context).top + 12,
              16,
              bottomPadding,
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
                    IconButton(
                      tooltip: 'Notifications',
                      onPressed: () => context.push('/notifications'),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.15),
                      ),
                      icon: Badge(
                        isLabelVisible: unread > 0,
                        label: Text('$unread'),
                        backgroundColor: MoncarColors.accent,
                        child: const Icon(
                          Icons.notifications_none,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                child,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.size, required this.color});

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
