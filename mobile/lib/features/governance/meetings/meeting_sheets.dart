import 'package:flutter/material.dart';
import 'package:signature/signature.dart';

import '../../../core/ui/ui.dart';
import '../logic/meeting_logic.dart';
import '../models/meeting_models.dart';
import '../widgets/gov_widgets.dart';

/// "Add flat members" table picker (web member picker dialog).
/// Returns the selected member ids (not already on the list), or null when cancelled.
Future<List<String>?> showMemberPickerSheet(
  BuildContext context, {
  required List<MemberPick> members,
  required Set<String> onListMemberIds,
}) {
  final sorted = [...members]..sort((a, b) => compareMemberPick(a.flatNumber, a.name, b.flatNumber, b.name));
  final eligible = sorted.where((m) => !onListMemberIds.contains(m.id)).map((m) => m.id).toList();
  final selection = <String>{};
  return showGovSheet<List<String>>(
    context,
    title: context.tr('Add flat members', 'फ्लैट सदस्य जोड़ें'),
    description: context.tr(
        'Select one or more residents in the table, then add them to this meeting’s attendance list as present.',
        'तालिका में एक या अधिक निवासी चुनें, फिर उन्हें इस बैठक की उपस्थिति सूची में उपस्थित के रूप में जोड़ें।'),
    builder: (ctx, setState) {
      final t = ctx.tokens;
      final allOn = eligible.isNotEmpty && eligible.every(selection.contains);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              MiniButton(
                label: allOn ? ctx.tr('Deselect all (new)', 'सभी हटाएँ (नए)') : ctx.tr('Select all not on list', 'सूची से बाहर सभी चुनें'),
                fontSize: 11,
                onPressed: () => setState(() {
                  if (allOn) {
                    selection.removeAll(eligible);
                  } else {
                    selection.addAll(eligible);
                  }
                }),
              ),
              MiniButton(
                label: ctx.tr('Clear selection', 'चयन साफ़ करें'),
                fontSize: 11,
                onPressed: () => setState(selection.clear),
              ),
              Text(ctx.tr('${selection.length} selected', '${selection.length} चयनित'), style: AppText.caption(ctx)),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            color: AppTokens.tint(t.muted, 0.5),
            child: Row(
              children: [
                const SizedBox(width: 36),
                SizedBox(width: 64, child: Text(ctx.tr('Flat', 'फ्लैट'), style: AppText.fieldLabel(ctx))),
                Expanded(child: Text(ctx.tr('Member', 'सदस्य'), style: AppText.fieldLabel(ctx))),
                SizedBox(width: 90, child: Text(ctx.tr('List', 'सूची'), style: AppText.fieldLabel(ctx))),
              ],
            ),
          ),
          if (sorted.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(ctx.tr('No society members loaded.', 'कोई सोसायटी सदस्य लोड नहीं।'),
                  textAlign: TextAlign.center, style: AppText.caption(ctx)),
            ),
          for (final m in sorted)
            Builder(builder: (_) {
              final onList = onListMemberIds.contains(m.id);
              return InkWell(
                onTap: onList
                    ? null
                    : () => setState(() => selection.contains(m.id) ? selection.remove(m.id) : selection.add(m.id)),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppTokens.tint(t.border, 0.8)))),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 36,
                        child: Checkbox(
                          value: onList || selection.contains(m.id),
                          onChanged: onList
                              ? null
                              : (_) => setState(() => selection.contains(m.id) ? selection.remove(m.id) : selection.add(m.id)),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      SizedBox(width: 64, child: Text(m.flatNumber, style: AppText.bodyMedium(ctx).copyWith(fontSize: 12))),
                      Expanded(
                        child: Row(
                          children: [
                            PersonAvatar(name: m.name, photo: m.photo, size: AvatarSize.xs),
                            const SizedBox(width: 6),
                            Expanded(child: Text(m.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 90,
                        child: Text(onList ? ctx.tr('Already added', 'पहले से जोड़ा') : '—', style: AppText.caption(ctx)),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      );
    },
    footer: (ctx, setState) => [
      AppButton.secondary(label: ctx.tr('Cancel', 'रद्द करें'), onPressed: () => Navigator.of(ctx).pop()),
      AppButton(
        label: ctx.tr('Add selected to attendance', 'चयनित को उपस्थिति में जोड़ें'),
        onPressed: () => Navigator.of(ctx).pop(selection.toList()),
      ),
    ],
  );
}

/// Result of the signature dialog.
class SignatureCapture {
  const SignatureCapture({required this.png, required this.signerLabel});

  final List<int> png;
  final String signerLabel;
}

/// Signature dialog (web `SignaturePad` + printed name). The pad is a paper-like
/// white surface with dark ink in both themes because it is exported as a PNG.
Future<SignatureCapture?> showSignatureSheet(
  BuildContext context, {
  required String documentTitle,
  required String attendeeName,
}) async {
  final label = TextEditingController(text: attendeeName);
  final pad = SignatureController(
    penStrokeWidth: 2,
    penColor: const Color(0xFF111111),
    strokeCap: StrokeCap.round,
    exportBackgroundColor: const Color(0xFFFFFFFF),
  );
  final result = await showGovSheet<SignatureCapture>(
    context,
    title: '${context.tr('Signature', 'हस्ताक्षर')} — $documentTitle',
    description: context.tr('For $attendeeName. Collect on one device at the table if needed.',
        '$attendeeName के लिए। आवश्यकता हो तो मेज़ पर एक ही उपकरण पर लें।'),
    builder: (ctx, setState) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField(controller: label, label: ctx.tr('Printed name (optional)', 'मुद्रित नाम (वैकल्पिक)'), caps: false),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: DecoratedBox(
            decoration: BoxDecoration(border: Border.all(color: ctx.tokens.border)),
            child: Signature(controller: pad, height: 160, backgroundColor: const Color(0xFFFFFFFF)),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: MiniButton(label: ctx.tr('Clear pad', 'पैड साफ़ करें'), variant: MiniVariant.secondary, onPressed: pad.clear),
        ),
      ],
    ),
    footer: (ctx, setState) => [
      AppButton.secondary(label: ctx.tr('Cancel', 'रद्द करें'), onPressed: () => Navigator.of(ctx).pop()),
      AppButton(
        label: ctx.tr('Save signature', 'हस्ताक्षर सहेजें'),
        onPressed: () async {
          final png = await pad.toPngBytes();
          if (!ctx.mounted) return;
          if (png == null || pad.isEmpty) {
            GovToast.error(ctx, ctx.tr('Could not read signature', 'हस्ताक्षर पढ़ा नहीं जा सका'));
            return;
          }
          Navigator.of(ctx).pop(SignatureCapture(png: png, signerLabel: label.text));
        },
      ),
    ],
  );
  Future<void>.delayed(const Duration(milliseconds: 600), () {
    label.dispose();
    pad.dispose();
  });
  return result;
}
