<!--TOKENS-->
**Dev Tool Usage** — updated 2026-08-05
Total: In 4.3K · Out 1.2M · CacheW 6.3M · CacheR 105.7M
| Model | In | Out | CacheW | CacheR |
|---|---|---|---|---|
| claude-opus-5 | 537 | 338.2K | 2.5M | 47.0M |
| claude-fable-5 | 3.6K | 495.9K | 2.8M | 45.1M |
| claude-sonnet-5 | 186 | 380.7K | 1.0M | 13.6M |
<!--/TOKENS-->

# AccountGuardian

Account-level `Expert Advisor` for `MetaTrader 5`.

## What it is

A protection layer that runs on the whole account, not on a single trade
and not on a single strategy. The goal is to enforce account-level risk
limits in real time, independent of other advisors running in parallel
on the same terminal.

## Who it is for

A single-account operator running multiple advisors or manual trading on
the same account, who needs one backstop that applies to everything.

## Why it matters

A regular advisor only protects the trades it opened itself. Cumulative
daily loss, margin overuse, or manual trades opened by mistake are not
stopped by anyone. This layer is the last line of defense.

## Current status

No code written yet. The repo currently contains only management files
and git scaffolding. Exact operational settings are still open.

## Known constraints

* `MQL5` is the target stack. No library or helper framework chosen yet.
* The advisor cannot close the terminal or disconnect from the broker.
  Maximum enforcement is closing positions, deleting pending orders, and
  blocking new opens.
* The advisor only runs on one open chart. If the chart is closed, the
  protection stops working.
* `OnTick` is not guaranteed to run when the market is closed. A separate
  timer is needed for checks that do not depend on quotes.

## Tone

Direct, no filler.

---

# AccountGuardian

`Expert Advisor` ברמת חשבון עבור `MetaTrader 5`.

## מה זה

שכבת הגנה שרצה על החשבון כולו, לא על עסקה בודדת ולא על אסטרטגיה בודדת.
המטרה היא לאכוף מגבלות סיכון ברמת החשבון בזמן אמת, בלי תלות ביועצים אחרים
שרצים במקביל על אותו טרמינל.

## למי זה

מפעיל חשבון יחיד שמריץ מספר יועצים או מסחר ידני על אותו חשבון, וצריך בלם
אחד שחל על הכל.

## למה זה חשוב

יועץ רגיל מגן רק על העסקאות שהוא עצמו פתח. הפסד יומי מצטבר, שימוש יתר
במרג׳ין, או עסקאות ידניות שנפתחו בטעות לא נעצרים על ידי אף אחד. השכבה הזו
היא הבלם האחרון.

## סטטוס נוכחי

טרם נכתב קוד. הריפו מכיל כרגע רק קבצי ניהול ותשתית `git`. ההגדרות
התפעוליות המדויקות עדיין פתוחות.

## מגבלות ידועות

* `MQL5` הוא הסטאק המיועד. לא נבחרה עדיין ספרייה או מסגרת עזר.
* יועץ אינו יכול לסגור את הטרמינל או להתנתק מהברוקר. אכיפה מקסימלית היא
  סגירת פוזיציות, מחיקת פקודות ממתינות, וחסימת פתיחה חדשה.
* יועץ רץ רק על גרף פתוח אחד. אם הגרף נסגר, ההגנה מפסיקה לפעול.
* `OnTick` לא מובטח לרוץ כשהשוק סגור. טיימר נפרד נדרש לבדיקות שלא תלויות
  בציטוטים.

## טון

עברית ישירה. בלי מילוי. מונחים טכניים, שמות קבצים ופקודות נשארים
באנגלית בתוך גרשיים אחוריים או בבלוק קוד נפרד.
