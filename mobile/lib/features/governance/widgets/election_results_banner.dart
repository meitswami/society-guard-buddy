import 'package:flutter/material.dart';

import '../../../core/ui/ui.dart';
import '../data/gov_backend.dart';
import '../data/poll_repository.dart';
import '../logic/election_governance.dart';
import '../logic/election_tally.dart';
import 'gov_widgets.dart';

/// Winners list (web `ResultsBlock` / ElectionModule `renderResults`).
class ElectionResultsBlock extends StatelessWidget {
  const ElectionResultsBlock({super.key, required this.results, required this.photoForOption});

  final ElectionResults results;
  final String? Function(String optionId) photoForOption;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final hi = context.lang == AppLang.hi;
    final votes = context.tr('votes', 'मत');
    Widget line(String label, ElectedWinner w) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: PersonPhotoSide(
            name: w.name,
            photo: photoForOption(w.optionId),
            size: AvatarSize.sm,
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(text: '$label: ', style: TextStyle(color: t.mutedForeground)),
                  TextSpan(text: w.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  TextSpan(text: '  (${w.score} $votes)', style: AppText.tiny(context)),
                ]),
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ),
        );
    final committee = results.committee;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final post in ElectionPosts.offices)
          if (results.office(post) != null) line(postDisplay(post, hi: hi), results.office(post)!),
        if (committee.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text('${context.tr('Executive Members', 'कार्यकारिणी सदस्य')} (${committee.length})', style: AppText.caption(context)),
          for (final c in committee)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: PersonPhotoSide(
                name: c.name,
                photo: photoForOption(c.optionId),
                size: AvatarSize.sm,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(text: c.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                      TextSpan(text: '  (${c.score} $votes)', style: AppText.tiny(context)),
                    ]),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

/// Port of web `ElectionResultsBanner` — latest closed society elections for the
/// admin portal (shown on the polls page and the admin overview).
class ElectionResultsBanner extends StatefulWidget {
  const ElectionResultsBanner({super.key, required this.societyId, this.adminOnly = true});

  final String societyId;
  final bool adminOnly;

  @override
  State<ElectionResultsBanner> createState() => _ElectionResultsBannerState();
}

class _ElectionResultsBannerState extends State<ElectionResultsBanner> {
  List<Map<String, dynamic>> _rows = const [];
  Map<String, String> _optionMemberIds = const {};
  Map<String, String> _photos = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ElectionResultsBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.societyId != widget.societyId) _load();
  }

  Future<void> _load() async {
    if (!widget.adminOnly) return;
    try {
      final repo = PollRepository(widget.societyId);
      final rows = await repo.latestResultsPolls();
      final ids = rows.map((r) => '${r['id']}').toList();
      final mids = await repo.optionMemberIds(ids);
      final photos = await GovBackend.fetchMemberPhotoMap(mids.values);
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _optionMemberIds = mids;
        _photos = photos;
      });
    } catch (_) {
      // Banner is best-effort (web ignores errors as well).
    }
  }

  @override
  Widget build(BuildContext context) {
    final valid = _rows.where((r) => ElectionResults.isPayload(r['election_results'])).toList();
    if (!widget.adminOnly || valid.isEmpty) return const SizedBox.shrink();
    final t = context.tokens;
    return TintBox(
      color: t.primary,
      border: 0.25,
      radius: AppTokens.radius,
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.emoji_events_outlined, size: 20, color: t.primary),
              const SizedBox(width: 8),
              Text(context.tr('Election results (admin only)', 'चुनाव परिणाम (केवल प्रशासक)'), style: AppText.sectionTitle(context)),
            ],
          ),
          const SizedBox(height: 10),
          for (final r in valid)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTokens.tint(t.card, 0.8),
                border: Border.all(color: t.border),
                borderRadius: BorderRadius.circular(AppTokens.radiusSm),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(context.tr('ELECTION', 'चुनाव'), style: AppText.fieldLabel(context)),
                  const SizedBox(height: 2),
                  Text('${r['question'] ?? ''}', style: AppText.sectionTitle(context)),
                  const SizedBox(height: 4),
                  ElectionResultsBlock(
                    results: ElectionResults.tryParse(r['election_results'])!,
                    photoForOption: (oid) {
                      final mid = _optionMemberIds[oid];
                      return mid == null ? null : _photos[mid];
                    },
                  ),
                ],
              ),
            ),
          Text(
            context.tr(
                'Publish winners to the Committee module when ready. Residents see the roster only after publish. Photos fill from each member\'s profile in My Family & Staff.',
                'तैयार होने पर विजेताओं को समिति खंड में प्रकाशित करें। प्रकाशन के बाद ही निवासियों को सूची दिखती है। फ़ोटो प्रत्येक सदस्य की प्रोफ़ाइल (मेरा परिवार व स्टाफ़) से आती हैं।'),
            style: AppText.tiny(context),
          ),
        ],
      ),
    );
  }
}
