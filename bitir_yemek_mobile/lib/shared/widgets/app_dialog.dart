import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/theme.dart';

enum AppDialogTone { danger, brand }

/// Shared confirmation and information dialogs.
class AppDialog {
  AppDialog._();

  /// Dismissal, back navigation and the close button never confirm an action.
  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
    String cancelLabel = 'Vazgeç',
    IconData icon = Icons.help_outline_rounded,
    AppDialogTone tone = AppDialogTone.danger,
  }) async {
    final result = await show<bool>(
      context,
      builder: (dialogContext) => _ConfirmationPanel(
        icon: icon,
        tone: tone,
        title: title,
        message: message,
        cancelLabel: cancelLabel,
        confirmLabel: confirmLabel,
      ),
    );
    return result ?? false;
  }

  static Future<T?> show<T>(
    BuildContext context, {
    required WidgetBuilder builder,
    bool dismissible = true,
  }) {
    HapticFeedback.selectionClick();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: dismissible,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: AppColors.ink.withValues(alpha: 0.38),
      transitionDuration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 220),
      pageBuilder: (dialogContext, _, _) => builder(dialogContext),
      transitionBuilder: (context, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
  }
}

class _ConfirmationPanel extends StatelessWidget {
  const _ConfirmationPanel({
    required this.icon,
    required this.tone,
    required this.title,
    required this.message,
    required this.cancelLabel,
    required this.confirmLabel,
  });

  final IconData icon;
  final AppDialogTone tone;
  final String title;
  final String message;
  final String cancelLabel;
  final String confirmLabel;

  @override
  Widget build(BuildContext context) {
    final accent = tone == AppDialogTone.danger
        ? const Color(0xFFB64432)
        : AppColors.primaryInk;
    return AppDialogShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: accent, size: 25),
              ),
              IconButton(
                tooltip: 'Kapat',
                onPressed: () => Navigator.of(context).pop(false),
                style: IconButton.styleFrom(
                  foregroundColor: AppColors.inkSoft,
                  minimumSize: const Size(48, 48),
                ),
                icon: const Icon(Icons.close_rounded, size: 22),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Semantics(
            namesRoute: true,
            header: true,
            child: Text(
              title,
              style: AppTypography.h2.copyWith(
                fontSize: 23,
                height: 1.15,
                color: AppColors.ink,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            style: AppTypography.bodyLarge.copyWith(
              fontSize: 15,
              height: 1.45,
              color: AppColors.inkSoft,
            ),
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              final cancel = _DialogButton(
                label: cancelLabel,
                accent: accent,
                filled: false,
                onPressed: () => Navigator.of(context).pop(false),
              );
              final confirm = _DialogButton(
                label: confirmLabel,
                accent: accent,
                filled: true,
                onPressed: () => Navigator.of(context).pop(true),
              );
              // Keep both actions readable for large text and long translations.
              final scaler = MediaQuery.textScalerOf(context);
              bool fits(String label) {
                final painter = TextPainter(
                  text: TextSpan(
                    text: label,
                    style: AppTypography.button.copyWith(fontSize: 15),
                  ),
                  textScaler: scaler,
                  textDirection: Directionality.of(context),
                  maxLines: 1,
                )..layout();
                final fits =
                    painter.width + 32 <= (constraints.maxWidth - 10) / 2;
                painter.dispose();
                return fits;
              }

              if (!fits(cancelLabel) || !fits(confirmLabel)) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [confirm, const SizedBox(height: 10), cancel],
                );
              }
              return Row(
                children: [
                  Expanded(child: cancel),
                  const SizedBox(width: 10),
                  Expanded(child: confirm),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// A restrained cream surface, scrollable on small screens and with large text.
class AppDialogShell extends StatelessWidget {
  const AppDialogShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Dialog(
      backgroundColor: const Color(0xFFFFF9F2),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      constraints: const BoxConstraints(minWidth: 0, maxWidth: 380),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: AppDepth.border, width: 0.8),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: child,
      ),
    ),
  );
}

class _DialogButton extends StatelessWidget {
  const _DialogButton({
    required this.label,
    required this.filled,
    required this.accent,
    required this.onPressed,
  });

  final String label;
  final bool filled;
  final Color accent;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(
      backgroundColor: filled ? accent : const Color(0xFFF1E5D9),
      foregroundColor: filled ? Colors.white : AppColors.ink,
      minimumSize: const Size(48, 48),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: AppTypography.button.copyWith(fontSize: 15),
    ),
    child: Text(label, textAlign: TextAlign.center),
  );
}
