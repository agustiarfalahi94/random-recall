import 'package:flutter/material.dart';
import 'package:random_recall/l10n/app_localizations.dart';

class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.faqTitle,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          // ── Notifications ─────────────────────────────────────────────────
          _SectionHeader(label: l10n.faqSectionNotifications, theme: theme),
          const SizedBox(height: 8),
          _FaqCard(
            colorScheme: colorScheme,
            items: [
              _FaqItem(question: l10n.faqQ1, answer: l10n.faqA1),
              _FaqItem(question: l10n.faqQ2, answer: l10n.faqA2),
              _FaqItem(question: l10n.faqQ3, answer: l10n.faqA3),
              _FaqItem(question: l10n.faqQ4, answer: l10n.faqA4),
              _FaqItem(question: l10n.faqQ5, answer: l10n.faqA5),
              _FaqItem(question: l10n.faqQ6, answer: l10n.faqA6),
            ],
          ),

          const SizedBox(height: 24),

          // ── Question Bank & Limits ─────────────────────────────────────────
          _SectionHeader(label: l10n.faqSectionQuestionBank, theme: theme),
          const SizedBox(height: 8),
          _FaqCard(
            colorScheme: colorScheme,
            items: [
              _FaqItem(question: l10n.faqQ7, answer: l10n.faqA7),
              _FaqItem(question: l10n.faqQ8, answer: l10n.faqA8),
              _FaqItem(question: l10n.faqQ9, answer: l10n.faqA9),
            ],
          ),

          const SizedBox(height: 24),

          // ── Challenge Mode ─────────────────────────────────────────────────
          _SectionHeader(label: l10n.faqSectionChallengeMode, theme: theme),
          const SizedBox(height: 8),
          _FaqCard(
            colorScheme: colorScheme,
            items: [
              _FaqItem(question: l10n.faqQ10, answer: l10n.faqA10),
              _FaqItem(question: l10n.faqQ11, answer: l10n.faqA11),
            ],
          ),

          const SizedBox(height: 24),

          // ── Account & Sync ─────────────────────────────────────────────────
          _SectionHeader(label: l10n.faqSectionAccountSync, theme: theme),
          const SizedBox(height: 8),
          _FaqCard(
            colorScheme: colorScheme,
            items: [
              _FaqItem(question: l10n.faqQ12, answer: l10n.faqA12),
              _FaqItem(question: l10n.faqQ13, answer: l10n.faqA13),
            ],
          ),

          const SizedBox(height: 24),

          // ── Permissions ────────────────────────────────────────────────────
          _SectionHeader(label: l10n.faqSectionPermissions, theme: theme),
          const SizedBox(height: 8),
          _FaqCard(
            colorScheme: colorScheme,
            items: [
              _FaqItem(question: l10n.faqQ14, answer: l10n.faqA14),
              _FaqItem(question: l10n.faqQ15, answer: l10n.faqA15),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Section header ─────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.theme});
  final String label;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: theme.textTheme.labelSmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

// ── FAQ card (groups related questions) ───────────────────────────────────────

class _FaqCard extends StatelessWidget {
  const _FaqCard({required this.colorScheme, required this.items});
  final ColorScheme colorScheme;
  final List<_FaqItem> items;

  @override
  Widget build(BuildContext context) {
    // Outer Container provides only the border stroke.
    // Inner Material provides background + rounded clip so that ExpansionTile's
    // ink effects (ripple/highlight) are painted inside this Material and are
    // correctly clipped to the rounded corners — not on the page-level Material
    // where they appear as a square flash on the first/last tile of each card.
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Material(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (int i = 0; i < items.length; i++) ...[
              _FaqTile(item: items[i], colorScheme: colorScheme),
              if (i < items.length - 1)
                Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Individual FAQ tile (expandable) ──────────────────────────────────────────

class _FaqTile extends StatelessWidget {
  const _FaqTile({required this.item, required this.colorScheme});
  final _FaqItem item;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Theme(
      // Remove the default ExpansionTile top/bottom dividers
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        title: Text(
          item.question,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        iconColor: colorScheme.primary,
        collapsedIconColor: colorScheme.onSurfaceVariant,
        children: [
          Text(
            item.answer,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.55,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Data class ────────────────────────────────────────────────────────────────

class _FaqItem {
  const _FaqItem({required this.question, required this.answer});
  final String question;
  final String answer;
}
