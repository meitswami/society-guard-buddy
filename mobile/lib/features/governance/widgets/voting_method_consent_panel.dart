import 'package:flutter/material.dart';

import '../../../core/ui/ui.dart';
import '../data/gov_backend.dart';
import '../data/poll_repository.dart';
import '../logic/election_governance.dart';
import '../logic/voting_method_consent.dart';
import '../models/poll_models.dart';
import 'gov_widgets.dart';

/// Port of web `VotingMethodConsentPanel.tsx`: record Secret Ballot / Show of Hands
/// before polling (bye-laws), with optional member consent (Option A / B).
class VotingMethodConsentPanel extends StatefulWidget {
  const VotingMethodConsentPanel({
    super.key,
    required this.poll,
    required this.repo,
    required this.viewer,
    required this.onReload,
  });

  final PollRow poll;
  final PollRepository repo;
  final PollViewer viewer;
  final VoidCallback onReload;

  @override
  State<VotingMethodConsentPanel> createState() =>
      _VotingMethodConsentPanelState();
}

class _VotingMethodConsentPanelState extends State<VotingMethodConsentPanel> {
  List<VotingMethodConsentRow> _rows = const [];
  int? _eligible;
  bool _busy = false;
  late bool _separateOffice = widget.poll.separateOfficeVotes;
  bool _showList = false;

  bool get _hi => context.lang == AppLang.hi;
  bool get _isResident => widget.viewer.isResident;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant VotingMethodConsentPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.poll.raw != widget.poll.raw) _load();
  }

  Future<void> _load() async {
    final res = await widget.repo.fetchConsents(widget.poll.id);
    final count = await GovBackend.activeMemberCount(widget.repo.societyId);
    if (!mounted) return;
    if (res.error != null) GovToast.error(context, res.error!);
    setState(() {
      if (res.error == null) _rows = res.rows;
      _eligible = count;
    });
  }

  String _optLabel(String method) => votingMethodOption(method).title(_hi);

  Future<void> _openConsent() async {
    final ok = await govConfirm(
      context,
      title: _hi ? 'सदस्य सहमति खोलें?' : 'Open member consent?',
      message: _hi
          ? 'सदस्य विकल्प A (गुप्त मतपत्र) या विकल्प B (हाथ उठाकर) देखकर सहमति देंगे।'
          : 'Members will see Option A (Secret Ballot) and Option B (Show of Hands) and may record consent.',
      confirmLabel: _hi ? 'खोलें' : 'Open consent',
    );
    if (!ok) return;
    setState(() => _busy = true);
    final err = await widget.repo
        .openConsent(pollId: widget.poll.id, openedBy: widget.viewer.adminName);
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      GovToast.error(context, err);
    } else {
      GovToast.ok(context, _hi ? 'सहमति खुली' : 'Member consent opened');
      widget.onReload();
    }
  }

  Future<void> _cast(String method) async {
    if (widget.viewer.memberId.isEmpty) {
      GovToast.error(context,
          _hi ? 'सदस्य प्रोफ़ाइल आवश्यक है।' : 'Member profile required.');
      return;
    }
    setState(() => _busy = true);
    final err = await widget.repo.submitConsent(
      pollId: widget.poll.id,
      memberId: widget.viewer.memberId,
      choice: method,
      memberName: widget.viewer.memberName,
      flatNumber: widget.viewer.flatNumber,
      hi: _hi,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      GovToast.error(context, err);
    } else {
      GovToast.ok(context, _hi ? 'सहमति दर्ज' : 'Consent recorded');
      await _load();
    }
  }

  Future<void> _finalize(String method, bool allowPartial) async {
    final eligible = _eligible;
    if (eligible == null) return;
    final ok = await govConfirm(
      context,
      title: _hi ? 'मतदान विधि अंतिम करें?' : 'Finalize voting method?',
      message: _hi
          ? 'विधि: ${_optLabel(method)}${allowPartial ? ' (आंशिक सहमति / बैठक प्रस्ताव)' : ''}'
          : 'Method: ${_optLabel(method)}${allowPartial ? ' (partial consent / meeting resolution)' : ''}',
      confirmLabel: _hi ? 'अंतिम करें' : 'Finalize',
    );
    if (!ok) return;
    setState(() => _busy = true);
    final err = await widget.repo.finalizeConsent(
      pollId: widget.poll.id,
      method: method,
      recordedBy: widget.viewer.adminName,
      eligibleMemberCount: eligible,
      consentTotal: tallyFromConsents(_rows).total,
      allowPartial: allowPartial,
      separateOfficeVotes: _separateOffice,
      hi: _hi,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      GovToast.error(context, err);
    } else {
      GovToast.ok(
        context,
        method == VotingMethods.secretBallot
            ? (_hi
                ? 'विकल्प A अंतिम — गुप्त मतपत्र'
                : 'Option A finalized — Secret Ballot')
            : (_hi
                ? 'विकल्प B अंतिम — हाथ उठाकर'
                : 'Option B finalized — Show of Hands'),
      );
      widget.onReload();
    }
  }

  Future<void> _recordByResolution(String method) async {
    final ok = await govConfirm(
      context,
      title: _hi
          ? 'बैठक प्रस्ताव से विधि दर्ज करें?'
          : 'Record method by meeting resolution?',
      message: _hi
          ? '${_optLabel(method)}. मतदान खोलने से पहले विधि दर्ज होनी चाहिए।'
          : '${_optLabel(method)}. Method must be recorded before polling opens.',
      confirmLabel: _hi ? 'दर्ज करें' : 'Record',
    );
    if (!ok) return;
    setState(() => _busy = true);
    final err = await widget.repo.recordByResolution(
      pollId: widget.poll.id,
      method: method,
      recordedBy: widget.viewer.adminName,
      separateOfficeVotes: _separateOffice,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      GovToast.error(context, err);
    } else {
      GovToast.ok(context, _hi ? 'मतदान विधि दर्ज' : 'Voting method recorded');
      widget.onReload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final poll = widget.poll;
    final tally = tallyFromConsents(_rows);
    final my = widget.viewer.memberId.isEmpty
        ? null
        : _rows.where((r) => r.memberId == widget.viewer.memberId).firstOrNull;
    final leading = leadingConsentMethod(tally);
    final allConsented =
        _eligible != null && _eligible! > 0 && tally.total >= _eligible!;
    final finalized = (poll.votingMethod ?? '').isNotEmpty;
    final consentOpen = poll.votingMethodConsentOpen;

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTokens.tint(t.muted, 0.2),
        border: Border.all(color: AppTokens.tint(t.border, 0.7)),
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
              _hi
                  ? 'मतदान विधि — विकल्प A या B'
                  : 'Voting method — Option A or B',
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(
            _hi
                ? 'उपविधि दोनों विधियाँ अनुमति देती है। मतदान खोलने से पहले विधि दर्ज करें।'
                : 'Bye-laws permit both methods. Record the method before opening the poll.',
            style: AppText.caption(context).copyWith(fontSize: 11),
          ),
          const SizedBox(height: 10),
          for (final method in VotingMethods.all)
            Builder(builder: (_) {
              final o = votingMethodOption(method);
              final selected = my?.choice == method;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: selected
                      ? AppTokens.tint(t.accent, 0.1)
                      : AppTokens.tint(t.background, 0.5),
                  border: Border.all(
                      color:
                          selected ? t.accent : AppTokens.tint(t.border, 0.6)),
                  borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(o.title(_hi),
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(o.effect(_hi),
                        style: AppText.caption(context).copyWith(fontSize: 11)),
                    if (consentOpen)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text.rich(
                          TextSpan(children: [
                            TextSpan(text: '${_hi ? 'सहमति' : 'Consents'}: '),
                            TextSpan(
                                text: '${tally.countFor(method)}',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: t.foreground)),
                          ]),
                          style: AppText.tiny(context),
                        ),
                      ),
                    if (_isResident && consentOpen && !finalized && my == null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: MiniButton(
                          label: _hi
                              ? 'विकल्प ${o.code} को सहमति'
                              : 'Consent to Option ${o.code}',
                          variant: MiniVariant.accent,
                          busy: _busy,
                          onPressed: () => _cast(method),
                        ),
                      ),
                    if (selected)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                            _hi
                                ? 'आपकी सहमति दर्ज है'
                                : 'Your consent is recorded',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: t.success)),
                      ),
                  ],
                ),
              );
            }),
          if (consentOpen && !finalized)
            Text.rich(
              TextSpan(children: [
                TextSpan(text: '${_hi ? 'प्रगति' : 'Progress'}: '),
                TextSpan(
                  text:
                      '${tally.total}${_eligible != null ? ' / $_eligible' : ''}',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, color: t.foreground),
                ),
                TextSpan(
                    text:
                        ' ${_hi ? 'पात्र सदस्यों ने सहमति दी' : 'eligible members consented'}'),
                if (leading != null)
                  TextSpan(
                      text:
                          ' · ${_hi ? 'अग्रणी' : 'Leading'}: ${_optLabel(leading)}'),
              ]),
              style: AppText.caption(context).copyWith(fontSize: 11),
            ),
          if (finalized)
            Text.rich(
              TextSpan(children: [
                TextSpan(text: '${_hi ? 'अंतिम विधि' : 'Finalized'}: '),
                TextSpan(
                    text: _optLabel(poll.votingMethod!),
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                if ((poll.votingMethodRecordedBy ?? '').isNotEmpty)
                  TextSpan(text: ' · ${poll.votingMethodRecordedBy}'),
                if (poll.separateOfficeVotes)
                  TextSpan(
                      text: _hi
                          ? ' · प्रति-पद मत अनुमोदित'
                          : ' · separate office votes approved'),
              ]),
              style: TextStyle(fontSize: 12, color: t.success),
            )
          else if (!_isResident) ...[
            const SizedBox(height: 6),
            CheckRow(
              value: _separateOffice,
              onChanged: (v) => setState(() => _separateOffice = v),
              label: _hi
                  ? 'प्रति-पद मत अनुमोदित (केवल यदि स्पष्ट रूप से स्थापित)'
                  : 'Approve separate per-office votes (only if expressly established)',
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                MiniButton(
                  label:
                      _hi ? 'A दर्ज करें (प्रस्ताव)' : 'Record A (resolution)',
                  variant: MiniVariant.success,
                  onPressed: _busy
                      ? null
                      : () => _recordByResolution(VotingMethods.secretBallot),
                ),
                MiniButton(
                  label:
                      _hi ? 'B दर्ज करें (प्रस्ताव)' : 'Record B (resolution)',
                  variant: MiniVariant.success,
                  onPressed: _busy
                      ? null
                      : () => _recordByResolution(VotingMethods.showOfHands),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (!consentOpen)
              Align(
                alignment: Alignment.centerLeft,
                child: MiniButton(
                  label: _hi
                      ? 'वैकल्पिक: सदस्य सहमति खोलें'
                      : 'Optional: open member consent',
                  onPressed: _busy ? null : _openConsent,
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  MiniButton(
                    label: _hi
                        ? 'सभी सहमति के बाद अंतिम'
                        : 'Finalize after all consent',
                    onPressed: _busy || leading == null || !allConsented
                        ? null
                        : () => _finalize(leading, false),
                  ),
                  if (leading != null && !allConsented && tally.total > 0)
                    MiniButton(
                      label: _hi
                          ? 'आंशिक सहमति से अंतिम'
                          : 'Finalize with partial consent',
                      variant: MiniVariant.warning,
                      onPressed: _busy ? null : () => _finalize(leading, true),
                    ),
                ],
              ),
            const SizedBox(height: 6),
            Text(
              _hi
                  ? 'मतदान तब तक नहीं खुल सकता जब तक विधि अंतिम न हो।'
                  : 'Voting cannot open until a method is finalized.',
              style: AppText.tiny(context),
            ),
          ],
          if (!_isResident && _rows.isNotEmpty) ...[
            const SizedBox(height: 8),
            InkWell(
              onTap: () => setState(() => _showList = !_showList),
              child: Text(
                '${_showList ? '▾' : '▸'} ${_hi ? 'सहमति सूची' : 'Consent list'} (${_rows.length})',
                style: AppText.caption(context).copyWith(fontSize: 11),
              ),
            ),
            if (_showList)
              for (final r in _rows)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${(r.memberName ?? '').isNotEmpty ? r.memberName : (r.memberId.length > 8 ? r.memberId.substring(0, 8) : r.memberId)}${(r.flatNumber ?? '').isNotEmpty ? ' · ${r.flatNumber}' : ''}',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                      Text(r.choice == VotingMethods.secretBallot ? 'A' : 'B',
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
          ],
        ],
      ),
    );
  }
}
