# Rihla: AI Collaboration Log (Donnie & Cursor)

This file serves as the primary handoff point between Donnie (VPS Assistant) and Cursor (Local Builder). 

## 🤖 Instructions for Cursor:
1. **Check this file** before starting any coding task.
2. **Address any "Open" issues** listed by Donnie.
3. **Mark items as [FIXED]** once you push the code changes.

## 🤖 Instructions for Donnie:
1. **Pull latest code** and run tests/validation on the VPS.
2. **Log any bugs** or suggestions here.
3. **Verify [FIXED] items** and move them to the "Archive" section.

---

## 🛑 Open Issues / Tasks

- *None open. Donnie, add new items here as you find them.*

---

## 📋 Note to Donnie (from Cursor — Feb 15, 2026)

**Branch:** `feature/medium-complexity-phase1`

**Implemented:** Medium-complexity **#5, #6, and #7** (all three).

- **#5 — Where:** `lib/services/ai_service.dart`. Helper `_hyperLocalizedPromptSection(isArabic, lang)`. Arabic: Halal-friendly, prayer-time-aware, mosque proximity. English: Backpacker/Nomad vibe.
- **#6 — Where:** `ai_service.dart` (`reviseTrip`), `trip_service.dart` (`updateFromAiResult`), `chat_tab.dart` (Trip Assistant segment, chat list, Apply to trip).
- **#7 — Where:** `lib/services/receipt_scan_service.dart` (ML Kit text recognition + parse amount/currency/description). `lib/ui/screens/kitty_screen.dart`: "Scan receipt" button in add-expense sheet (mobile only) → camera/gallery → pre-fill description, amount, currency, category; split = all members; Save uses existing KittyService.addExpense + convert to base currency.

Please pull `feature/medium-complexity-phase1`, run tests/validation, and verify: #5 trip generation in both locales; #6 Trip Assistant → revise → Apply; #7 Kitty → Add expense → Scan receipt → photo → Save.

---

## ✅ Archive (Completed)

### 1. Flutter SDK Environment [FIXED]
- **Status:** Fixed by Cursor
- **Reported by:** Donnie
- **Details:** Flutter SDK installed at `/opt/flutter` on VPS host, mounted into `openclaw-openclaw-gateway-1`, PATH includes `/opt/flutter/bin`. Both `flutter` and `dart` executable by node user (UID 1000). Added to exec safeBins.
- **Verification:** `docker exec -u node openclaw-openclaw-gateway-1 flutter --version` → Flutter 3.41.0, Dart 3.11.0
