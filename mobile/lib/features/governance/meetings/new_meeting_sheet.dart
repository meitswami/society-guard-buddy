import 'package:flutter/material.dart';

import '../../../core/ui/ui.dart';
import '../data/gov_backend.dart';
import '../data/meeting_repository.dart';
import '../logic/meeting_logic.dart';
import '../models/meeting_models.dart';
import '../widgets/gov_widgets.dart';

/// "New meeting notice" dialog of web `MeetingManager` → bottom sheet.
/// Returns the created meeting (or null when cancelled).
Future<MeetingRow?> showNewMeetingSheet(
  BuildContext context, {
  required MeetingRepository repo,
  required String societyId,
  required String adminName,
}) async {
  final title = TextEditingController();
  final purpose = TextEditingController();
  final location = TextEditingController();
  final agenda = TextEditingController();
  final nowIso = DateTime.now().toIso8601String();
  var date = toDateInput(nowIso);
  var time = toTimeInput(nowIso);
  var kind = MeetingKind.generalBody;
  var notify = true;
  var whatsapp = false;
  var email = false;
  var busy = false;
  final hi = context.lang == AppLang.hi;

  Future<void> create(BuildContext ctx, StateSetter setState) async {
    if (date.isEmpty || time.isEmpty) {
      GovToast.error(
          ctx, ctx.tr('Date and time are required', 'तिथि और समय आवश्यक हैं'));
      return;
    }
    if (location.text.trim().isEmpty) {
      GovToast.error(ctx, ctx.tr('Venue is required', 'स्थान आवश्यक है'));
      return;
    }
    if (purpose.text.trim().isEmpty) {
      GovToast.error(ctx, ctx.tr('Purpose is required', 'उद्देश्य आवश्यक है'));
      return;
    }
    setState(() => busy = true);
    try {
      final titleText =
          title.text.trim().isEmpty ? kind.labelEn : title.text.trim();
      final meetingAt = combineDateAndTimeToIso(date, time);
      final purposeText = purpose.text.trim();
      final venue = location.text.trim();
      final created = await repo.createMeeting(
        title: titleText,
        description: purposeText,
        kind: kind,
        location: venue,
        meetingAt: meetingAt,
        published: notify,
        createdBy: adminName,
      );
      final lines = parseAgendaLines(agenda.text);
      if (lines.isNotEmpty) {
        try {
          await repo.insertAgendaItems([
            for (final (i, l) in lines.indexed)
              {
                'meeting_id': created.id,
                'title': l,
                'sort_order': i,
                'source': 'admin',
                'status': 'accepted'
              },
          ]);
        } catch (e) {
          if (ctx.mounted) GovToast.error(ctx, GovBackend.errorText(e));
        }
      }
      if (notify) {
        await GovBackend.notifyResidentsOfMeeting(
          societyId: societyId,
          createdBy: adminName,
          title: 'Meeting notice: $titleText',
          body: meetingCreateNoticeBody(
              purpose: purposeText,
              when: Fmt.dateTimeFull(meetingAt),
              venue: venue),
          whatsapp: whatsapp,
          email: email,
        );
        if (ctx.mounted) {
          GovToast.ok(
              ctx,
              ctx.tr('Meeting created, published, and residents notified',
                  'बैठक बनी, प्रकाशित हुई और निवासियों को सूचित किया गया'));
        }
      } else if (ctx.mounted) {
        GovToast.ok(
            ctx,
            ctx.tr(
                'Meeting created as draft — publish when ready to notify residents',
                'बैठक ड्राफ़्ट के रूप में बनी — तैयार होने पर प्रकाशित करें'));
      }
      if (ctx.mounted) Navigator.of(ctx).pop(created);
    } catch (e) {
      if (ctx.mounted) GovToast.error(ctx, GovBackend.errorText(e));
      setState(() => busy = false);
    }
  }

  final result = await showGovSheet<MeetingRow>(
    context,
    title: context.tr('New meeting notice', 'नई बैठक सूचना'),
    description: context.tr(
        'Enter only what residents need before the meeting. Session tools (attendance, minutes, recording) unlock on the meeting day.',
        'बैठक से पहले निवासियों को जो चाहिए वही दर्ज करें। सत्र उपकरण (उपस्थिति, कार्यवृत्त, रिकॉर्डिंग) बैठक के दिन खुलते हैं।'),
    builder: (ctx, setState) {
      final t = ctx.tokens;
      const gap = SizedBox(height: 12);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppDropdown<MeetingKind>(
            label: ctx.tr('Meeting type', 'बैठक प्रकार'),
            items: MeetingKind.values,
            value: kind,
            labelOf: (k) => k.label(hi),
            onChanged: (v) =>
                setState(() => kind = v ?? MeetingKind.generalBody),
          ),
          gap,
          AppTextField(
            controller: title,
            label:
                ctx.tr('Short title (optional)', 'संक्षिप्त शीर्षक (वैकल्पिक)'),
            hint: ctx.tr(
                'Defaults to meeting type name', 'डिफ़ॉल्ट बैठक प्रकार का नाम'),
            caps: false,
          ),
          gap,
          AppTextField(
            controller: purpose,
            label: ctx.tr('Purpose', 'उद्देश्य'),
            required: true,
            hint: ctx.tr('Why this meeting is being called',
                'यह बैठक क्यों बुलाई जा रही है'),
            maxLines: 4,
            minLines: 3,
            caps: false,
          ),
          gap,
          Row(
            children: [
              Expanded(
                child: GovDateField(
                  label: ctx.tr('Date', 'तिथि'),
                  required: true,
                  value: date,
                  clearable: false,
                  onChanged: (v) => setState(() => date = v),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GovTimeField(
                  label: ctx.tr('Time', 'समय'),
                  required: true,
                  value: time,
                  onChanged: (v) => setState(() => time = v),
                ),
              ),
            ],
          ),
          gap,
          AppTextField(
            controller: location,
            label: ctx.tr('Venue', 'स्थान'),
            required: true,
            hint: ctx.tr('Club house hall', 'क्लब हाउस हॉल'),
            caps: false,
          ),
          gap,
          AppTextField(
            controller: agenda,
            label: ctx.tr('Agenda issues', 'कार्यसूची के विषय'),
            hint: ctx.tr(
                'One issue per line, e.g.\nMaintenance arrears\nParking allocation\nAGM date',
                'प्रति पंक्ति एक विषय, जैसे\nरखरखाव बकाया\nपार्किंग आवंटन\nवार्षिक सभा तिथि'),
            maxLines: 5,
            minLines: 4,
            caps: false,
          ),
          const SizedBox(height: 8),
          Text(
            ctx.tr(
                'After create, attach PDF/images on the meeting record. You can edit the notice after publishing.',
                'बनाने के बाद बैठक अभिलेख पर PDF/चित्र संलग्न करें। प्रकाशन के बाद भी सूचना संपादित कर सकते हैं।'),
            style: AppText.tiny(ctx).copyWith(fontSize: 11),
          ),
          gap,
          TintBox(
            color: t.primary,
            padding: const EdgeInsets.all(8),
            child: CheckRow(
              value: notify,
              onChanged: (v) => setState(() => notify = v),
              label: ctx.tr('Bring to notice of residents',
                  'निवासियों के संज्ञान में लाएँ'),
              subtitle: ctx.tr(
                  'Publish immediately and send in-app + push notification with date, time, venue, and purpose.',
                  'तुरंत प्रकाशित करें और तिथि, समय, स्थान व उद्देश्य सहित इन-ऐप + पुश सूचना भेजें।'),
            ),
          ),
          if (notify) ...[
            const SizedBox(height: 6),
            CheckRow(
              value: whatsapp,
              onChanged: (v) => setState(() => whatsapp = v),
              label: ctx.tr('Also WhatsApp directory contacts',
                  'निर्देशिका संपर्कों को व्हाट्सऐप भी करें'),
            ),
            CheckRow(
              value: email,
              onChanged: (v) => setState(() => email = v),
              label: ctx.tr('Also email directory contacts',
                  'निर्देशिका संपर्कों को ईमेल भी करें'),
            ),
          ],
        ],
      );
    },
    footer: (ctx, setState) => [
      AppButton.secondary(
          label: ctx.tr('Cancel', 'रद्द करें'),
          onPressed: () => Navigator.of(ctx).pop()),
      AppButton(
        label: notify
            ? ctx.tr('Create & notify', 'बनाएँ व सूचित करें')
            : ctx.tr('Create draft', 'ड्राफ़्ट बनाएँ'),
        loading: busy,
        onPressed: () => create(ctx, setState),
      ),
    ],
  );
  // Let the sheet finish its closing animation before releasing the controllers.
  Future<void>.delayed(const Duration(milliseconds: 600), () {
    for (final c in [title, purpose, location, agenda]) {
      c.dispose();
    }
  });
  return result;
}
