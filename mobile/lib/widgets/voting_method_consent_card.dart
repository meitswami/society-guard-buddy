import 'package:flutter/material.dart';

import '../core/theme/kutumbika_colors.dart';
import '../services/election_service.dart';
import '../utils/voting_method_consent.dart';

/// Shared Option A / B consent UI for resident and admin election screens.
class VotingMethodConsentCard extends StatefulWidget {
  const VotingMethodConsentCard({
    super.key,
    required this.poll,
    required this.societyId,
    required this.isResident,
    this.adminName = 'Admin',
    this.memberId,
    this.memberName,
    this.flatNumber,
    required this.onChanged,
  });

  final Map<String, dynamic> poll;
  final String societyId;
  final bool isResident;
  final String adminName;
  final String? memberId;
  final String? memberName;
  final String? flatNumber;
  final Future<void> Function() onChanged;

  @override
  State<VotingMethodConsentCard> createState() => _VotingMethodConsentCardState();
}

class _VotingMethodConsentCardState extends State<VotingMethodConsentCard> {
  final _service = ElectionService();
  List<VotingMethodConsentRow> _rows = [];
  int? _eligibleCount;
  bool _busy = false;
  bool _separateOffice = false;
  bool _hi = false;

  @override
  void initState() {
    super.initState();
    final code = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    _hi = code == 'hi';
    _separateOffice = widget.poll['separate_office_votes'] == true;
    _load();
  }

  @override
  void didUpdateWidget(covariant VotingMethodConsentCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.poll['id'] != widget.poll['id'] ||
        oldWidget.poll['voting_method'] != widget.poll['voting_method'] ||
        oldWidget.poll['voting_method_consent_open'] != widget.poll['voting_method_consent_open']) {
      _separateOffice = widget.poll['separate_office_votes'] == true;
      _load();
    }
  }

  Future<void> _load() async {
    final rows = await _service.fetchVotingMethodConsents(widget.poll['id'] as String);
    final eligible = await _service.countEligibleMembers(widget.societyId);
    if (!mounted) return;
    setState(() {
      _rows = rows;
      _eligibleCount = eligible;
    });
  }

  String _optLabel(ElectionVotingMethod method) {
    final o = votingMethodOptions[method]!;
    return _hi ? o.titleHi : o.titleEn;
  }

  Future<bool> _confirm(String title, String body, String okLabel) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_hi ? 'रद्द' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(okLabel),
          ),
        ],
      ),
    );
    return ok == true;
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _openConsent() async {
    final ok = await _confirm(
      _hi ? 'सदस्य सहमति खोलें?' : 'Open member consent?',
      _hi
          ? 'सदस्य विकल्प A (गुप्त मतपत्र) या विकल्प B (हाथ उठाकर) देखकर सहमति देंगे।'
          : 'Members will see Option A (Secret Ballot) and Option B (Show of Hands) and record consent.',
      _hi ? 'खोलें' : 'Open consent',
    );
    if (!ok) return;
    setState(() => _busy = true);
    try {
      await _service.openVotingMethodConsent(
        pollId: widget.poll['id'] as String,
        societyId: widget.societyId,
        openedBy: widget.adminName,
      );
      _toast(_hi ? 'सदस्य सहमति खुली' : 'Member consent opened');
      await widget.onChanged();
      await _load();
    } catch (e) {
      _toast(e.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cast(ElectionVotingMethod choice) async {
    final memberId = widget.memberId;
    if (memberId == null || memberId.isEmpty) {
      _toast(_hi ? 'सदस्य प्रोफ़ाइल आवश्यक है' : 'Member profile required');
      return;
    }
    final ok = await _confirm(
      _hi ? 'सहमति दर्ज करें?' : 'Record your consent?',
      _hi
          ? 'आप ${_optLabel(choice)} चुन रहे हैं। जमा होने के बाद बदल नहीं सकते।'
          : 'You are choosing ${_optLabel(choice)}. This cannot be changed after submission.',
      _hi ? 'सहमति दें' : 'Confirm consent',
    );
    if (!ok) return;
    setState(() => _busy = true);
    try {
      await _service.submitVotingMethodConsent(
        societyId: widget.societyId,
        pollId: widget.poll['id'] as String,
        memberId: memberId,
        choice: choice,
        memberName: widget.memberName,
        flatNumber: widget.flatNumber,
      );
      _toast(_hi ? 'सहमति दर्ज हो गई' : 'Consent recorded');
      await _load();
    } catch (e) {
      _toast(e.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _finalize(ElectionVotingMethod method, {required bool allowPartial}) async {
    final eligible = _eligibleCount;
    if (eligible == null) {
      _toast(_hi ? 'पात्र सदस्य संख्या उपलब्ध नहीं' : 'Eligible member count unavailable');
      return;
    }
    final tally = tallyFromConsents(_rows);
    final ok = await _confirm(
      _hi ? 'मतदान विधि अंतिम करें?' : 'Finalize voting method?',
      allowPartial
          ? (_hi
              ? 'आंशिक सहमति (${tally.total}/$eligible) के साथ ${_optLabel(method)} अंतिम करें?'
              : 'Finalize ${_optLabel(method)} with partial consent (${tally.total}/$eligible)?')
          : (_hi
              ? 'सभी $eligible पात्र सदस्यों की सहमति मिल गई। ${_optLabel(method)} अंतिम करें?'
              : 'All $eligible eligible members have consented. Finalize ${_optLabel(method)}?'),
      _hi ? 'अंतिम करें' : 'Finalize',
    );
    if (!ok) return;
    setState(() => _busy = true);
    try {
      await _service.finalizeVotingMethodFromConsent(
        pollId: widget.poll['id'] as String,
        societyId: widget.societyId,
        method: method,
        recordedBy: widget.adminName,
        eligibleMemberCount: eligible,
        consentTotal: tally.total,
        allowPartial: allowPartial,
        separateOfficeVotes: _separateOffice,
      );
      _toast(
        method == votingMethodSecretBallot
            ? (_hi ? 'विकल्प A अंतिम — गुप्त मतपत्र' : 'Option A finalized — Secret Ballot')
            : (_hi ? 'विकल्प B अंतिम — हाथ उठाकर' : 'Option B finalized — Show of Hands'),
      );
      await widget.onChanged();
      await _load();
    } catch (e) {
      _toast(e.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final method = widget.poll['voting_method'] as String?;
    final consentOpen = widget.poll['voting_method_consent_open'] == true;
    final finalized = method != null && method.isNotEmpty;
    final tally = tallyFromConsents(_rows);
    final leading = leadingConsentMethod(tally);
    final eligible = _eligibleCount;
    final allConsented = eligible != null && eligible > 0 && tally.total >= eligible;
    VotingMethodConsentRow? myConsent;
    final mid = widget.memberId;
    if (mid != null && mid.isNotEmpty) {
      for (final r in _rows) {
        if (r.memberId == mid) {
          myConsent = r;
          break;
        }
      }
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: KutumbikaColors.textMuted.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(10),
        color: KutumbikaColors.surfaceMuted.withValues(alpha: 0.55),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _hi ? 'मतदान विधि — विकल्प A या B' : 'Voting method — Option A or B',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            _hi
                ? 'उपविधियाँ दोनों विधियों की अनुमति देती हैं। सदस्य प्रभाव देखें, सहमति दें।'
                : 'Bye-laws permit both methods. Members see effects and record consent before finalization.',
            style: const TextStyle(fontSize: 11, color: KutumbikaColors.textMuted),
          ),
          const SizedBox(height: 10),
          for (final m in [votingMethodSecretBallot, votingMethodShowOfHands]) ...[
            _OptionTile(
              option: votingMethodOptions[m]!,
              count: m == votingMethodSecretBallot ? tally.secretBallot : tally.showOfHands,
              selected: myConsent?.choice == m,
              hi: _hi,
              showConsentButton:
                  widget.isResident && consentOpen && !finalized && myConsent == null,
              busy: _busy,
              onConsent: () => _cast(m),
            ),
            const SizedBox(height: 8),
          ],
          Text(
            '${_hi ? 'प्रगति' : 'Progress'}: ${tally.total}${eligible != null ? ' / $eligible' : ''} '
            '${_hi ? 'पात्र सदस्यों की सहमति' : 'eligible members consented'}'
            '${allConsented ? (_hi ? ' — पूर्ण' : ' — complete') : ''}'
            '${leading != null ? ' · ${_hi ? 'अग्रणी' : 'Leading'}: ${_optLabel(leading)}' : (tally.total > 0 ? ' · ${_hi ? 'बराबरी' : 'Tie'}' : '')}',
            style: const TextStyle(fontSize: 11, color: KutumbikaColors.textMuted),
          ),
          if (finalized) ...[
            const SizedBox(height: 8),
            Text(
              '${_hi ? 'अंतिम विधि' : 'Finalized'}: ${_optLabel(method!)}'
              '${widget.poll['voting_method_recorded_by'] != null ? ' · ${widget.poll['voting_method_recorded_by']}' : ''}',
              style: TextStyle(fontSize: 12, color: Colors.green.shade700, fontWeight: FontWeight.w600),
            ),
          ] else if (!widget.isResident) ...[
            const SizedBox(height: 10),
            if (!consentOpen)
              FilledButton(
                onPressed: _busy ? null : _openConsent,
                child: Text(_hi ? 'सदस्य सहमति खोलें (A / B)' : 'Open member consent (A / B)'),
              )
            else ...[
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: _separateOffice,
                onChanged: _busy
                    ? null
                    : (v) => setState(() => _separateOffice = v ?? false),
                title: Text(
                  _hi
                      ? 'प्रति-पद अलग मतपत्र स्पष्ट रूप से अनुमोदित'
                      : 'Approve separate per-office votes (only if expressly established)',
                  style: const TextStyle(fontSize: 11),
                ),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton(
                    onPressed: _busy || leading == null || !allConsented
                        ? null
                        : () => _finalize(leading, allowPartial: false),
                    child: Text(
                      _hi ? 'सभी सदस्यों की सहमति के बाद अंतिम' : 'Finalize after all consent',
                    ),
                  ),
                  if (leading != null && !allConsented)
                    OutlinedButton(
                      onPressed: _busy || tally.total < 1
                          ? null
                          : () => _finalize(leading, allowPartial: true),
                      child: Text(
                        _hi ? 'आंशिक सहमति से अंतिम' : 'Finalize with partial consent',
                      ),
                    ),
                  if (leading == null && tally.total > 0) ...[
                    OutlinedButton(
                      onPressed: _busy || !allConsented
                          ? null
                          : () => _finalize(votingMethodSecretBallot, allowPartial: !allConsented),
                      child: Text(_hi ? 'बराबरी पर A' : 'Tie-break: A'),
                    ),
                    OutlinedButton(
                      onPressed: _busy || !allConsented
                          ? null
                          : () => _finalize(votingMethodShowOfHands, allowPartial: !allConsented),
                      child: Text(_hi ? 'बराबरी पर B' : 'Tie-break: B'),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              Text(
                _hi
                    ? 'अंतिम होने तक मतदान विंडो नहीं खोली जा सकती।'
                    : 'Voting cannot open until a method is finalized.',
                style: const TextStyle(fontSize: 10, color: KutumbikaColors.textMuted),
              ),
            ],
            if (_rows.isNotEmpty) ...[
              const SizedBox(height: 8),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(
                  '${_hi ? 'सहमति सूची' : 'Consent list'} (${_rows.length})',
                  style: const TextStyle(fontSize: 11, color: KutumbikaColors.textMuted),
                ),
                children: [
                  for (final r in _rows)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '${r.memberName ?? r.memberId.substring(0, 8)}${r.flatNumber != null ? ' · ${r.flatNumber}' : ''}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: Text(
                        r.choice == votingMethodSecretBallot ? 'A' : 'B',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.option,
    required this.count,
    required this.selected,
    required this.hi,
    required this.showConsentButton,
    required this.busy,
    required this.onConsent,
  });

  final VotingMethodOption option;
  final int count;
  final bool selected;
  final bool hi;
  final bool showConsentButton;
  final bool busy;
  final VoidCallback onConsent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: selected ? Colors.indigo : KutumbikaColors.textMuted.withValues(alpha: 0.4),
        ),
        color: selected ? Colors.indigo.withValues(alpha: 0.08) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            hi ? option.titleHi : option.titleEn,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            hi ? option.effectHi : option.effectEn,
            style: const TextStyle(fontSize: 11, color: KutumbikaColors.textMuted),
          ),
          const SizedBox(height: 4),
          Text(
            '${hi ? 'सहमति' : 'Consents'}: $count',
            style: const TextStyle(fontSize: 10, color: KutumbikaColors.textMuted),
          ),
          if (showConsentButton) ...[
            const SizedBox(height: 8),
            FilledButton(
              onPressed: busy ? null : onConsent,
              style: FilledButton.styleFrom(backgroundColor: Colors.indigo),
              child: Text(hi ? 'विकल्प ${option.code} की सहमति' : 'Consent to Option ${option.code}'),
            ),
          ],
          if (selected)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                hi ? 'आपकी सहमति दर्ज है' : 'Your consent is recorded',
                style: TextStyle(fontSize: 10, color: Colors.green.shade700, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }
}
