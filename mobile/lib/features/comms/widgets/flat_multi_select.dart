import 'package:flutter/material.dart';

import '../../../core/ui/ui.dart';
import '../core/comms_i18n.dart';
import '../data/flat_options.dart';
import 'comms_ui.dart';

/// Port of web `FlatMultiSelect` (compact grid of flat buttons with search,
/// "All visible" / "Clear visible").
class FlatMultiSelect extends StatefulWidget {
  const FlatMultiSelect({
    super.key,
    required this.flats,
    required this.selected,
    required this.onChanged,
    this.label,
    this.compact = true,
  });

  final List<FlatOption> flats;
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;
  final String? label;
  final bool compact;

  @override
  State<FlatMultiSelect> createState() => _FlatMultiSelectState();
}

class _FlatMultiSelectState extends State<FlatMultiSelect> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final filtered = filterFlatOptions(widget.flats, _q);
    final label = widget.label ?? context.ct('comms.notif.selectFlats');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                context.ct('comms.flats.selected', {'label': label, 'count': widget.selected.length}),
                style: AppText.caption(context).copyWith(fontWeight: FontWeight.w500),
              ),
            ),
            if (filtered.isNotEmpty) ...[
              LinkText(context.ct('comms.flats.allVisible'),
                  onTap: () => widget.onChanged(selectAllVisible(widget.selected, filtered))),
              Text(' · ', style: AppText.tiny(context)),
              LinkText(context.ct('comms.flats.clearVisible'),
                  color: t.mutedForeground, onTap: () => widget.onChanged(clearVisible(widget.selected, filtered))),
            ],
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          onChanged: (v) => setState(() => _q = v),
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            isDense: true,
            hintText: context.ct('comms.flats.search'),
            prefixIcon: Icon(Icons.search, size: 18, color: t.mutedForeground),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 192,
          child: filtered.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(context.ct('comms.flats.empty'), style: AppText.caption(context)),
                )
              : GridView.builder(
                  itemCount: filtered.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: widget.compact ? 3 : 2,
                    mainAxisSpacing: 4,
                    crossAxisSpacing: 4,
                    mainAxisExtent: 52,
                  ),
                  itemBuilder: (context, i) {
                    final f = filtered[i];
                    final on = widget.selected.contains(f.flatNumber);
                    return Material(
                      color: on ? t.primary : t.card,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                        side: BorderSide(color: on ? t.primary : t.border),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(6),
                        onTap: () => widget.onChanged(toggleFlat(widget.selected, f.flatNumber)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                f.flatNumber,
                                style: AppText.mono(context,
                                    size: 12, weight: FontWeight.w600, color: on ? t.primaryForeground : t.foreground),
                              ),
                              if (f.subtitle != null)
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
