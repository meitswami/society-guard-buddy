import 'package:flutter/material.dart';

import '../../../../core/ui/ui.dart';
import '../logic/flat_options.dart';
import 'ev_i18n.dart';

/// Port of `src/components/FlatMultiSelect.tsx`: search, "All visible" / "Clear visible",
/// grid of flat buttons with the primary member / owner name underneath.
class FlatMultiSelect extends StatefulWidget {
  const FlatMultiSelect({
    super.key,
    required this.flats,
    required this.selected,
    required this.onChanged,
    this.label,
    this.compact = false,
    this.emptyHint,
    this.selectedBadgeByFlat = const {},
  });

  final List<FlatOption> flats;
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;
  final String? label;
  final bool compact;
  final String? emptyHint;
  final Map<String, String> selectedBadgeByFlat;

  @override
  State<FlatMultiSelect> createState() => _FlatMultiSelectState();
}

class _FlatMultiSelectState extends State<FlatMultiSelect> {
  String _q = '';

  List<FlatOption> get _filtered {
    final s = _q.trim().toLowerCase();
    if (s.isEmpty) return widget.flats;
    return [
      for (final f in widget.flats)
        if (f.flatNumber.toLowerCase().contains(s) || (f.subtitle?.toLowerCase().contains(s) ?? false)) f,
    ];
  }

  void _toggle(String fn) {
    final on = widget.selected.contains(fn);
    widget.onChanged(on ? [for (final x in widget.selected) if (x != fn) x] : [...widget.selected, fn]);
  }

  void _selectAllFiltered(List<FlatOption> filtered) {
    final merged = <String>[...widget.selected];
    for (final f in filtered) {
      if (!merged.contains(f.flatNumber)) merged.add(f.flatNumber);
    }
    widget.onChanged(merged);
  }

  void _clearFiltered(List<FlatOption> filtered) {
    final nums = {for (final f in filtered) f.flatNumber};
    widget.onChanged([for (final x in widget.selected) if (!nums.contains(x)) x]);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final filtered = _filtered;
    final label = widget.label ?? context.ev('fms.flats');
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
                context.ev('fms.labelCount', {'label': label, 'n': widget.selected.length}),
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: t.mutedForeground),
              ),
              if (filtered.isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _MiniLink(text: context.ev('fms.allVisible'), color: t.primary, onTap: () => _selectAllFiltered(filtered)),
                    Text('  ·  ', style: TextStyle(fontSize: 10, color: t.mutedForeground)),
                    _MiniLink(text: context.ev('fms.clearVisible'), color: t.mutedForeground, onTap: () => _clearFiltered(filtered)),
                  ],
                ),
            ],
          ),
        ),
        TextField(
          onChanged: (v) => setState(() => _q = v),
          style: TextStyle(fontSize: 14, color: t.foreground),
          decoration: InputDecoration(
            isDense: true,
            hintText: context.ev('fms.search'),
            prefixIcon: Icon(Icons.search, size: 18, color: t.mutedForeground),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 192),
          child: filtered.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(widget.emptyHint ?? context.ev('fms.noMatch'), style: TextStyle(fontSize: 12, color: t.mutedForeground)),
                )
              : GridView.builder(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: filtered.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: widget.compact ? 3 : 2,
                    mainAxisSpacing: widget.compact ? 4 : 6,
                    crossAxisSpacing: widget.compact ? 4 : 6,
                    mainAxisExtent: widget.compact ? 46 : 54,
                  ),
                  itemBuilder: (context, i) {
                    final f = filtered[i];
                    final on = widget.selected.contains(f.flatNumber);
                    final badge = widget.selectedBadgeByFlat[f.flatNumber];
                    final fg = on ? t.primaryForeground : t.foreground;
                    final radius = BorderRadius.circular(widget.compact ? 4 : AppTokens.radiusSm);
                    return Material(
                      color: on ? t.primary : t.card,
                      shape: RoundedRectangleBorder(borderRadius: radius, side: BorderSide(color: on ? t.primary : t.border)),
                      child: InkWell(
                        borderRadius: radius,
                        onTap: () => _toggle(f.flatNumber),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(f.flatNumber, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.mono(context, size: 12, weight: FontWeight.w600, color: fg)),
                              if (on && badge != null)
                                Text(badge, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w500, color: fg)),
                              if (f.subtitle != null)
                                Text(
                                  f.subtitle!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 9, height: 1.15, color: on ? AppTokens.tint(t.primaryForeground, 0.9) : t.mutedForeground),
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

class _MiniLink extends StatelessWidget {
  const _MiniLink({required this.text, required this.color, required this.onTap});

  final String text;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Text(
          text,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: color, decoration: TextDecoration.underline, decorationColor: color),
        ),
      );
}
