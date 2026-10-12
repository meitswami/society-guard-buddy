import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/ui/ui.dart';

/// Web OTP boxes (`w-11 h-12 rounded-xl border-2 font-mono`): six digit cells backed by one
/// invisible text field, so paste, backspace and SMS one-time-code autofill all work.
class OtpCodeInput extends StatefulWidget {
  const OtpCodeInput({
    super.key,
    required this.controller,
    required this.onCompleted,
    this.focusNode,
    this.enabled = true,
    this.length = 6,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final ValueChanged<String> onCompleted;
  final FocusNode? focusNode;
  final bool enabled;
  final int length;
  final bool autofocus;

  @override
  State<OtpCodeInput> createState() => _OtpCodeInputState();
}

class _OtpCodeInputState extends State<OtpCodeInput> {
  FocusNode? _ownFocus;
  FocusNode get _focus => widget.focusNode ?? (_ownFocus ??= FocusNode());

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    _focus.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(covariant OtpCodeInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onChanged);
      widget.controller.addListener(_onChanged);
    }
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _ownFocus)?.removeListener(_onFocus);
      _focus.addListener(_onFocus);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    _focus.removeListener(_onFocus);
    _ownFocus?.dispose();
    super.dispose();
  }

  String _lastNotified = '';

  void _onChanged() {
    final code = widget.controller.text;
    if (mounted) setState(() {});
    if (code.length == widget.length && code != _lastNotified) {
      _lastNotified = code;
      widget.onCompleted(code);
    } else if (code.length < widget.length) {
      _lastNotified = '';
    }
  }

  void _onFocus() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final code = widget.controller.text;
    final focused = _focus.hasFocus;
    final active = code.length.clamp(0, widget.length - 1);

    Widget cell(int i) {
      final digit = i < code.length ? code[i] : '';
      final highlight = widget.enabled && focused && i == active;
      return AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: 44,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: t.background,
          borderRadius: BorderRadius.circular(AppTokens.radius),
          border: Border.all(color: highlight ? t.primary : t.border, width: 2),
          boxShadow: highlight ? [BoxShadow(color: AppTokens.tint(t.primary, 0.2), spreadRadius: 2)] : null,
        ),
        child: Text(digit, style: AppText.mono(context, size: 18, weight: FontWeight.w600)),
      );
    }

    return Semantics(
      label: context.tr('One-time code', 'एक बार का कोड'),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < widget.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                cell(i),
              ],
            ],
          ),
          Positioned.fill(
            child: Opacity(
              opacity: 0,
              child: TextField(
                controller: widget.controller,
                focusNode: _focus,
                enabled: widget.enabled,
                autofocus: widget.autofocus,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.oneTimeCode],
                showCursor: false,
                maxLength: widget.length,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(widget.length),
                ],
                style: const TextStyle(color: Colors.transparent, fontSize: 1),
                decoration: const InputDecoration(
                  counterText: '',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  filled: false,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
