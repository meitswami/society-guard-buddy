import 'package:flutter/material.dart';

import '../../../core/ui/ui.dart';
import '../gate_i18n.dart';

class FlatOption {
  const FlatOption({required this.id, required this.flatNumber, this.subtitle});

  final String id;
  final String flatNumber;

  /// Shown under the flat number (primary member or owner).
  final String? subtitle;
}

/// Web `FlatMultiSelect`: searchable grid of flat toggles with "All visible" / "Clear visible".
class FlatMultiSelect extends StatefulWidget {
  const FlatMultiSelect({super.key, required this.flats, required this.selected, required this.onChanged, this.label});

  final List<FlatOption> flats;

  /// Selected flat numbers.
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;
  final String? label;

  @override
  State<FlatMultiSelect> createState() => _FlatMultiSelectState();
}

class _FlatMultiSelectState extends State<FlatMultiSelect> {
  String _q = '';

  List<FlatOption> get _filtered {
    final s = _q.trim().toLowerCase();
    if (s.isEmpty) return widget.flats;
    return widget.flats
        .where((f) => f.flatNumber.toLowerCase().contains(s) || (f.subtitle ?? '').toLowerCase().contains(s))
        .toList();
  }

  void _toggle(String num) {
    final on = widget.selected.contains(num);
    widget.onChanged(on ? widget.selected.where((x) => x != num).toList() : [...widget.selected, num]);
  }

  void _selectAll(List<FlatOption> filtered) {
    final merged = <String>{...widget.selected, ...filtered.map((f) => f.flatNumber)};
    widget.onChanged(merged.toList());
  }

  void _clear(List<FlatOption> filtered) {
    final nums = filtered.map((f) => f.flatNumber).toSet();
    widget.onChanged(widget.selected.where((x) => !nums.contains(x)).toList());
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final filtered = _filtered;
    final label = widget.label ?? context.tr('Flats', 'फ्लैट');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(
                context.gt('gate.flats.selected', {'label': label, 'count': widget.selected.length}),
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: t.mutedForeground),
              ),
              if (filtered.isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _LinkText(context.gt('gate.flats.allVisible'), color: t.primary, onTap: () => _selectAll(filtered)),
                    Text(' · ', style: AppText.tiny(context)),
                    _LinkText(context.gt('gate.flats.clearVisible'), color: t.mutedForeground, onTap: () => _clear(filtered)),
                  ],
                ),
            ],
          ),
        ),
        AppTextField(
          hint: context.gt('gate.flats.search'),
          caps: false,
          prefixIcon: Icons.search,
          onChanged: (v) => setState(() => _q = v),
        ),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 192),
          child: filtered.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(context.gt('gate.flats.empty'), style: AppText.caption(context)),
                )
              : GridView.builder(
                  shrinkWrap: true,
                  primary: false,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                    mainAxisExtent: 54,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final f = filtered[i];
                    final on = widget.selected.contains(f.flatNumber);
                    return Material(
                      color: on ? t.primary : t.card,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                        side: BorderSide(color: on ? t.primary : t.border),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                        onTap: () => _toggle(f.flatNumber),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                f.flatNumber,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.mono(context,
                                    size: 12, weight: FontWeight.w600, color: on ? t.primaryForeground : t.foreground),
                              ),
                              if (f.subtitle != null && f.subtitle!.isNotEmpty)
                                Text(
                                  f.subtitle!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 9,
                                    height: 1.15,
                                    color: on ? AppTokens.tint(t.primaryForeground, 0.9) : t.mutedForeground,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _LinkText extends StatelessWidget {
  const _LinkText(this.text, {required this.color, required this.onTap});

  final String text;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: color,
          decoration: TextDecoration.underline,
          decorationColor: color,
        ),
      ),
    );
  }
}
