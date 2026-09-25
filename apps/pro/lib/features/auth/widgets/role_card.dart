import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

import '../../../core/domain/models.dart';
import '../../../core/ui/role_style.dart';

/// Carte de poste (inscription, choix du poste).
class RoleCard extends StatelessWidget {
  const RoleCard({
    super.key,
    required this.role,
    required this.selected,
    required this.onTap,
  });

  final ProRole role;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = role.accent;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: selected ? c.withValues(alpha: 0.08) : MoncarColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: selected ? c : MoncarColors.hairline,
          width: selected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(
              0xFF002060,
            ).withValues(alpha: selected ? 0.12 : 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: role.gradient),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(role.icon, color: Colors.white, size: 30),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              role.label,
                              style: TextStyle(
                                fontSize: 16.5,
                                fontWeight: FontWeight.w800,
                                color: MoncarColors.ink,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          MoncarBadge(
                            label: role.code,
                            size: MoncarBadgeSize.sm,
                            backgroundColor: c.withValues(alpha: 0.12),
                            textColor: c,
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        role.tagline,
                        style: TextStyle(
                          fontSize: 13,
                          color: MoncarColors.inkMut,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final f in role.features)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: MoncarColors.muted,
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Text(
                                f,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: MoncarColors.inkMut,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedScale(
                  scale: selected ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
