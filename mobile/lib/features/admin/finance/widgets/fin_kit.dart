// Small finance UI pieces mirroring web components used across FinanceManager:
// DescriptiveValueButton / DescriptiveStatSummary, ChannelBadge, DateInput, month input,
// ExportFormatMenu, SharePdfWhatsAppButton, radio / checkbox rows, compact tables.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/i18n/extra/finance_strings.dart';
import '../../../../core/i18n/i18n.dart' show applyVars;
import '../../../../core/ui/ui.dart';
import '../export/finance_exports.dart';
import '../logic/cash_bank_channel.dart';
import '../logic/finance_dates.dart';
import '../logic/finance_period_report.dart';

extension FinI18nX on BuildContext {
  /// Finance label from `kFinanceStrings` (works before and after the lead merges it).
  String fin(String key, [Map<String, Object?>? vars]) {
    final row = kFinanceStrings[key];
    if (row != null) {
      final v = row[lang == AppLang.hi ? 'hi' : 'en'] ?? row['en'] ?? key;
      return applyVars(v, vars);
    }
    return t(key, vars);
  }

  String finStatus(String status) {
    final k = 'fin.status.$status';
    return kFinanceStrings.containsKey(k) ? fin(k) : status;
  }

  String finMethod(String method) {
    final k = 'fin.method.$method';
    return kFinanceStrings.containsKey(k)
        ? fin(k)
        : method.replaceAll('_', ' ');
  }
}

/// Positive decimal input (web `type="number"`).
final List<TextInputFormatter> kAmountFormatters = [
  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
];

/// Web `DescriptiveValueButton`: value with an info glyph; tap explains the number.
class FinInfoValue extends StatelessWidget {
  const FinInfoValue({
    super.key,
    required this.title,
    required this.value,
    required this.description,
    this.howCalculated,
    this.style,
    this.color,
  });

  final String title;
  final String value;
  final String description;
  final String? howCalculated;
  final TextStyle? style;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () => AppFeedback.info(context,
          title: title, description: description, howCalculated: howCalculated),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                value,
                style: (style ??
                        AppText.mono(context,
                            size: 12, weight: FontWeight.w700))
                    .copyWith(color: color),
              ),
            ),
            const SizedBox(width: 3),
            Icon(Icons.info_outline, size: 11, color: t.mutedForeground),
          ],
        ),
      ),
    );
  }
}

/// Web `DescriptiveStatSummary`: muted one-liner; tap for description.
class FinSummaryLine extends StatelessWidget {
  const FinSummaryLine(
      {super.key,
      required this.label,
      required this.description,
      this.howCalculated});

  final String label;
  final String description;
  final String? howCalculated;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => AppFeedback.info(context,
          title: label, description: description, howCalculated: howCalculated),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child:
                  Icon(Icons.info_outline, size: 12, color: t.mutedForeground),
            ),
            const SizedBox(width: 6),
            Expanded(
                child: Text(label,
                    style: AppText.tiny(context).copyWith(fontSize: 11))),
          ],
        ),
      ),
    );
  }
}

/// Web `ChannelBadge` (Cash amber / Bank blue / Other muted).
class FinChannelBadge extends StatelessWidget {
  const FinChannelBadge({super.key, required this.method});

  final Object? method;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final ch = normalizePaymentChannel(method);
    final (label, color) = switch (ch) {
      PaymentChannel.cash => (context.fin('fin.cash'), t.warning),
      PaymentChannel.bank => (context.tr('Bank', 'बैंक'), t.accent),
      PaymentChannel.other => (context.fin('fin.other'), t.mutedForeground),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color:
            ch == PaymentChannel.other ? t.muted : AppTokens.tint(color, 0.15),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(label.toUpperCase(),
          style: TextStyle(
              fontSize: 9, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

/// Rounded status pill (verified green / rejected red / pending amber).
class FinStatusPill extends StatelessWidget {
  const FinStatusPill({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = switch (status) {
      'verified' || 'paid' || 'settled' || 'receipt' => t.success,
      'rejected' || 'expense' => t.destructive,
      'pending' => t.warning,
      _ => t.mutedForeground,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
          color: AppTokens.tint(c, 0.18),
          borderRadius: BorderRadius.circular(99)),
      child: Text(context.finStatus(status),
          style:
              TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: c)),
    );
  }
}

/// Uppercase tiny label (`text-[10px] font-medium uppercase text-muted-foreground`).
class FinMicroLabel extends StatelessWidget {
  const FinMicroLabel(this.text,
      {super.key, this.padding = const EdgeInsets.only(bottom: 4)});

  final String text;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Padding(
        padding: padding,
        child: Text(text.toUpperCase(),
            style: AppText.tiny(context)
                .copyWith(fontWeight: FontWeight.w600, letterSpacing: 0.5)),
      );
}

/// Muted helper text (`text-[10px] text-muted-foreground leading-snug`).
class FinHint extends StatelessWidget {
  const FinHint(this.text,
      {super.key, this.color, this.padding = const EdgeInsets.only(top: 4)});

  final String text;
  final Color? color;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Padding(
        padding: padding,
        child: Text(text,
            style: AppText.tiny(context)
                .copyWith(fontSize: 11, height: 1.35, color: color)),
      );
}

/// Tinted bordered box (`rounded-lg border p-3 bg-x/5`).
class FinTintBox extends StatelessWidget {
  const FinTintBox(
      {super.key,
      required this.child,
      this.color,
      this.padding = const EdgeInsets.all(12),
      this.margin});

  final Widget child;
  final Color? color;
  final EdgeInsets padding;
  final EdgeInsets? margin;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = color;
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color:
            c == null ? AppTokens.tint(t.muted, 0.35) : AppTokens.tint(c, 0.06),
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        border:
            Border.all(color: c == null ? t.border : AppTokens.tint(c, 0.3)),
      ),
      child: child,
    );
  }
}

/// Radio row (web `<label><input type="radio"/> …</label>`).
class FinRadioRow<T> extends StatelessWidget {
  const FinRadioRow(
      {super.key,
      required this.value,
      required this.group,
      required this.onChanged,
      required this.label});

  final T value;
  final T group;
  final ValueChanged<T> onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final on = value == group;
    return InkWell(
      onTap: () => onChanged(value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(on ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                size: 18, color: on ? t.primary : t.mutedForeground),
            const SizedBox(width: 8),
            Expanded(
                child: Text(label,
                    style: AppText.body(context).copyWith(fontSize: 12))),
          ],
        ),
      ),
    );
  }
}

/// Checkbox row (web `<label><input type="checkbox"/> …</label>`).
class FinCheckRow extends StatelessWidget {
  const FinCheckRow(
      {super.key,
      required this.value,
      required this.onChanged,
      required this.label,
      this.enabled = true});

  final bool value;
  final ValueChanged<bool> onChanged;
  final String label;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: InkWell(
        onTap: enabled ? () => onChanged(!value) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(value ? Icons.check_box : Icons.check_box_outline_blank,
                  size: 18, color: value ? t.primary : t.mutedForeground),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(label,
                      style: AppText.body(context).copyWith(fontSize: 12))),
            ],
          ),
        ),
      ),
    );
  }
}

/// Web `DateInput`: dd/MM/yyyy typing + calendar picker; emits `yyyy-MM-dd`.
class FinDateField extends StatefulWidget {
  const FinDateField(
      {super.key,
      required this.value,
      required this.onChanged,
      this.label,
      this.enabled = true});

  final String value;
  final ValueChanged<String> onChanged;
  final String? label;
  final bool enabled;

  @override
  State<FinDateField> createState() => _FinDateFieldState();
}

class _FinDateFieldState extends State<FinDateField> {
  late final TextEditingController _ctrl =
      TextEditingController(text: isoDateToDisplay(widget.value));
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (_focus.hasFocus) return;
      final iso = parseDisplayDateToIso(_ctrl.text);
      if (iso != null) {
        _ctrl.text = isoDateToDisplay(iso);
        if (iso != widget.value) widget.onChanged(iso);
      } else {
        _ctrl.text = isoDateToDisplay(widget.value);
      }
    });
  }

  @override
  void didUpdateWidget(FinDateField old) {
    super.didUpdateWidget(old);
    if (!_focus.hasFocus && old.value != widget.value) {
      _ctrl.text = isoDateToDisplay(widget.value);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final initial = parseYmd(widget.value) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    final iso = ymdOf(picked);
    _ctrl.text = isoDateToDisplay(iso);
    widget.onChanged(iso);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final field = TextField(
      controller: _ctrl,
      focusNode: _focus,
      enabled: widget.enabled,
      keyboardType: TextInputType.datetime,
      style: TextStyle(fontSize: 14, color: t.foreground),
      onChanged: (v) {
        final iso = parseDisplayDateToIso(v);
        if (iso != null) widget.onChanged(iso);
      },
      decoration: InputDecoration(
        hintText: 'dd/mm/yyyy',
        suffixIcon: IconButton(
          icon: Icon(Icons.calendar_today_outlined,
              size: 18, color: t.mutedForeground),
          onPressed: widget.enabled ? _pick : null,
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null) FieldLabel(widget.label!),
        field,
        if (_ctrl.text.isEmpty)
          FinHint(
              context.tr('Type dd/mm/yyyy or use the calendar',
                  'dd/mm/yyyy लिखें या कैलेंडर चुनें'),
              padding: const EdgeInsets.only(top: 2)),
      ],
    );
  }
}

/// Web `<input type="month" min=…>`: shows `MM/yyyy`, opens a month grid.
class FinMonthField extends StatelessWidget {
  const FinMonthField(
      {super.key,
      required this.value,
      required this.onChanged,
      this.label,
      this.min = kFinanceReportingEarliestMonth});

  final String value;
  final ValueChanged<String> onChanged;
  final String? label;
  final String min;

  Future<void> _pick(BuildContext context) async {
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => _MonthPickerDialog(initial: value, min: min),
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final box = InkWell(
      onTap: () => _pick(context),
      borderRadius: BorderRadius.circular(AppTokens.radiusSm),
      child: InputDecorator(
        decoration: InputDecoration(
            suffixIcon: Icon(Icons.calendar_month_outlined,
                size: 18, color: t.mutedForeground)),
        child: Text(isoMonthToDisplay(value),
            style: TextStyle(fontSize: 14, color: t.foreground)),
      ),
    );
    if (label == null) return box;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [FieldLabel(label!), box],
    );
  }
}

class _MonthPickerDialog extends StatefulWidget {
  const _MonthPickerDialog({required this.initial, required this.min});

  final String initial;
  final String min;

  @override
  State<_MonthPickerDialog> createState() => _MonthPickerDialogState();
}

class _MonthPickerDialogState extends State<_MonthPickerDialog> {
  late int _year =
      int.tryParse(widget.initial.split('-').first) ?? DateTime.now().year;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final minYear = int.tryParse(widget.min.split('-').first) ?? 2000;
    return AlertDialog(
      title: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _year > minYear ? () => setState(() => _year--) : null,
          ),
          Expanded(child: Text('$_year', textAlign: TextAlign.center)),
          IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () => setState(() => _year++)),
        ],
      ),
      content: SizedBox(
        width: 280,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var m = 1; m <= 12; m++)
              () {
                final ym = '$_year-${m.toString().padLeft(2, '0')}';
                final disabled = ym.compareTo(widget.min) < 0;
                final selected = ym == widget.initial;
                return SizedBox(
                  width: 82,
                  child: Opacity(
                    opacity: disabled ? 0.35 : 1,
                    child: PillChoice(
                      label: englishMonthName(m).substring(0, 3),
                      selected: selected,
                      onTap:
                          disabled ? () {} : () => Navigator.pop(context, ym),
                    ),
                  ),
                );
              }(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.fin('fin.cancel'),
              style: TextStyle(color: t.mutedForeground)),
        ),
      ],
    );
  }
}

/// Web `ExportFormatMenu` (PDF / Excel / Word / CSV).
class FinExportMenuButton extends StatelessWidget {
  const FinExportMenuButton(
      {super.key,
      required this.label,
      required this.onExport,
      this.enabled = true});

  final String label;
  final ValueChanged<FinExportFormat> onExport;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return PopupMenuButton<FinExportFormat>(
      enabled: enabled,
      onSelected: onExport,
      itemBuilder: (_) => [
        PopupMenuItem(
            value: FinExportFormat.pdf,
            child: _menuRow(Icons.picture_as_pdf_outlined, 'PDF')),
        PopupMenuItem(
            value: FinExportFormat.excel,
            child: _menuRow(Icons.table_chart_outlined, 'Excel (.xlsx)')),
        PopupMenuItem(
            value: FinExportFormat.word,
            child: _menuRow(Icons.description_outlined, 'Word (.doc)')),
        PopupMenuItem(
            value: FinExportFormat.csv,
            child: _menuRow(Icons.download_outlined, 'CSV')),
      ],
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: t.secondary,
            border: Border.all(color: t.border),
            borderRadius: BorderRadius.circular(AppTokens.radiusSm),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.download_outlined,
                  size: 14, color: t.secondaryForeground),
              const SizedBox(width: 4),
              Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: t.secondaryForeground)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _menuRow(IconData icon, String label) => Row(children: [
        Icon(icon, size: 16),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 13))
      ]);
}

/// Web `SharePdfWhatsAppButton` (green tint) — builds the PDF and opens the share sheet.
class FinShareButton extends StatefulWidget {
  const FinShareButton(
      {super.key,
      required this.label,
      required this.onShare,
      this.enabled = true});

  final String label;
  final Future<void> Function() onShare;
  final bool enabled;

  @override
  State<FinShareButton> createState() => _FinShareButtonState();
}

class _FinShareButtonState extends State<FinShareButton> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = t.success;
    final disabled = !widget.enabled || _busy;
    return Opacity(
      opacity: disabled && !_busy ? 0.5 : 1,
      child: Material(
        color: AppTokens.tint(c, 0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
          side: BorderSide(color: AppTokens.tint(c, 0.3)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
          onTap: disabled
              ? null
              : () async {
                  setState(() => _busy = true);
                  try {
                    await widget.onShare();
                  } catch (_) {
                    if (context.mounted) {
                      AppFeedback.toast(
                          context,
                          context.tr(
                              'Could not share PDF', 'PDF साझा नहीं हो सका'),
                          tone: BadgeTone.alert);
                    }
                  } finally {
                    if (mounted) setState(() => _busy = false);
                  }
                },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_busy)
                  SizedBox(
                      width: 14,
                      height: 14,
                      child:
                          CircularProgressIndicator(strokeWidth: 2, color: c))
                else
                  Icon(Icons.share_outlined, size: 14, color: c),
                const SizedBox(width: 4),
                Text(
                  _busy
                      ? context.tr('Sharing…', 'साझा हो रहा है…')
                      : widget.label,
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w500, color: c),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Small bordered action (web `btn-secondary text-[10px] py-1 px-2`).
class FinMiniButton extends StatelessWidget {
  const FinMiniButton(
      {super.key,
      required this.label,
      required this.onTap,
      this.icon,
      this.color,
      this.filled = false});

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final Color? color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final fg = filled ? t.primaryForeground : (color ?? t.secondaryForeground);
    final bg = filled
        ? (color ?? t.primary)
        : (color == null ? t.secondary : Colors.transparent);
    return Opacity(
      opacity: onTap == null ? 0.5 : 1,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
          side: filled ? BorderSide.none : BorderSide(color: color ?? t.border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 12, color: fg),
                  const SizedBox(width: 4)
                ],
                Flexible(
                  child: Text(label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: fg)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact dropdown used inline on cards (status selects).
class FinInlineSelect<T> extends StatelessWidget {
  const FinInlineSelect(
      {super.key,
      required this.value,
      required this.items,
      required this.labelOf,
      required this.onChanged});

  final T value;
  final List<T> items;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return PopupMenuButton<T>(
      onSelected: onChanged,
      itemBuilder: (_) => [
        for (final i in items)
          PopupMenuItem(
              value: i,
              child: Text(labelOf(i), style: const TextStyle(fontSize: 13)))
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: t.input,
          border: Border.all(color: t.border),
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(labelOf(value),
                style: TextStyle(fontSize: 11, color: t.foreground)),
            Icon(Icons.arrow_drop_down, size: 16, color: t.mutedForeground),
          ],
        ),
      ),
    );
  }
}

/// Column spec for [FinTable].
class FinCol {
  const FinCol(this.label, {this.width = 80, this.right = false});

  final String label;
  final double width;
  final bool right;
}

/// Horizontally scrollable compact table (web `overflow-x-auto` + `table text-[10px]`).
class FinTable extends StatelessWidget {
  const FinTable(
      {super.key,
      required this.columns,
      required this.rows,
      this.footer,
      this.onRowTap});

  final List<FinCol> columns;
  final List<List<Widget>> rows;
  final List<Widget>? footer;
  final ValueChanged<int>? onRowTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    Widget line(List<Widget> cells,
        {Color? bg, bool header = false, VoidCallback? onTap}) {
      final row = Container(
        decoration: BoxDecoration(
            color: bg,
            border: Border(
                bottom: BorderSide(color: AppTokens.tint(t.border, 0.8)))),
        child: Row(
          children: [
            for (var i = 0; i < columns.length; i++)
              SizedBox(
                width: columns[i].width,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
                  child: Align(
                    alignment: columns[i].right
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: i < cells.length ? cells[i] : const SizedBox(),
                  ),
                ),
              ),
          ],
        ),
      );
      return onTap == null ? row : InkWell(onTap: onTap, child: row);
    }

    final headerStyle = TextStyle(
        fontSize: 10, fontWeight: FontWeight.w600, color: t.mutedForeground);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        decoration: BoxDecoration(
            border: Border.all(color: t.border),
            borderRadius: BorderRadius.circular(6)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            line([for (final c in columns) Text(c.label, style: headerStyle)],
                bg: AppTokens.tint(t.muted, 0.6), header: true),
            for (var r = 0; r < rows.length; r++)
              line(rows[r],
                  onTap: onRowTap == null ? null : () => onRowTap!(r)),
            if (footer != null)
              line(footer!, bg: AppTokens.tint(t.muted, 0.35)),
          ],
        ),
      ),
    );
  }
}

/// Table cell text helpers.
Widget finCell(BuildContext context, String text,
        {bool mono = false,
        bool bold = false,
        Color? color,
        int maxLines = 2}) =>
    Text(
      text,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      style: mono
          ? AppText.mono(context,
              size: 10,
              weight: bold ? FontWeight.w700 : FontWeight.w400,
              color: color)
          : TextStyle(
              fontSize: 10,
              fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
              color: color ?? context.tokens.foreground),
    );

/// Text-field controller that notifies the parent on change.
TextEditingController finController([String text = '']) =>
    TextEditingController(text: text);
