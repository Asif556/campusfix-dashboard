import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Pill badge showing a complaint status, colored per the shared status palette.
class StatusBadge extends StatelessWidget {
  final String status;
  final bool small;

  const StatusBadge({super.key, required this.status, this.small = false});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.statusColor(status);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 8 : 11,
        vertical: small ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          SizedBox(width: small ? 5 : 7),
          Text(
            status,
            style: TextStyle(
              color: color,
              fontSize: small ? 10.5 : 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
