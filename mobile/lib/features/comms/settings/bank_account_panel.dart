import 'package:flutter/material.dart';

import '../../../core/ui/ui.dart';
import '../core/comms_i18n.dart';
import '../data/notification_media_storage.dart';
import '../data/settings_repository.dart';
import '../data/society_settings_logic.dart';
import '../widgets/comms_ui.dart';

/// Port of web `SocietyBankAccountPanel` (+ `societyBankAccountService.upsert`): edits the
/// primary society account members pay maintenance into; "Add another"; copy details.
class BankAccountPanel extends StatefulWidget {
  const BankAccountPanel({super.key, required this.societyId});

  final String societyId;

  @override
  State<BankAccountPanel> createState() => _BankAccountPanelState();
}

class _BankAccountPanelState extends State<BankAccountPanel> {
  final _repo = const SettingsRepository();
  final _holder = TextEditingController();
  final _bank = TextEditingController();
  final _ifsc = TextEditingController();
  final _number = TextEditingController();
  final _branch = TextEditingController();
  final _upi = TextEditingController();
  final _branchAddress = TextEditingController();
  final _micr = TextEditingController();
  final _type = TextEditingController();
  final _notes = TextEditingController();
  BankAccountInput _hidden = const BankAccountInput();
  List<SocietyBankAccountRow> _accounts = const [];
  String? _editingId;
  bool _loading = true;
  bool _saving = false;

  List<TextEditingController> get _all => [
        _holder,
        _bank,
        _ifsc,
        _number,
        _branch,
        _upi,
        _branchAddress,
        _micr,
        _type,
        _notes
      ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _all) {
      c.dispose();
    }
    super.dispose();
  }

  void _fill(BankAccountInput i) {
    _hidden = i;
    _holder.text = i.accountHolderName;
    _bank.text = i.bankName;
    _ifsc.text = i.ifsc;
    _number.text = i.accountNumber;
    _branch.text = i.branchName;
    _upi.text = i.upiVpa;
    _branchAddress.text = i.branchAddress;
    _micr.text = i.micr;
    _type.text = i.accountType;
    _notes.text = i.notes;
  }

  BankAccountInput get _input => BankAccountInput(
        accountHolderName: _holder.text,
        bankName: _bank.text,
        ifsc: _ifsc.text,
        accountNumber: _number.text,
        branchName: _branch.text,
        upiVpa: _upi.text,
        branchAddress: _branchAddress.text,
        micr: _micr.text,
        accountType: _type.text,
        notes: _notes.text,
        currency: _hidden.currency,
        customerId: _hidden.customerId,
        isPrimary: _hidden.isPrimary,
        isActive: _hidden.isActive,
        effectiveFrom: _hidden.effectiveFrom,
      );

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rows = await _repo.loadBankAccounts(widget.societyId);
      final primary =
          rows.where((r) => r.isPrimary && r.isActive).firstOrNull ??
              rows.firstOrNull;
      if (!mounted) return;
      setState(() {
        _accounts = rows;
        _editingId = primary?.id;
        _fill(primary == null
            ? const BankAccountInput()
            : BankAccountInput.fromAccount(primary));
      });
    } catch (e) {
      if (mounted) {
        AppFeedback.toast(context,
            '${context.ct('comms.bank.loadFailed')}: ${commsErrorMessage(e)}',
            tone: BadgeTone.alert);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final input = _input;
    if (!bankAccountInputComplete(input)) {
      AppFeedback.toast(context, context.ct('comms.bank.required'),
          tone: BadgeTone.alert);
      return;
    }
    setState(() => _saving = true);
    final wasEditing = _editingId != null;
    try {
      await _repo.upsertBankAccount(widget.societyId, input,
          existingId: _editingId);
      if (!mounted) return;
      AppFeedback.toast(context,
          context.ct(wasEditing ? 'comms.bank.updated' : 'comms.bank.saved'),
          tone: BadgeTone.success);
      await _load();
    } catch (e) {
      if (mounted)
        AppFeedback.toast(context,
            '${context.ct('comms.bank.saveFailed')}: ${commsErrorMessage(e)}',
            tone: BadgeTone.alert);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _copy() async {
    final active = _accounts.where((a) => a.id == _editingId).firstOrNull ??
        _accounts.where((a) => a.isPrimary && a.isActive).firstOrNull;
    if (active == null) {
      AppFeedback.toast(context, context.ct('comms.bank.saveFirst'),
          tone: BadgeTone.alert);
      return;
    }
    final ok = await copyToClipboard(copyableBankDetails(active));
    if (!mounted) return;
    AppFeedback.toast(
        context, context.ct(ok ? 'comms.bank.copied' : 'comms.bank.copyFailed'),
        tone: ok ? BadgeTone.success : BadgeTone.alert);
  }

  Widget _field(BuildContext context, String labelKey, TextEditingController c,
      {bool required = false,
      String? hint,
      bool mono = false,
      bool upper = false,
      int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppTextField(
        label: context.ct(labelKey),
        required: required,
        controller: c,
        hint: hint,
        caps: false,
        mono: mono,
        maxLines: maxLines,
        minLines: maxLines > 1 ? 2 : null,
        inputFormatters: upper ? const [UpperCaseInputFormatter()] : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return CardSection(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                    color: AppTokens.tint(t.primary, 0.1),
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.account_balance_outlined,
                    size: 16, color: t.primary),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.ct('comms.bank.title'),
                        style: AppText.sectionTitle(context)),
                    const SizedBox(height: 2),
                    Text(context.ct('comms.bank.hint'),
                        style: AppText.tiny(context).copyWith(height: 1.4)),
                  ],
                ),
              ),
              if (_accounts.any((a) => a.isActive))
                AppButton.secondary(
                    expand: false,
                    dense: true,
                    icon: Icons.copy,
                    label: context.ct('comms.bank.copy'),
                    onPressed: _copy),
            ],
          ),
          const SizedBox(height: 12),
          if (_loading)
            const LoadingView()
          else ...[
            if (_accounts.length > 1) ...[
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final a in _accounts)
                    PillChoice(
                      label:
                          '${a.bankName} ${maskAccountNumber(a.accountNumber)}'
                          '${a.isPrimary ? ' · ${context.ct('comms.bank.primary')}' : ''}'
                          '${a.isActive ? '' : ' · ${context.ct('comms.bank.inactive')}'}',
                      selected: a.id == _editingId,
                      onTap: () => setState(() {
                        _editingId = a.id;
                        _fill(BankAccountInput.fromAccount(a));
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            _field(context, 'comms.bank.holder', _holder,
                required: true, hint: context.ct('comms.bank.holderPh')),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                    child: _field(context, 'comms.bank.bank', _bank,
                        required: true, hint: context.ct('comms.bank.bankPh'))),
                const SizedBox(width: 8),
                Expanded(
                    child: _field(context, 'comms.bank.ifsc', _ifsc,
                        required: true, hint: 'HDFC0000000', upper: true)),
              ],
            ),
            _field(context, 'comms.bank.accountNumber', _number,
                required: true,
                hint: context.ct('comms.bank.accountNumber'),
                mono: true),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _field(context, 'comms.bank.branch', _branch)),
                const SizedBox(width: 8),
                Expanded(
                    child: _field(context, 'comms.bank.upi', _upi,
                        hint: 'society@okhdfcbank')),
              ],
            ),
            _field(context, 'comms.bank.branchAddress', _branchAddress),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _field(context, 'comms.bank.micr', _micr)),
                const SizedBox(width: 8),
                Expanded(
                    child: _field(context, 'comms.bank.accountType', _type)),
              ],
            ),
            _field(context, 'comms.bank.notes', _notes, maxLines: 4),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                AppButton(
                  expand: false,
                  icon: Icons.save_outlined,
                  loading: _saving,
                  label: context.ct(_editingId != null
                      ? 'comms.bank.update'
                      : 'comms.bank.save'),
                  onPressed: _saving ? null : _save,
                ),
                if (_editingId != null)
                  AppButton.secondary(
                    expand: false,
                    icon: Icons.apartment_outlined,
                    label: context.ct('comms.bank.addAnother'),
                    onPressed: () => setState(() {
                      _editingId = null;
                      _fill(const BankAccountInput());
                    }),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
