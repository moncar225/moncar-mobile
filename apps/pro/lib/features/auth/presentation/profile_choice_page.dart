import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/application/session_controller.dart';
import '../../../core/domain/models.dart';
import '../../../core/ui/pro_kit.dart';
import '../../../core/ui/role_style.dart';
import '../widgets/role_card.dart';

/// Choix du profil à l'ouverture, piloté par les permissions renvoyées
/// par l'API (AUTH-002) — seuls les profils autorisés sont proposés.
class ProfileChoicePage extends ConsumerStatefulWidget {
  const ProfileChoicePage({super.key});

  @override
  ConsumerState<ProfileChoicePage> createState() => _ProfileChoicePageState();
}

class _ProfileChoicePageState extends ConsumerState<ProfileChoicePage> {
  ProRole? _selected;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(sessionProvider).user;
    if (user == null) return const SizedBox.shrink();
    return Scaffold(
      backgroundColor: MoncarColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                children: [
                  Row(
                    children: [
                      const ProLogo(size: 40),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Bonjour ${user.firstName}',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: MoncarColors.ink,
                              ),
                            ),
                            Text(
                              '${user.company} · ${user.station}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: MoncarColors.inkMut,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 26),
                  Text(
                    'Quel est votre poste aujourd’hui ?',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: MoncarColors.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Profils ouverts sur votre compte par votre compagnie.',
                    style: TextStyle(
                      color: MoncarColors.inkMut,
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  for (final r in user.roles) ...[
                    RoleCard(
                      role: r,
                      selected: _selected == r,
                      onTap: () {
                        haptic(HapticKind.tap);
                        setState(() => _selected = r);
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
            StickyActionBar(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  BigActionButton(
                    label: _selected == null
                        ? 'Sélectionnez un poste'
                        : 'Continuer comme ${_selected!.label}',
                    icon: Icons.arrow_forward_rounded,
                    color: _selected?.accent ?? MoncarColors.brand,
                    onPressed: _selected == null
                        ? null
                        : () => ref
                              .read(sessionProvider.notifier)
                              .selectRole(_selected!),
                  ),
                  TextButton(
                    onPressed: () =>
                        ref.read(sessionProvider.notifier).signOut(),
                    child: Text(
                      'Ce n’est pas mon compte',
                      style: TextStyle(color: MoncarColors.inkMut),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
