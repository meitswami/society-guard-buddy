import 'package:flutter/material.dart';

import '../../../../core/ui/ui.dart';

/// `<input type="month" min=…>` replacement: bottom sheet with a year stepper and a 12-month grid.
Future<String?> showMonthPicker(BuildContext context,
    {required String initial, String? min, String? max}) {
  return showModalBottomSheet<String>(
    context: context,
    builder: (ctx) => _MonthPickerSheet(initial: initial, min: min, max: max),
  );
}

class _MonthPickerSheet extends StatefulWidget {
  const _MonthPickerSheet({required this.initial, this.min, this.max});

  final String initial;
  final String? min;
  final String? max;

  @override
  State<_MonthPickerSheet> createState() => _MonthPickerSheetState();
}

class _MonthPickerSheetState extends State<_MonthPickerSheet> {
  late int _year;

  static const _en = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];
  static const _hi = [
    'जन',
    'फ़र',
    'मार्च',
    'अप्रै',
    'मई',
    'जून',
    'जुला',
    'अग',
    'सित',
    'अक्टू',
    'नव',
    'दिस'
  ];

  @override
  void initState() {
    super.initState();
    _year =
        int.tryParse(widget.initial.split('-').first) ?? DateTime.now().year;
  }

  String _ym(int m) => '$_year-${m.toString().padLeft(2, '0')}';

  bool _enabled(String ym) =>
      (widget.min == null || ym.compareTo(widget.min!) >= 0) &&
      (widget.max == null || ym.compareTo(widget.max!) <= 0);

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final minYear =
        widget.min == null ? 2000 : int.parse(widget.min!.substring(0, 4));
    final maxYear = widget.max == null
        ? DateTime.now().year + 5
        : int.parse(widget.max!.substring(0, 4));
    final names = context.lang == AppLang.hi ? _hi : _en;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconButton(
                    onPressed:
                        _year > minYear ? () => setState(() => _year--) : null,
                    icon: const Icon(Icons.chevron_left)),
                Expanded(
                    child: Text('$_year',
                        textAlign: TextAlign.center,
                        style: AppText.pageTitle(context))),
                IconButton(
                    onPressed:
                        _year < maxYear ? () => setState(() => _year++) : null,
                    icon: const Icon(Icons.chevron_right)),
              ],
            ),
            const SizedBox(height: 8),
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2,
              children: [
                for (var m = 1; m <= 12; m++)
                  Builder(builder: (_) {
                    final ym = _ym(m);
                    final selected = ym == widget.initial;
                    final enabled = _enabled(ym);
                    return Material(
                      color: selected ? t.primary : t.secondary,
                      borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                        onTap:
                            enabled ? () => Navigator.pop(context, ym) : null,
                        child: Center(
                          child: Text(
                            names[m - 1],
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: !enabled
                                  ? AppTokens.tint(t.mutedForeground, 0.4)
                                  : selected
                                      ? t.primaryForeground
                                      : t.secondaryForeground,
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
  }
}
