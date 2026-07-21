import 'package:flutter/material.dart';

import '../core/constants.dart';

/// A rounded, gradient-tinted tile displaying a category's emoji.
class CategoryAvatar extends StatelessWidget {
  final String category;
  final double size;
  final bool solid;

  const CategoryAvatar({
    super.key,
    required this.category,
    this.size = 44,
    this.solid = false,
  });

  @override
  Widget build(BuildContext context) {
    final meta = categoryMeta(category);
    final colors = solid
        ? meta.gradient
        : meta.gradient.map((c) => c.withValues(alpha: 0.18)).toList();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      alignment: Alignment.center,
      child: Text(meta.emoji, style: TextStyle(fontSize: size * 0.45)),
    );
  }
}
