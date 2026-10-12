import 'package:flutter/material.dart';

import '../i18n/i18n.dart';
import '../theme/app_tokens.dart';
import 'controls.dart';
import 'layout.dart';

/// SweetAlert-style dialogs and toasts used across the web app (`src/lib/swal.ts`, sonner).
abstract final class AppFeedback {
  /// Web `confirmAction` (warning icon, Yes / No).
  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    String? message,
    String? confirmLabel,
    String? cancelLabel,
    bool destructive = false,
  }) async {
    final t = context.tokens;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.warning_amber_rounded, color: destructive ? t.destructive : t.warning, size: 40),
        title: Text(title, textAlign: TextAlign.center),
        content: message == null ? null : Text(message, textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(cancelLabel ?? ctx.t('swal.no'))),
          FilledButton(
            style: destructive ? FilledButton.styleFrom(backgroundColor: t.destructive) : null,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel ?? ctx.t('swal.yes')),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  /// Web `showSuccess` — green check dialog that closes itself.
  static Future<void> success(BuildContext context, {required String title, String? message}) async {
    final t = context.tokens;
    final nav = Navigator.of(context);
    var open = true;
    Future.delayed(const Duration(milliseconds: 1600), () {
      if (open && nav.mounted) nav.pop();
    });
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.check_circle_rounded, color: t.success, size: 48),
        title: Text(title, textAlign: TextAlign.center),
        content: message == null ? null : Text(message, textAlign: TextAlign.center),
      ),
    );
    open = false;
  }

  /// Error dialog with an OK button.
  static Future<void> error(BuildContext context, {required String title, String? message}) {
    final t = context.tokens;
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.error_rounded, color: t.destructive, size: 44),
        title: Text(title, textAlign: TextAlign.center),
        content: message == null ? null : Text(message, textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.center,
        actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
      ),
    );
  }

  /// Sonner-style toast.
  static void toast(BuildContext context, String message, {BadgeTone tone = BadgeTone.neutral, Duration? duration}) {
    final t = context.tokens;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    final color = switch (tone) {
      BadgeTone.alert => t.destructive,
      BadgeTone.success || BadgeTone.inside => t.success,
      BadgeTone.warning => t.warning,
      _ => null,
    };
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              if (color != null) ...[
                Icon(
                  tone == BadgeTone.alert ? Icons.error_outline : (tone == BadgeTone.warning ? Icons.warning_amber : Icons.check_circle_outline),
                  color: color,
                  size: 18,
                ),
                const SizedBox(width: 8),
              ],
              Expanded(child: Text(message)),
            ],
          ),
          duration: duration ?? const Duration(seconds: 3),
        ),
      );
  }

  /// Single text input prompt (web `Swal.fire({ input })`).
  static Future<String?> prompt(
    BuildContext context, {
    required String title,
    String? message,
    String? initial,
    String? hint,
    TextInputType? keyboardType,
    bool obscure = false,
    String? confirmLabel,
    int maxLines = 1,
  }) async {
    final ctrl = TextEditingController(text: initial ?? '');
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (message != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(message)),
            TextField(
              controller: ctrl,
              autofocus: true,
              obscureText: obscure,
              keyboardType: keyboardType,
              maxLines: obscure ? 1 : maxLines,
              decoration: InputDecoration(hintText: hint),
              onSubmitted: (v) => Navigator.pop(ctx, v),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(ctx.t('common.cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: Text(confirmLabel ?? 'OK')),
        ],
      ),
    );
    ctrl.dispose();
    return value;
  }

  /// Information sheet (title / description / how it is calculated) — web `HoverInfoTip`.
  static Future<void> info(
    BuildContext context, {
    required String title,
    required String description,
    String? howCalculated,
    String? navigateLabel,
    VoidCallback? onNavigate,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppText.pageTitle(ctx)),
              const SizedBox(height: 8),
              Text(description, style: AppText.body(ctx)),
              if (howCalculated != null) ...[
                const SizedBox(height: 12),
                Text(ctx.tr('How it is calculated', 'गणना कैसे होती है'), style: AppText.fieldLabel(ctx)),
                const SizedBox(height: 4),
                Text(howCalculated, style: AppText.caption(ctx)),
              ],
              if (onNavigate != null) ...[
                const SizedBox(height: 16),
                AppButton(
                  label: navigateLabel ?? ctx.tr('Open', 'खोलें'),
                  onPressed: () {
                    Navigator.pop(ctx);
                    onNavigate();
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Centered spinner.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            if (message != null) ...[const SizedBox(height: 12), Text(message!, style: AppText.caption(context))],
          ],
        ),
      ),
    );
  }
}

/// Muted empty-state text (web `text-sm text-muted-foreground text-center py-8`).
class EmptyView extends StatelessWidget {
  const EmptyView({super.key, this.message, this.icon});

  final String? message;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 36, color: context.tokens.mutedForeground), const SizedBox(height: 8)],
          Text(message ?? context.t('mobile.empty'), textAlign: TextAlign.center, style: AppText.body(context).copyWith(color: context.tokens.mutedForeground)),
        ],
      ),
    );
  }
}

/// Error message with retry.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, this.message, this.onRetry});

  final String? message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_rounded, size: 36, color: context.tokens.destructive),
          const SizedBox(height: 8),
          Text(message ?? context.t('mobile.loadFailed'), textAlign: TextAlign.center, style: AppText.body(context)),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            AppButton.secondary(label: context.t('mobile.retry'), icon: Icons.refresh, onPressed: onRetry, expand: false),
          ],
        ],
      ),
    );
  }
}

/// Loads [future] and renders loading / error (with retry) / data states.
class AsyncBody<T> extends StatefulWidget {
  const AsyncBody({super.key, required this.load, required this.builder, this.isEmpty, this.emptyMessage});

  final Future<T> Function() load;
  final Widget Function(BuildContext context, T data, Future<void> Function() reload) builder;
  final bool Function(T data)? isEmpty;
  final String? emptyMessage;

  @override
  State<AsyncBody<T>> createState() => _AsyncBodyState<T>();
}

class _AsyncBodyState<T> extends State<AsyncBody<T>> {
  late Future<T> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.load();
  }

  Future<void> _reload() async {
    final f = widget.load();
    setState(() => _future = f);
    try {
      await f;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const LoadingView();
        if (snap.hasError) return ErrorView(onRetry: _reload);
        final data = snap.data as T;
        if (widget.isEmpty?.call(data) ?? false) return EmptyView(message: widget.emptyMessage);
        return widget.builder(context, data, _reload);
      },
    );
  }
}
