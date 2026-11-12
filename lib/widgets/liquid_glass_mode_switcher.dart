import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/settings_service.dart';

/// Next-Generation Liquid Glass Segmented Mode Switcher.
/// Floating translucent pill with specular highlights, frosted blur, and smooth animated sliding pill.
class LiquidGlassModeSwitcher extends StatelessWidget {
  final AppMode selectedMode;
  final ValueChanged<AppMode>? onModeChanged;
  final bool isBusy;

  const LiquidGlassModeSwitcher({
    super.key,
    required this.selectedMode,
    this.onModeChanged,
    this.isBusy = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isGeny = selectedMode == AppMode.geny;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: isGeny
                    ? const Color(0xFF00E5FF).withValues(alpha: 0.15)
                    : (isDark
                        ? Colors.black.withValues(alpha: 0.35)
                        : Colors.black.withValues(alpha: 0.06)),
                blurRadius: 18,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isGeny
                      ? const Color(0x35020B14)
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.white.withValues(alpha: 0.75)),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: isGeny
                        ? const Color(0xFF00E5FF).withValues(alpha: 0.35)
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.14)
                            : Colors.black.withValues(alpha: 0.08)),
                    width: 1.0,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _modeItem(
                        context: context,
                        mode: AppMode.agent,
                        label: 'Agent',
                        icon: Icons.smart_toy_rounded,
                        activeColor: const Color(0xFF818CF8),
                        glowColor: const Color(0xFF6366F1),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: _modeItem(
                        context: context,
                        mode: AppMode.chat,
                        label: 'Chat',
                        icon: Icons.chat_bubble_rounded,
                        activeColor: const Color(0xFF38BDF8),
                        glowColor: const Color(0xFF0EA5E9),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: _modeItem(
                        context: context,
                        mode: AppMode.geny,
                        label: 'GENY',
                        icon: Icons.graphic_eq_rounded,
                        activeColor: const Color(0xFF00E5FF),
                        glowColor: const Color(0xFF00E5FF),
                        isMonospace: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _modeItem({
    required BuildContext context,
    required AppMode mode,
    required String label,
    required IconData icon,
    required Color activeColor,
    required Color glowColor,
    bool isMonospace = false,
  }) {
    final isSelected = selectedMode == mode;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: isBusy || onModeChanged == null
          ? null
          : () {
              if (selectedMode != mode) {
                HapticFeedback.lightImpact();
                onModeChanged!(mode);
              }
            },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: isSelected
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    glowColor.withValues(alpha: 0.32),
                    activeColor.withValues(alpha: 0.14),
                  ],
                )
              : null,
          border: isSelected
              ? Border.all(
                  color: activeColor.withValues(alpha: 0.65),
                  width: 1.2,
                )
              : Border.all(
                  color: Colors.transparent,
                  width: 1.2,
                ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: glowColor.withValues(alpha: 0.28),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? activeColor
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.45)
                      : Colors.black.withValues(alpha: 0.40)),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                letterSpacing: isMonospace ? 1.4 : 0.2,
                fontFamily: isMonospace ? 'monospace' : null,
                color: isSelected
                    ? (isDark ? Colors.white : Colors.black87)
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.50)
                        : Colors.black.withValues(alpha: 0.45)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

