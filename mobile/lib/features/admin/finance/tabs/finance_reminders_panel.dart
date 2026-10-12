// Port of FinanceRemindersTab + FinanceManager's sendReminders / saveAutoReminderSettings /
// testAutoReminderNow / issueMonthlyBillNow.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/ui/ui.dart';
import '../data/finance_repository.dart';
import '../logic/finance_dates.dart';
import '../logic/finance_format.dart';
import '../state/finance_controller.dart';
import '../widgets/fin_kit.dart';
import '../widgets/finance_widgets.dart';

class FinanceRemindersPanel extends StatefulWidget {
  const FinanceRemindersPanel({super.key, required this.c, required this.includeVacant, required this.onIncludeVacantChanged});

  final FinanceController c;
  final bool includeVacant;
  final ValueChanged<bool> onIncludeVacantChanged;

  @override
  State<FinanceRemindersPanel> createState() => _FinanceRemindersPanelState();
}

class _FinanceRemindersPanelState extends State<FinanceRemindersPanel> {
  FinanceController get c => widget.c;
  bool _saving = false;
  bool _testing = false;
  bool _issuing = false;
  bool _sending = false;
  String _lastTest = '';
  String _lastBill = '';
  late final _dueDay = TextEditingController(text: '${c.settings.dueDay}');
  final _dueDayFocus = FocusNode();

  @override
  void dispose() {
    _dueDay.dispose();
    _dueDayFocus.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await c.repo.upsertReminderSettings(c.societyId, c.settings);
      await c.invalidateAll();
      if (mounted) AppFeedback.toast(context, context.tr('Auto reminder / bill settings saved', 'स्वतः अनुस्मारक / बिल सेटिंग सहेजी गई'), tone: BadgeTone.success);
    } catch (e) {
      if (mounted) AppFeedback.toast(context, financeErrorMessage(e, 'Could not save settings'), tone: BadgeTone.alert);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _test() async {
    setState(() => _testing = true);
    try {
      final sent = await c.repo.invokeReminderTest(c.societyId);
      if (!mounted) return;
      AppFeedback.toast(
        context,
        sent > 0
            ? context.tr('Test reminder sent to $sent flat(s)', '$sent फ्लैटों को परीक्षण अनुस्मारक भेजा')
            : context.tr('No pending dues found for test run', 'परीक्षण के लिए कोई बकाया नहीं मिला'),
        tone: BadgeTone.success,
      );
      setState(() => _lastTest = context.tr('Last test at ${fmtTimeLocal(DateTime.now())}: sent to $sent flat(s)',
          'पिछला परीक्षण ${fmtTimeLocal(DateTime.now())}: $sent फ्लैटों को भेजा'));
    } catch (e) {
      final detail = financeErrorMessage(e, 'Unknown function error');
      final generic = detail.contains('non-2xx') || detail.contains('FunctionsHttpError') || detail == 'Unknown function error';
      if (!mounted) return;
      AppFeedback.toast(context, generic ? context.tr('Reminder test failed. Check edge function logs.', 'अनुस्मारक परीक्षण विफल। एज फ़ंक्शन लॉग देखें।') : detail,
          tone: BadgeTone.alert);
      setState(() => _lastTest = context.tr('Last test failed: $detail', 'पिछला परीक्षण विफल: $detail'));
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _issue() async {
    setState(() => _issuing = true);
    try {
      final r = await c.repo.invokeIssueMonthlyBill(c.societyId);
      await c.invalidateAll();
      if (!mounted) return;
      final title = (r.chargeTitle ?? '').isEmpty ? 'Monthly Maintenance' : r.chargeTitle!;
      final amount = r.amount ?? 2500;
      final waFail = r.whatsappFailed ?? 0;
      final msg = r.issued > 0
          ? context.tr(
              'Issued $title (${inrLocale(amount)}) to ${r.flats ?? 0} flat(s); WhatsApp sent ${r.whatsappSent ?? 0}${waFail > 0 ? ', failed $waFail' : ''}',
              '$title (${inrLocale(amount)}) ${r.flats ?? 0} फ्लैटों को जारी; व्हाट्सऐप भेजे ${r.whatsappSent ?? 0}${waFail > 0 ? ', विफल $waFail' : ''}')
          : (r.note ?? '').isNotEmpty
              ? context.tr('Skipped: ${r.note}', 'छोड़ा गया: ${r.note}')
              : context.tr('No bills issued', 'कोई बिल जारी नहीं हुआ');
      AppFeedback.toast(context, msg, tone: BadgeTone.success);
      setState(() => _lastBill = context.tr('Last run at ${fmtTimeLocal(DateTime.now())}: $msg', 'पिछला रन ${fmtTimeLocal(DateTime.now())}: $msg'));
      if (r.whatsappConfigured == false) {
        await Future<void>.delayed(const Duration(milliseconds: 1500));
        if (mounted) {
          AppFeedback.toast(
            context,
            context.tr('WhatsApp not configured — set WHATSAPP_ACCESS_TOKEN and WHATSAPP_PHONE_NUMBER_ID secrets',
                'व्हाट्सऐप सेट नहीं — WHATSAPP_ACCESS_TOKEN और WHATSAPP_PHONE_NUMBER_ID सीक्रेट सेट करें'),
            tone: BadgeTone.warning,
          );
        }
      }
    } catch (e) {
      final detail = financeErrorMessage(e, 'Unknown function error');
      if (!mounted) return;
      AppFeedback.toast(context, detail, tone: BadgeTone.alert);
      setState(() => _lastBill = context.tr('Last run failed: $detail', 'पिछला रन विफल: $detail'));
    } finally {
      if (mounted) setState(() => _issuing = false);
    }
  }

  Future<void> _sendReminders(List<String> flats) async {
    setState(() => _sending = true);
    try {
      await c.repo.sendMaintenanceReminders(c.societyId, c.adminName, flats);
      await c.invalidateAll();
      if (mounted) AppFeedback.toast(context, context.tr('Reminders sent to ${flats.length} flats', '${flats.length} फ्लैटों को अनुस्मारक भेजे'), tone: BadgeTone.success);
    } catch (e) {
      if (mounted) AppFeedback.toast(context, financeErrorMessage(e, 'Could not send reminders'), tone: BadgeTone.alert);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final t = context.tokens;
        final s = c.settings;
        if (_dueDay.text != '${s.dueDay}' && !_dueDayFocus.hasFocus) _dueDay.text = '${s.dueDay}';
        final derived = c.derived;
        final unpaid = derived.unpaidFlats(includeVacant: widget.includeVacant);
        final rows = derived.unpaidReminderRows(includeVacant: widget.includeVacant);
        final total = c.data.flats.length;
        final target = derived.targetFlatCount(includeVacant: widget.includeVacant);
        const gap = SizedBox(height: 8);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CardSection(
              margin: const EdgeInsets.only(bottom: 16),
              color: Color.alphaBlend(AppTokens.tint(t.success, 0.05), t.card),
              borderColor: AppTokens.tint(t.success, 0.2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SectionTitle(context.tr('Monthly maintenance bill (₹2,500)', 'मासिक रखरखाव बिल (₹2,500)'),
                      icon: Icons.warning_amber_rounded, iconColor: t.success),
                  Text(
                    context.tr(
                      "On the 1st of each month, create the month's maintenance charge and notify every member on their profile WhatsApp number, with a musical tone in the app notification.",
                      'हर माह की 1 तारीख को उस माह का रखरखाव शुल्क बनाएँ और हर सदस्य को उनके प्रोफ़ाइल व्हाट्सऐप नंबर पर सूचित करें, ऐप सूचना में संगीतमय धुन के साथ।',
                    ),
                    style: AppText.caption(context),
                  ),
                  gap,
                  FinCheckRow(
                    value: s.autoIssueEnabled,
                    label: context.tr('Auto-issue on 1st of every month (09:00 Asia/Kolkata)', 'हर माह 1 तारीख को स्वतः जारी करें (09:00 एशिया/कोलकाता)'),
                    onChanged: (v) => c.updateSettings(s.copyWith(autoIssueEnabled: v)),
                  ),
                  FinCheckRow(
                    value: s.autoIssueWhatsapp,
                    enabled: s.autoIssueEnabled,
                    label: context.tr("Send WhatsApp to each member's profile number", 'हर सदस्य के प्रोफ़ाइल नंबर पर व्हाट्सऐप भेजें'),
                    onChanged: (v) => c.updateSettings(s.copyWith(autoIssueWhatsapp: v)),
                  ),
                  FinCheckRow(
                    value: s.autoIssueEmail,
                    enabled: s.autoIssueEnabled,
                    label: context.tr("Send email to each member's directory email ID", 'हर सदस्य की निर्देशिका ईमेल पर ईमेल भेजें'),
                    onChanged: (v) => c.updateSettings(s.copyWith(autoIssueEmail: v)),
                  ),
                  gap,
                  FieldLabel(context.tr('App notification tune', 'ऐप सूचना धुन')),
                  AppDropdown<String>(
                    items: const ['melody', 'chime', 'bell', 'digital'],
                    value: const ['melody', 'chime', 'bell', 'digital'].contains(s.billSoundKey) ? s.billSoundKey : 'melody',
                    labelOf: (k) => switch (k) {
                      'melody' => context.tr('Musical melody', 'संगीतमय धुन'),
                      'chime' => context.tr('Soft chime', 'मधुर घंटी'),
                      'bell' => context.tr('Bell tone', 'घंटी स्वर'),
                      _ => context.tr('Digital beep', 'डिजिटल बीप'),
                    },
                    onChanged: s.autoIssueEnabled ? (v) => c.updateSettings(s.copyWith(billSoundKey: v ?? 'melody')) : null,
                  ),
                  gap,
                  AppButton.secondary(
                    label: _saving ? context.tr('Saving…', 'सहेजा जा रहा है…') : context.tr('Save bill settings', 'बिल सेटिंग सहेजें'),
                    onPressed: _saving ? null : _save,
                  ),
                  gap,
                  AppButton(
                    label: _issuing ? context.tr('Issuing…', 'जारी हो रहा है…') : context.tr('Issue this month now', 'इस माह का अभी जारी करें'),
                    loading: _issuing,
                    onPressed: _issuing ? null : _issue,
                  ),
                  if (_lastBill.isNotEmpty) FinHint(_lastBill),
                  FinHint(context.tr(
                    "WhatsApp cannot change the phone's ringtone; the musical tune plays in the app notification. Optional WhatsApp audio clip needs MAINTENANCE_BILL_AUDIO_URL configured.",
                    'व्हाट्सऐप फ़ोन की रिंगटोन नहीं बदल सकता; संगीतमय धुन ऐप सूचना में बजती है। वैकल्पिक व्हाट्सऐप ऑडियो के लिए MAINTENANCE_BILL_AUDIO_URL सेट करें।',
                  )),
                ],
              ),
            ),
            CardSection(
              margin: const EdgeInsets.only(bottom: 16),
              color: Color.alphaBlend(AppTokens.tint(t.warning, 0.05), t.card),
              borderColor: AppTokens.tint(t.warning, 0.2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SectionTitle(context.tr('Due reminders', 'बकाया अनुस्मारक'), icon: Icons.warning_amber_rounded, iconColor: t.warning),
                  FieldLabel(context.tr('Flat scope for reminders', 'अनुस्मारक हेतु फ्लैट दायरा')),
                  AppDropdown<bool>(
                    items: const [false, true],
                    value: widget.includeVacant,
                    labelOf: (v) => v
                        ? context.tr('Include vacant flats', 'खाली फ्लैट भी शामिल करें')
                        : context.tr('Occupied / sold flats only', 'केवल आबाद / बिके फ्लैट'),
                    onChanged: (v) => widget.onIncludeVacantChanged(v ?? false),
                  ),
                  FinHint(widget.includeVacant
                      ? context.tr('Using all flats ($total)', 'सभी फ्लैट ($total)')
                      : context.tr('Using occupied/sold flats ($target)', 'आबाद/बिके फ्लैट ($target)')),
                  Divider(color: t.border, height: 20),
                  Text(context.tr('Automatic due reminders', 'स्वचालित बकाया अनुस्मारक'), style: AppText.bodyMedium(context).copyWith(fontSize: 12)),
                  gap,
                  AppTextField(
                    controller: _dueDay,
                    focusNode: _dueDayFocus,
                    label: context.tr('Monthly due day (1–28)', 'मासिक देय दिन (1–28)'),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (v) => c.updateSettings(s.copyWith(dueDay: int.tryParse(v) ?? 0)),
                  ),
                  FinHint(context.tr('Daily reminders start after this day each month for unpaid maintenance.',
                      'अदत्त रखरखाव के लिए हर माह इस दिन के बाद रोज़ अनुस्मारक शुरू होते हैं।')),
                  FinCheckRow(
                    value: s.enabled,
                    label: context.tr('Enable daily due reminders after monthly due date', 'मासिक देय तिथि के बाद रोज़ बकाया अनुस्मारक चालू करें'),
                    onChanged: (v) => c.updateSettings(s.copyWith(enabled: v)),
                  ),
                  FinCheckRow(
                    value: s.reminderWhatsapp,
                    enabled: s.enabled,
                    label: context.tr('Also WhatsApp directory contacts for due reminders', 'बकाया अनुस्मारक निर्देशिका संपर्कों को व्हाट्सऐप पर भी'),
                    onChanged: (v) => c.updateSettings(s.copyWith(reminderWhatsapp: v)),
                  ),
                  FinCheckRow(
                    value: s.reminderEmail,
                    enabled: s.enabled,
                    label: context.tr('Also email directory contacts for due reminders', 'बकाया अनुस्मारक निर्देशिका संपर्कों को ईमेल पर भी'),
                    onChanged: (v) => c.updateSettings(s.copyWith(reminderEmail: v)),
                  ),
                  gap,
                  AppDropdown<String>(
                    items: const ['once_12pm', 'twice_12pm_7pm'],
                    value: s.schedule,
                    labelOf: (v) => v == 'once_12pm'
                        ? context.tr('Once daily at 12:00 PM', 'रोज़ एक बार दोपहर 12:00 बजे')
                        : context.tr('Twice daily at 12:00 PM and 7:00 PM', 'रोज़ दो बार दोपहर 12:00 और शाम 7:00 बजे'),
                    onChanged: s.enabled ? (v) => c.updateSettings(s.copyWith(schedule: v ?? 'once_12pm')) : null,
                  ),
                  gap,
                  AppButton.secondary(
                    label: _saving ? context.tr('Saving…', 'सहेजा जा रहा है…') : context.tr('Save reminder settings', 'अनुस्मारक सेटिंग सहेजें'),
                    onPressed: _saving ? null : _save,
                  ),
                  gap,
                  AppButton.secondary(
                    label: _testing ? context.tr('Testing…', 'परीक्षण हो रहा है…') : context.tr('Test reminder now', 'अभी परीक्षण अनुस्मारक'),
                    onPressed: _testing ? null : _test,
                  ),
                  if (_lastTest.isNotEmpty) FinHint(_lastTest),
                ],
              ),
            ),
            CardSection(
              margin: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(context.tr('${unpaid.length} flats have not paid maintenance', '${unpaid.length} फ्लैटों ने रखरखाव नहीं दिया'),
                      style: AppText.body(context).copyWith(color: t.mutedForeground)),
                  const SizedBox(height: 12),
                  if (unpaid.isNotEmpty) ...[
                    AppButton(
                      label: context.tr('Send reminders to all (${unpaid.length})', 'सभी को अनुस्मारक भेजें (${unpaid.length})'),
                      loading: _sending,
                      onPressed: () => _sendReminders([for (final f in unpaid) f.flatNumber]),
                    ),
                    const SizedBox(height: 16),
                  ],
                  UnpaidFlatGridTable(rows: rows, emptyMessage: context.tr('All flats have paid maintenance', 'सभी फ्लैटों ने रखरखाव दिया है')),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
