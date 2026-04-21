# UI/UX Improvements: Display Name, Challenge Mode, & Notification Limits

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:writing-plans (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enhance user engagement and experience through personalized display names, stricter challenge mode rules with cosmetic rewards, and increased notification flexibility.

**Architecture:** Three independent features that enhance core app functionality without major architectural changes. Display name prompt integrates with Firebase Auth, challenge mode extends existing StreakService, and notification limit is a simple UI/backend update.

**Tech Stack:** Firebase Auth (displayName), Firestore (persistence), Google Safe Browsing API (profanity check), Flutter UI updates

---

## Feature 1: Display Name Prompt with Validation

### Purpose
Users need a personalized display name for:
- Welcome message on home screen ("Welcome, Agustiar Falahi")
- Profile display
- Potential future features (leaderboards, etc.)

### Requirements

**Trigger Points:**
1. **New user signup:** Show after email verification during onboarding
2. **Existing user with empty name:** Show on first app launch (can't skip)

**Validation Rules:**
- Max 50 characters
- **Allowed:** Letters (a-z, A-Z), numbers (0-9), spaces, hyphens (-), underscores (_)
- **Blocked:** Special characters (!@#$%^&*()_+=[]{}|;:'",.<>?/~`)
- **Blocked:** Profanity (via Google Safe Browsing API)

**UI Flow:**
1. Full-screen modal (can't dismiss without valid input)
2. Text input field with character counter
3. Real-time validation feedback:
   - Valid: Green checkmark, submit enabled
   - Special characters: "Only letters, numbers, spaces, hyphens, and underscores allowed."
   - Profanity detected: "This name contains inappropriate content. Please choose another."
4. Submit button (disabled until valid)

**Localization:**
- English validation messages
- Indonesian validation messages (Bahasa Indonesia)

**Database Persistence:**
- Save to Firebase Auth `displayName` field
- Sync to Firestore `users/{userId}/name` for backup
- Update on app launch if Auth displayName empty

---

## Feature 2: Challenge Mode Overhaul

### Purpose
Provide high-difficulty challenge with strict rules and cosmetic rewards to increase long-term user engagement.

### Current vs. New Behavior

| Aspect | Current | New |
|--------|---------|-----|
| **Timer requirement** | Timer ≤ 20s activates | Must use 5-10s only |
| **Question requirement** | Any answer counts | ALL must be correct |
| **Duration** | No fixed duration | 7 or 14 days consecutive |
| **Frequency** | User can change anytime | Locked for duration |
| **Failure condition** | No penalty | Exit challenge + reset streak |
| **Free-tier reward** | +1 question per 7 days | +1Q per 7-day, +1Q+1C per 14-day |
| **Premium reward** | N/A | Badge + title + notification appearance |

### Activation Flow

**Step 1: Frequency Selection**
- Dialog: "How many questions per day during this 7-day challenge? (1-50)"
- User selects frequency and confirms

**Step 2: Warning Dialog**
- Full-screen modal (can't dismiss without confirming)
- Title: "⚠️ Challenge Mode — 7-Day Streak"
- Rules list:
  - "• Must answer ALL questions correctly (no mistakes allowed)"
  - "• Timer locked to 5 or 10 seconds only"
  - "• Notification frequency locked (cannot change)"
  - "• Must complete every day for 7 consecutive days"
  - "• Complete all 7 days to earn rewards"
- Buttons: "Cancel" or "I Understand, Start Challenge"

**Step 3: Challenge Active**
- Display: "Challenge Day X/7 | Locked Settings"
- Timer options restricted to 5-10s only
- Notification frequency locked in settings (can't change)
- Any incorrect answer → automatic exit + streak reset to 0 + all locks removed

### Reward System

**Free-Tier Users:**
- Each 7-day completion: +1 question slot
- Each 14-day completion: +1 question slot + 1 category slot
- Can repeat indefinitely
- Max: 200 questions + 20 categories (same as premium)
- Estimated time to max: ~10 months of continuous 14-day streaks

**Premium Users:**
- 🏆 Badge on profile (shows completion count)
- 👑 Progressive title after each 14-day completion:
  - 1st: "Challenger"
  - 2nd: "Champion"
  - 3rd+: "Legend"
- 🔥 Special notification appearance during active challenge (gold border or fire icon)

### Existing User Data

**For current 3 accounts:** No migration needed. New users get fresh challenge state. Existing users can opt-in to challenge mode anytime.

### Database Persistence

**Firestore documents to create/update:**

```
users/{userId}/
  ├── challenge/
  │   ├── active (bool) — is user currently in challenge?
  │   ├── start_date (timestamp) — challenge start date
  │   ├── day (int) — current day (0-7 or 0-14)
  │   ├── locked_frequency (int) — notification count locked at start
  │   └── last_answer_date (timestamp) — last question answered (for daily check)
  ├── streak/
  │   ├── total_7day_completed (int) — cumulative 7-day challenges done
  │   └── total_14day_completed (int) — cumulative 14-day challenges done
  ├── rewards/
  │   ├── bonus_questions (int) — earned through streaks (free-tier only)
  │   ├── bonus_categories (int) — earned through 14-day streaks (free-tier only)
  │   ├── challenge_badge_unlocked (bool) — badge earned (premium only)
  │   └── highest_title (string) — "Challenger"/"Champion"/"Legend" (premium only)
```

**Sync Strategy:**
- Save to Firestore on every challenge state change (start, answer, completion, reset)
- Load from Firestore on app launch
- Handle offline scenarios gracefully (use local cache, sync when reconnected)

---

## Feature 3: Daily Notification Limit Increase

### Purpose
Allow users more flexibility in notification frequency for better customization.

### Current vs. New

| Aspect | Current | New |
|--------|---------|-----|
| **Max daily notifications** | 10 | 50 |
| **Slider range** | 1-10 | 1-50 |
| **Safety** | 1-hour time gap enforced | 1-hour time gap enforced |

### Why It's Safe
- Time picker enforces minimum 1-hour gap between start/end times
- 50 notifications in 60 minutes = ~1.2 minute spacing per notification
- Exceeds 1-minute spacing requirement ✅
- No database schema changes needed

### Implementation
- Update slider `max` value in `notification_schedule_screen.dart` from 10 to 50
- Update slider `divisions` if needed for granularity
- No UI changes beyond slider update
- Works seamlessly with challenge mode (frequency locked during challenge)

---

## Testing Checklist

### Display Name
- [ ] New user signup shows prompt (can't skip)
- [ ] Existing user with empty name sees prompt on app launch
- [ ] Special characters rejected with correct error message
- [ ] Profanity detected and rejected
- [ ] Valid names save to Firebase Auth + Firestore
- [ ] Welcome message on home screen uses display name
- [ ] Works in English and Indonesian

### Challenge Mode
- [ ] Frequency selection dialog shows 1-50 range
- [ ] Warning dialog displays all rules clearly
- [ ] Timer restricted to 5-10s only during challenge
- [ ] Notification frequency locked during challenge
- [ ] Incorrect answer exits challenge + resets streak
- [ ] Daily requirement checked (streak resets if missed a day)
- [ ] Free-tier earns +1Q per 7-day, +1Q+1C per 14-day
- [ ] Premium-tier earns badge, title, special notification appearance
- [ ] Rewards persist in Firestore
- [ ] Existing streaks: users can choose to keep old rules or start fresh
- [ ] Multi-device sync works (start on phone, check on tablet)

### Notification Limit
- [ ] Slider works from 1-50
- [ ] Setting persists across sessions
- [ ] Works with challenge mode (frequency locked)
- [ ] 50 notifications schedule correctly with 1-hour window

---

## Localization

**Strings to add/update:**
- Display name validation errors (English + Indonesian)
- Challenge mode warning (English + Indonesian)
- Challenge reward descriptions (English + Indonesian)
- Welcome message (already done in previous task)

---

## FAQ Updates Required

- [ ] Display name requirements (allowed/blocked characters)
- [ ] Challenge mode rules and rewards
- [ ] Daily notification limit increase to 50
- [ ] How free users can earn premium feature parity through challenge mode
