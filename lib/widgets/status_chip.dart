import 'package:flutter/material.dart';

import '../models/task_history_entry.dart';
import '../theme/app_theme.dart';

/// Small colored pill used for task status and connection states.
class StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const StatusChip({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  factory StatusChip.forTaskStatus(TaskStatus status, {Key? key}) {
    return switch (status) {
      TaskStatus.success => StatusChip(
          key: key,
          label: 'Success',
          color: AppTheme.success,
          icon: Icons.check_circle_outline,
        ),
      TaskStatus.failed => StatusChip(
          key: key,
          label: 'Failed',
          color: AppTheme.danger,
          icon: Icons.error_outline,
        ),
      TaskStatus.cancelled => StatusChip(
          key: key,
          label: 'Cancelled',
          color: AppTheme.warning,
          icon: Icons.stop_circle_outlined,
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Pulsing dot indicating the accessibility service connection state.
class ServiceStatusDot extends StatelessWidget {
  final bool enabled;
  const ServiceStatusDot({super.key, required this.enabled});

  @override
  Widget build(BuildContext context) {
    final color = enabled ? AppTheme.success : AppTheme.danger;
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 6),
        ],
      ),
    );
  }
}
