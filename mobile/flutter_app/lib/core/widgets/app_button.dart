import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum AppButtonStyle { primary, secondary, dark, danger, ghost }

class AppButton extends StatelessWidget {
  const AppButton(
    this.label, {
    super.key,
    required this.onPressed,
    this.style = AppButtonStyle.primary,
    this.icon,
    this.disabled = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonStyle style;
  final IconData? icon;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final background = switch (style) {
      AppButtonStyle.primary => AppColors.orange,
      AppButtonStyle.secondary || AppButtonStyle.dark => Colors.white,
      AppButtonStyle.danger => AppColors.red,
      AppButtonStyle.ghost => Colors.transparent,
    };
    final foreground = switch (style) {
      AppButtonStyle.primary || AppButtonStyle.danger => Colors.white,
      AppButtonStyle.secondary || AppButtonStyle.dark => AppColors.ink,
      AppButtonStyle.ghost => AppColors.muted,
    };
    return SizedBox(
      width: double.infinity,
      height: 49,
      child: ElevatedButton(
        onPressed: disabled ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          elevation: style == AppButtonStyle.primary ? 2 : 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: style == AppButtonStyle.secondary
                ? const BorderSide(color: AppColors.line)
                : BorderSide.none,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 19),
              const SizedBox(width: 8),
            ],
            Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}
