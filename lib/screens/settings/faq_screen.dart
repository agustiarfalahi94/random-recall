import 'package:flutter/material.dart';

class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'FAQ',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          // ── Notifications ─────────────────────────────────────────────────
          _SectionHeader(label: 'Notifications', theme: theme),
          const SizedBox(height: 8),
          _FaqCard(colorScheme: colorScheme, items: const [
            _FaqItem(
              question:
                  'Why do all my notifications arrive at once when I unlock my phone?',
              answer:
                  'On Xiaomi / MIUI / HyperOS devices, the OS holds scheduled '
                  'alarms while the screen is off and releases them all together '
                  'when you unlock. This is Android power management — the app '
                  "can't override it directly. Whitelisting the app in battery "
                  'settings (Settings → Battery → No restrictions) reduces the '
                  'delay significantly.',
            ),
            _FaqItem(
              question:
                  'Why does the badge number show fewer than the notifications in my tray?',
              answer:
                  'The badge counts unique questions pending, not the total number '
                  'of notifications. If your question bank is small (e.g. 3 '
                  'questions with frequency set to 6 per day), the same question '
                  'is scheduled into multiple slots — but you only need to answer '
                  'it once, so it counts as 1 in the badge.',
            ),
            _FaqItem(
              question:
                  'Why do multiple notifications disappear when I answer just one?',
              answer:
                  'When you answer a question, all pending reminders for that '
                  'same question are cleared at once. If your question bank is '
                  'small and the same question appeared in several slots, all '
                  'those notifications go away together. This is correct — '
                  "you've answered the question, so the reminders are no longer needed.",
            ),
            _FaqItem(
              question:
                  'Why did my badge count drop after I changed my notification schedule?',
              answer:
                  'Saving new schedule settings triggers a full reschedule. In '
                  'earlier versions, this could accidentally discard already-fired '
                  'notifications from the badge count if their internal ID '
                  'collided with a new future slot. This bug has been fixed — '
                  'fired-but-unanswered notifications are now preserved through '
                  'any schedule change.',
            ),
            _FaqItem(
              question: 'What does "Send at any time" mean?',
              answer:
                  'When enabled, your daily notifications are spread evenly '
                  'across the full 24-hour day (midnight to 11 PM). When '
                  'disabled, notifications are spaced within the time window you '
                  'set (e.g. 9 AM – 6 PM). Use a time window if you only want '
                  'to be reminded during waking hours.',
            ),
            _FaqItem(
              question: "Why aren't my notifications arriving on time?",
              answer:
                  'Two common causes: (1) Battery optimisation is ON for the app '
                  '— whitelist it using the prompt in Notification Schedule '
                  'settings. (2) MIUI / HyperOS holds alarms while the screen '
                  'is off and fires them all on unlock — see the first question '
                  'above.',
            ),
          ]),

          const SizedBox(height: 24),

          // ── Question Bank & Limits ─────────────────────────────────────────
          _SectionHeader(label: 'Question Bank & Limits', theme: theme),
          const SizedBox(height: 8),
          _FaqCard(colorScheme: colorScheme, items: const [
            _FaqItem(
              question: 'How many questions can I add for free?',
              answer:
                  'The free tier starts with 20 question slots. You can earn '
                  'additional slots by completing the 7-day Challenge streak '
                  '(+1 slot per streak). Premium removes the limit entirely.',
            ),
            _FaqItem(
              question: 'How many custom categories can I create for free?',
              answer:
                  'Free accounts can create 1 custom category. The built-in '
                  '"General" and "Work" categories do not count against this '
                  'limit. Premium gives unlimited categories.',
            ),
            _FaqItem(
              question: 'What is the daily Undo?',
              answer:
                  'You can undo your last answer once per calendar day. '
                  'The limit resets at midnight. This is available on both '
                  'free and premium accounts.',
            ),
          ]),

          const SizedBox(height: 24),

          // ── Challenge Mode ─────────────────────────────────────────────────
          _SectionHeader(label: 'Challenge Mode', theme: theme),
          const SizedBox(height: 8),
          _FaqCard(colorScheme: colorScheme, items: const [
            _FaqItem(
              question: 'What is Challenge Mode and how does it work?',
              answer:
                  'Set the response timer to 20 seconds or less in Notification '
                  'Schedule settings to activate Challenge Mode. Answer at '
                  'least one notification per day for 7 consecutive days while '
                  'Challenge Mode is active, and you permanently earn +1 free '
                  'question slot. The streak resets if you miss a day.',
            ),
            _FaqItem(
              question: 'Does the timer affect my score if it runs out?',
              answer:
                  'Yes — if the countdown reaches zero before you answer, the '
                  'question is automatically marked as incorrect. Set the timer '
                  'to 0 in settings to disable it and answer at your own pace.',
            ),
          ]),

          const SizedBox(height: 24),

          // ── Account & Sync ─────────────────────────────────────────────────
          _SectionHeader(label: 'Account & Sync', theme: theme),
          const SizedBox(height: 8),
          _FaqCard(colorScheme: colorScheme, items: const [
            _FaqItem(
              question: 'Do my questions sync across devices?',
              answer:
                  'Yes. Your questions, categories, and settings are backed up '
                  'to your account automatically. Signing in on a new device '
                  'restores everything. You can also trigger a manual sync '
                  'via Settings → Sync Data Now.',
            ),
            _FaqItem(
              question: 'What happens to my data if I sign out?',
              answer:
                  'Your data is saved to the cloud before sign-out completes. '
                  'Nothing is deleted locally or remotely. Signing back in '
                  'restores all your questions and settings.',
            ),
          ]),

          const SizedBox(height: 24),

          // ── Permissions ────────────────────────────────────────────────────
          _SectionHeader(label: 'Permissions', theme: theme),
          const SizedBox(height: 8),
          _FaqCard(colorScheme: colorScheme, items: const [
            _FaqItem(
              question:
                  'Why does the app ask to disable battery optimisation?',
              answer:
                  "Android's battery optimisation can kill scheduled alarms for "
                  'apps running in the background. Whitelisting the app '
                  '(a standard Android setting) tells the OS to keep its alarms '
                  'active — this is the single most effective fix for missed or '
                  'delayed notifications on any Android device.',
            ),
            _FaqItem(
              question: 'What do I lose if I deny notification permission?',
              answer:
                  "The app's entire purpose — timed recall prompts — stops "
                  "working. You won't receive any questions. The permission "
                  'screen will appear on every app open until permission is '
                  'granted in your device settings.',
            ),
          ]),
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
        childrenPadding:
            const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        title: Text(
          item.question,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
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
