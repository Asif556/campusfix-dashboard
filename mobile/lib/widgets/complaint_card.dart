import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/env.dart';
import '../core/theme.dart';
import '../models/complaint.dart';
import '../services/session_store.dart';
import 'category_avatar.dart';
import 'status_badge.dart';

class ComplaintCard extends StatelessWidget {
  final Complaint complaint;
  final VoidCallback onTap;

  const ComplaintCard({super.key, required this.complaint, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final meta = categoryMeta(complaint.category);
    final photoUrl =
        Env.resolvePhotoUrl(SessionStore.instance.baseUrl, complaint.photo);

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: theme.dividerColor.withValues(alpha: 0.6)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (photoUrl != null)
                SizedBox(
                  height: 130,
                  child: CachedNetworkImage(
                    imageUrl: photoUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, _) => Container(color: AppColors.muted),
                    errorWidget: (_, _, _) => _gradientStrip(meta, tall: true),
                  ),
                )
              else
                _gradientStrip(meta),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CategoryAvatar(category: complaint.category, size: 44),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                complaint.category,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Icon(Icons.location_on_outlined,
                                      size: 13,
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.55)),
                                  const SizedBox(width: 3),
                                  Expanded(
                                    child: Text(
                                      complaint.location.short,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: theme.colorScheme.onSurface
                                            .withValues(alpha: 0.6),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.3)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      complaint.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.65),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        StatusBadge(status: complaint.status),
                        Row(
                          children: [
                            Icon(Icons.calendar_today_outlined,
                                size: 12,
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.5)),
                            const SizedBox(width: 4),
                            Text(
                              complaint.date,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.55),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _gradientStrip(CategoryMeta meta, {bool tall = false}) {
    return Container(
      height: tall ? 130 : 6,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: meta.gradient.map((c) => c.withValues(alpha: 0.85)).toList(),
        ),
      ),
      alignment: Alignment.center,
      child: tall ? Text(meta.emoji, style: const TextStyle(fontSize: 40)) : null,
    );
  }
}
