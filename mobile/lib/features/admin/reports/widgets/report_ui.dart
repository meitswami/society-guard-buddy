import 'package:flutter/material.dart';

import '../../../../core/i18n/extra/reports_strings.dart';
import '../../../../core/ui/ui.dart';
import '../logic/js_compat.dart';
import '../logic/metric_copy.dart';
import '../logic/report_formatters.dart';

/// Small building blocks shared by the Reports screens (web Tailwind patterns).

bool isHindi(BuildContext context) => context.lang == AppLang.hi;

/// Reports-module string from [kReportsStrings] (works before the lead merges the map).
String rs(BuildContext context, String key) {
  final row = kReportsStrings[key];
  if (row == null) return context.t(key);
  return (isHindi(context) ? row['hi'] : row['en']) ?? row['en'] ?? key;
}

/// Opens the description sheet for a metric (web `HoverInfoTip`).
Future<void> showMetricInfo(
  BuildContext context,
  MetricCopy metric, {
  String? title,
  String? extraDescription,
  String? navigateLabel,
  VoidCallback? onNavigate,
}) {
  final hi = isHindi(context);
  return AppFeedback.info(
    context,
    title: title ?? metric.title(hi),
    description: [metric.description(hi), if (extraDescription != null) extraDescription].join(' '),
    howCalculated: metric.how(hi),
    navigateLabel: navigateLabel,
    onNavigate: onNavigate,
  );
}

/// Web `rounded-lg border border-border bg-card/40 p-3` panel.
class ReportPanel extends StatelessWidget {
  const ReportPanel({super.key, required this.child, this.padding = const EdgeInsets.all(12), this.margin});

  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets? margin;

  @override
  Widget build(BuildContext context) => CardSection(padding: padding, margin: margin, child: child);
}

/// Web `DescriptiveStatCard` with an icon row, tappable value and optional extra content.
class ReportStatCard extends StatelessWidget {
  const ReportStatCard({
    super.key,
    required this.metric,
    required this.value,
    this.title,
    this.caption,
    this.icon,
    this.iconColor,
    this.label,
    this.onNavigate,
    this.navigateLabel,
    this.center = false,
    this.valueColor,
    this.children = const [],
    this.compact = false,
  });

  final MetricCopy metric;
  final String value;

  /// Overrides the metric title in the info sheet.
  final String? title;
  final String? caption;
  final IconData? icon;
  final Color? iconColor;

  /// Text shown next to the icon (web `<span className="text-xs font-semibold">`).
  final String? label;
  final VoidCallback? onNavigate;
  final String? navigateLabel;
  final bool center;
  final Color? valueColor;
  final List<Widget> children;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final hi = isHindi(context);
    void info() => showMetricInfo(context, metric, title: title, onNavigate: onNavigate, navigateLabel: navigateLabel);
    final valueText = Text(
      value,
      textAlign: center ? TextAlign.center : TextAlign.start,
      style: compact
          ? AppText.mono(context, size: 17, weight: FontWeight.w700, color: valueColor)
          : AppText.statValue(context, color: valueColor).copyWith(fontSize: 22),
    );
    return CardSection(
      padding: EdgeInsets.all(compact ? 10 : 14),
      onTap: info,
      child: Column(
        crossAxisAlignment: center ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) Icon(icon, size: 16, color: iconColor ?? t.mutedForeground),
              if (label != null) ...[
                const SizedBox(width: 6),
                Flexible(child: Text(label!, style: AppText.bodyMedium(context).copyWith(fontSize: 12, fontWeight: FontWeight.w600))),
              ],
              const Spacer(),
              Icon(Icons.info_outline, size: 14, color: AppTokens.tint(t.mutedForeground, 0.7)),
            ],
          ),
          const SizedBox(height: 6),
          if (onNavigate != null)
            InkWell(onTap: onNavigate, borderRadius: BorderRadius.circular(6), child: valueText)
          else
            valueText,
          Text(
            caption ?? title ?? metric.title(hi),
            textAlign: center ? TextAlign.center : TextAlign.start,
            style: AppText.caption(context),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          ...children,
        ],
      ),
    );
  }
}

/// Web `DescriptiveValueButton` / `TableSumInsight`: a value with an info icon.
class InfoValue extends StatelessWidget {
  const InfoValue({
    super.key,
    required this.value,
    required this.metric,
    this.title,
    this.extraDescription,
    this.style,
    this.alignEnd = false,
  });

  final String value;
  final MetricCopy metric;
  final String? title;
  final String? extraDescription;
  final TextStyle? style;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () => showMetricInfo(context, metric, title: title, extraDescription: extraDescription),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            Flexible(
              child: Text(
                value,
                style: style ?? AppText.mono(context, size: 12, weight: FontWeight.w700),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 3),
            Icon(Icons.info_outline, size: 11, color: AppTokens.tint(t.mutedForeground, 0.6)),
          ],
        ),
      ),
    );
  }
}

/// Report type tab pill (web `rounded-lg text-xs font-medium` buttons).
class ReportTabPill extends StatelessWidget {
  const ReportTabPill({super.key, required this.label, required this.selected, required this.onTap, this.icon, this.trailing});

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final IconData? trailing;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final fg = selected ? t.primaryForeground : t.secondaryForeground;
    return Material(
      color: selected ? t.primary : t.secondary,
      borderRadius: BorderRadius.circular(AppTokens.radiusSm),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: 14, color: fg), const SizedBox(width: 6)],
              Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: fg)),
              if (trailing != null) ...[const SizedBox(width: 4), Icon(trailing, size: 14, color: AppTokens.tint(fg, 0.7))],
            ],
          ),
        ),
      ),
    );
  }
}

/// Month chooser (web `<input type="month" min=…>` shown as `MM/yyyy`).
class MonthPickerButton extends StatelessWidget {
  const MonthPickerButton({super.key, required this.value, required this.onChanged, this.minMonth});

  /// `yyyy-MM`
  final String value;
  final ValueChanged<String> onChanged;
  final String? minMonth;

  Future<void> _pick(BuildContext context) async {
    final picked = await showMonthPickerSheet(context, initial: value, minMonth: minMonth);
    if (picked != null && picked != value) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) => AppButton.secondary(
        label: fmtIsoMonthToDisplay(value),
        icon: Icons.calendar_month_outlined,
        expand: false,
        dense: true,
        onPressed: () => _pick(context),
      );
}

const List<String> _monthsEn = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const List<String> _monthsHi = ['जन', 'फ़र', 'मार्च', 'अप्रै', 'मई', 'जून', 'जुला', 'अग', 'सित', 'अक्टू', 'नव', 'दिस'];

/// Year + month grid sheet. Returns `yyyy-MM`.
Future<String?> showMonthPickerSheet(BuildContext context, {required String initial, String? minMonth}) {
  final parts = initial.split('-');
  var year = int.tryParse(parts[0]) ?? DateTime.now().year;
  final selMonth = parts.length > 1 ? int.tryParse(parts[1]) ?? 1 : 1;
  final selYear = year;
  final minParts = (minMonth ?? '1900-01').split('-');
  final minYear = int.tryParse(minParts[0]) ?? 1900;
  final minM = int.tryParse(minParts.length > 1 ? minParts[1] : '1') ?? 1;
  final maxYear = DateTime.now().year + 1;
  return showModalBottomSheet<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSt) {
        final t = ctx.tokens;
        final hi = ctx.lang == AppLang.hi;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: year > minYear ? () => setSt(() => year--) : null,
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Expanded(child: Center(child: Text('$year', style: AppText.sectionTitle(ctx).copyWith(fontSize: 16)))),
                    IconButton(
                      onPressed: year < maxYear ? () => setSt(() => year++) : null,
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                GridView.count(
                  crossAxisCount: 4,
                  shrinkWrap: true,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 2.2,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    for (var m = 1; m <= 12; m++)
                      Builder(builder: (_) {
                        final disabled = year < minYear || (year == minYear && m < minM);
                        final selected = year == selYear && m == selMonth;
                        return Opacity(
                          opacity: disabled ? 0.35 : 1,
                          child: Material(
                            color: selected ? t.primary : t.secondary,
                            borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                              onTap: disabled ? null : () => Navigator.pop(ctx, '$year-${pad2(m)}'),
                              child: Center(
                                child: Text(
                                  hi ? _monthsHi[m - 1] : _monthsEn[m - 1],
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: selected ? t.primaryForeground : t.secondaryForeground,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

/// Date field (web `DateInput`): shows `dd/MM/yyyy`, emits `yyyy-MM-dd`.
class ReportDateField extends StatelessWidget {
  const ReportDateField({super.key, required this.label, required this.value, required this.onChanged});

  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  Future<void> _pick(BuildContext context) async {
    final initial = DateTime.tryParse(value) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) onChanged(ymdOf(picked));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(label, style: AppText.tiny(context))),
        Material(
          color: t.input,
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppTokens.radiusSm),
            onTap: () => _pick(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                border: Border.all(color: t.border),
              ),
              child: Row(
                children: [
                  Expanded(child: Text(fmtIsoDateToDisplay(value), style: AppText.body(context))),
                  Icon(Icons.calendar_today_outlined, size: 16, color: t.mutedForeground),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Small coloured status chip (web `text-[10px] px-1.5 py-0.5 rounded-full`).
class MiniStatusChip extends StatelessWidget {
  const MiniStatusChip(this.label, {super.key, required this.color, this.capitalize = true});

  final String label;
  final Color color;
  final bool capitalize;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: AppTokens.tint(color, 0.15), borderRadius: BorderRadius.circular(999)),
        child: Text(capitalize ? capitalizeWords(label) : label,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: color)),
      );
}

/// Status colour used across report lists.
Color reportStatusColor(BuildContext context, String? status) {
  final t = context.tokens;
  switch (status) {
    case 'verified':
    case 'paid':
    case 'settled':
    case 'receipt':
      return t.success;
    case 'pending':
      return t.warning;
    case 'expense':
      return t.destructive;
    default:
      return t.mutedForeground;
  }
}
