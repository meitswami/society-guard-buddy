import 'package:flutter/material.dart';

import '../../core/ui/ui.dart';
import 'public_nav.dart';

/// Web `LegalPageLayout`: sticky header ("← Home | title") + `max-w-3xl` content.
class LegalPageScaffold extends StatelessWidget {
  const LegalPageScaffold({super.key, required this.title, required this.children, this.maxWidth = 768});

  final String title;
  final List<Widget> children;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: context.tr('Home', 'मुख्य पृष्ठ'),
          icon: const Icon(Icons.arrow_back),
          onPressed: () => PublicNav.leave(context),
        ),
        titleSpacing: 0,
        title: Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: -0.2, color: t.foreground)),
        shape: Border(bottom: BorderSide(color: t.border)),
      ),
      body: SafeArea(
        top: false,
        child: PageContainer(
          maxWidth: maxWidth,
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 48),
          children: children,
        ),
      ),
    );
  }
}

/// `text-sm leading-relaxed text-muted-foreground` paragraph; [spans] may hold [legalLink]s.
class LegalText extends StatelessWidget {
  const LegalText(this.text, {super.key, this.spans, this.foreground = false, this.bottom = 12, this.size = 14});

  final String text;
  final List<InlineSpan>? spans;
  final bool foreground;
  final double bottom;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Text.rich(
        TextSpan(text: text, children: spans),
        style: TextStyle(fontSize: size, height: 1.6, color: foreground ? t.foreground : t.mutedForeground),
      ),
    );
  }
}

/// `<strong className="text-foreground">` inline span.
TextSpan legalStrong(BuildContext context, String text) =>
    TextSpan(text: text, style: TextStyle(fontWeight: FontWeight.w600, color: context.tokens.foreground));

/// Underlined primary inline link (web `text-primary underline`).
InlineSpan legalLink(BuildContext context, String label, VoidCallback onTap) {
  final t = context.tokens;
  return WidgetSpan(
    alignment: PlaceholderAlignment.baseline,
    baseline: TextBaseline.alphabetic,
    child: GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        style: TextStyle(fontSize: 14, height: 1.6, color: t.primary, decoration: TextDecoration.underline, decorationColor: t.primary),
      ),
    ),
  );
}

/// Link to another public page.
InlineSpan legalPageLink(BuildContext context, String label, PublicPage page) =>
    legalLink(context, label, () => PublicNav.open(context, page));

/// `<section className="space-y-3">` with an `h2`.
class LegalSection extends StatelessWidget {
  const LegalSection({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: context.tokens.foreground)),
          ),
          ...children,
        ],
      ),
    );
  }
}

/// `list-disc` / `list-decimal` list.
class LegalList extends StatelessWidget {
  const LegalList({super.key, required this.items, this.ordered = false});

  /// Each item: plain text, or rich spans.
  final List<List<InlineSpan>> items;
  final bool ordered;

  static List<List<InlineSpan>> plain(List<String> items) => [
        for (final i in items) [TextSpan(text: i)],
      ];

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final style = TextStyle(fontSize: 14, height: 1.6, color: t.mutedForeground);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < items.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8, left: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 20, child: Text(ordered ? '${i + 1}.' : '•', style: style)),
                  Expanded(child: Text.rich(TextSpan(children: items[i]), style: style)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
