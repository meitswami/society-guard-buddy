import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/session/gate_actor.dart';
import '../../core/ui/ui.dart';
import 'data/gate_models.dart';
import 'data/gate_store.dart';
import 'data/quick_entry_logic.dart';
import 'gate_i18n.dart';
import 'widgets/gate_photo.dart';

/// One-tap entry / exit for registered staff and frequent visitors — web
/// `src/pages/QuickEntryPage.tsx`.
class QuickEntryView extends StatefulWidget {
  const QuickEntryView(
      {super.key, required this.actor, this.initialSearchQuery});

  final GateActor actor;

  /// Pre-filled search (admin global search, web `initialSearchQuery`).
  final String? initialSearchQuery;

  @override
  State<QuickEntryView> createState() => _QuickEntryViewState();
}

class _QuickEntryViewState extends State<QuickEntryView> {
  late final GateStore _store = GateStore.of(widget.actor.societyId);
  late final _search =
      TextEditingController(text: widget.initialSearchQuery ?? '');
  String? _success;
  Timer? _successTimer;
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _store.ensureLoaded();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _successTimer?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _flash(String msg) {
    _successTimer?.cancel();
    setState(() => _success = msg);
    _successTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _success = null);
    });
  }

  Future<void> _quickLog(QuickRow row) async {
    setState(() => _busy.add(row.key));
    try {
      await _store.addVisitor(buildQuickEntry(
          source: row.visitor,
          guardId: widget.actor.actorId,
          guardName: widget.actor.actorName));
      if (mounted) _flash('${row.visitor.name} ${context.t('quick.loggedIn')}');
    } catch (_) {
      if (mounted) {
        AppFeedback.toast(context, context.gt('gate.saveFailed'),
            tone: BadgeTone.alert);
      }
    } finally {
      if (mounted) setState(() => _busy.remove(row.key));
    }
  }

  Future<void> _quickExit(QuickRow row, GateVisitor active) async {
    final ok = await AppFeedback.confirm(
      context,
      title: context.t('swal.confirmExit'),
      message: context.t('swal.confirmExitText'),
      confirmLabel: context.t('swal.yes'),
      cancelLabel: context.t('swal.no'),
    );
    if (!ok || !mounted) return;
    setState(() => _busy.add(row.key));
    try {
      await _store.markExit(active.id);
      if (!mounted) return;
      AppFeedback.toast(context, context.t('swal.exitMarked'),
          tone: BadgeTone.success);
      _flash('${active.name} ${context.t('quick.exited')}');
    } catch (_) {
      if (mounted) {
        AppFeedback.toast(context, context.gt('gate.exitFailed'),
            tone: BadgeTone.alert);
      }
    } finally {
      if (mounted) setState(() => _busy.remove(row.key));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _store,
      builder: (context, _) {
        final t = context.tokens;
        final rows = buildQuickRows(
            visitors: _store.visitors,
            members: _store.members,
            flats: _store.flats);
        final filtered = filterQuickRows(rows, _search.text);
        final loading = !_store.visitorsLoaded || !_store.directoryLoaded;
        return PageContainer(
          onRefresh: () =>
              Future.wait([_store.loadVisitors(), _store.loadDirectory()]),
          children: [
            PageHeader(
                icon: Icons.bolt,
                title: context.t('quick.title'),
                subtitle: context.t('quick.subtitle'),
                bottomSpacing: 24),
            if (_success != null)
              CardSection(
                margin: const EdgeInsets.only(bottom: 16),
                borderColor: AppTokens.tint(t.success, 0.3),
                child: Text('✓ $_success',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: t.success)),
              ),
            AppTextField(
                controller: _search,
                hint: context.t('quick.searchPlaceholder'),
                prefixIcon: Icons.search,
                caps: false),
            const SizedBox(height: 16),
            if (loading && rows.isEmpty)
              const LoadingView()
            else if (filtered.isEmpty)
              EmptyView(
                icon: Icons.bolt,
                message: _search.text.trim().isNotEmpty
                    ? context.t('quick.noMatch')
                    : context.t('quick.emptyHint'),
              )
            else
              for (final row in filtered)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _QuickCard(
                    row: row,
                    active: findActiveVisit(_store.visitors, row.visitor),
                    busy: _busy.contains(row.key),
                    onEnter: () => _quickLog(row),
                    onExit: (a) => _quickExit(row, a),
                  ),
                ),
          ],
        );
      },
    );
  }
}

class _QuickCard extends StatelessWidget {
  const _QuickCard(
      {required this.row,
      required this.active,
      required this.busy,
      required this.onEnter,
      required this.onExit});

  final QuickRow row;
  final GateVisitor? active;
  final bool busy;
  final VoidCallback onEnter;
  final ValueChanged<GateVisitor> onExit;

  Widget _tag(String text, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
        child: Text(text,
            style:
                TextStyle(fontSize: 9, fontWeight: FontWeight.w500, color: fg)),
      );

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final v = row.visitor;
    final a = active;
    return CardSection(
      child: Row(
        children: [
          GatePhoto(
              src: v.visitorPhotos.isEmpty ? null : v.visitorPhotos.first,
              size: 40,
              fallbackText: v.name),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(v.name, style: AppText.sectionTitle(context)),
                    if (row.isStaff)
                      _tag(context.t('quick.staffBadge'), t.secondary,
                          t.secondaryForeground),
                    if (a != null)
                      _tag(context.t('common.inside'),
                          AppTokens.tint(t.success, 0.2), t.success),
                  ],
                ),
                Text(
                  isSyntheticStaffPhone(v.phone)
                      ? context.t('quick.noPhoneOnFile')
                      : v.phone,
                  style:
                      AppText.mono(context, size: 12, color: t.mutedForeground),
                ),
                const SizedBox(height: 2),
                Text.rich(
                  TextSpan(
                    style: AppText.tiny(context),
                    children: [
                      TextSpan(
                          text: '${context.t('common.flat')} ${v.flatNumber}'),
                      if (row.visitCount >= 2) ...[
                        const TextSpan(text: '  ·  '),
                        TextSpan(
                          text:
                              '${row.visitCount} ${context.t('quick.visits')}',
                          style: TextStyle(
                              color: t.primary, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          AppButton(
            label: a != null
                ? context.t('common.exit')
                : context.t('common.enter'),
            icon: a != null ? Icons.logout : Icons.how_to_reg_outlined,
            dense: true,
            expand: false,
            loading: busy,
            onPressed: a != null ? () => onExit(a) : onEnter,
          ),
        ],
      ),
    );
  }
}
