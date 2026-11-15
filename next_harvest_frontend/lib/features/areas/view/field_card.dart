import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/field.dart';

class FieldCard extends StatelessWidget {
  const FieldCard({super.key, required this.field, this.onTap, this.onDelete});

  final Field field;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final radius = BorderRadius.circular(16);
    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Ink(
          decoration: BoxDecoration(
            color: Color.alphaBlend(
              colors.primaryContainer.withValues(alpha: 0.45),
              colors.surface,
            ),
            borderRadius: radius,
          ),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        field.name,
                        style: GoogleFonts.ibmPlexSansThai(
                          textStyle: theme.textTheme.headlineSmall,
                          fontWeight: FontWeight.w500,
                          color: colors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        field.currentCrop.isNotEmpty
                            ? 'Current Crop: ${field.currentCrop}'
                            : 'Current Crop: Not specified',
                        style: GoogleFonts.inter(
                          textStyle: theme.textTheme.bodyMedium,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onDelete != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Delete field',
                    onPressed: onDelete,
                    icon: Icon(Icons.delete_outline, color: colors.error),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
