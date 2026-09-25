import 'package:flutter/material.dart';

import 'package:core_ui/core_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/providers.dart';
import 'moncar_logo.dart';
import 'ui_kit.dart';

enum MoncarTopBarVariant { defaultBar, transparent, brand }

/// Barre supérieure MON CAR (portage du `TopBar` web).
///
/// Variante [brand] : fond dégradé navy, textes blancs. Variante
/// [defaultBar] : fond blanc translucide, bord bas hairline.
class TopBar extends ConsumerWidget implements PreferredSizeWidget {
  const TopBar({
    super.key,
    this.title,
    this.subtitle,
    this.showBack = false,
    this.onBack,
    this.showBell = true,
    this.showAvatar = false,
    this.showLogo = false,
    this.rightSlot,
    this.variant = MoncarTopBarVariant.defaultBar,
  });

  final String? title;
  final String? subtitle;
  final bool showBack;
  final VoidCallback? onBack;
  final bool showBell;
  final bool showAvatar;
  final bool showLogo;
  final Widget? rightSlot;
  final MoncarTopBarVariant variant;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isBrand = variant == MoncarTopBarVariant.brand;
    final fg = isBrand ? Colors.white : MoncarColors.brand;
    final unread = ref
        .watch(mockStoreChangesProvider)
        .let(
          (_) => ref
              .read(mockStoreProvider)
              .notifications
              .where((n) => !n.read)
              .length,
        );

    return Container(
      decoration: BoxDecoration(
        gradient: isBrand
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: MoncarColors.brandGradient,
              )
            : null,
        color: isBrand ? null : MoncarColors.surface,
        border: isBrand
            ? null
            : Border(bottom: BorderSide(color: MoncarColors.hairline)),
      ),
      padding: EdgeInsets.only(
        top: MediaQuery.paddingOf(context).top,
        left: 16,
        right: 16,
        bottom: 10,
      ),
      child: Row(
        children: [
          if (showBack)
            _IconCircleButton(
              icon: Icons.chevron_left,
              tooltip: 'Retour',
              foreground: fg,
              onTap: onBack ?? () => context.mcBack(),
            ),
          if (showLogo) ...[
            const MonCarLogo(size: 34),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                MonCarWordmark(fontSize: 16),
                Text(
                  'Voyagez en toute confiance',
                  style: TextStyle(
                    fontSize: 10,
                    color: isBrand
                        ? Colors.white.withValues(alpha: 0.8)
                        : MoncarColors.inkMut,
                  ),
                ),
              ],
            ),
          ],
          if (title != null)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isBrand ? Colors.white : MoncarColors.ink,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: isBrand
                            ? Colors.white.withValues(alpha: 0.8)
                            : MoncarColors.inkMut,
                      ),
                    ),
                ],
              ),
            )
          else if (!showLogo)
            const Spacer(),
          ?rightSlot,
          if (showAvatar && !showBell)
            const Padding(
              padding: EdgeInsets.only(left: 8),
              child: _AvatarSlot(),
            ),
          if (showBell)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: _IconCircleButton(
                icon: Icons.notifications_none,
                tooltip: 'Notifications',
                foreground: fg,
                badge: unread > 0 ? '$unread' : null,
                onTap: () => context.push('/notifications'),
              ),
            ),
        ],
      ),
    );
  }
}

class _AvatarSlot extends ConsumerWidget {
  const _AvatarSlot();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final photo = ref.watch(profilePhotoProvider);
    return GestureDetector(
      onTap: () => context.push('/profile'),
      child: MoncarAvatar(
        initials: user?.initials ?? 'MC',
        image: photo == null ? null : MemoryImage(photo),
      ),
    );
  }
}

class _IconCircleButton extends StatelessWidget {
  const _IconCircleButton({
    required this.icon,
    required this.onTap,
    required this.foreground,
    this.badge,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color foreground;
  final String? badge;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, size: 22, color: foreground),
        ),
      ),
    );
    final withBadge = badge == null
        ? button
        : Stack(
            clipBehavior: Clip.none,
            children: [
              button,
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  constraints: const BoxConstraints(minWidth: 16),
                  height: 16,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: MoncarColors.danger,
                    borderRadius: BorderRadius.all(Radius.circular(999)),
                  ),
                  child: Text(
                    badge!,
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          );
    if (tooltip == null) return withBadge;
    return Tooltip(message: tooltip!, child: withBadge);
  }
}

extension _Let<T> on T {
  R let<R>(R Function(T) f) => f(this);
}
