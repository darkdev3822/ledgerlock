# Annual tax-rules review (owner + Claude, step by step)

**Not optional.** The app tells people about money and deadlines. Wrong numbers hurt them. Claude must walk the
owner through this, one step at a time, and must not skip it or let it slide to "next session".

## When it's due (Claude checks the date at the start of EVERY session)
| When | Why |
|---|---|
| **Dec 1 - Jan 31** every year | IRS publishes next year's mileage rate (usually mid/late Dec) and Free File / VITA limits (Jan, before filing season). |
| Any time a new `assets/tax_rules/<year>.json` is added or edited | New data = new check. |
| Any time the owner hears of a mid-year IRS change (e.g. a mid-year mileage rate change) | Rules can change mid-year. |
| Before every store release | Nothing unverified ships. |

## Steps (one at a time; Claude waits for the owner's answer after each)
1. **Claude prepares a draft.** Copies last year's file to the new year, marks every changed value and every
   resource as `"verified": null`. Shows the owner a short list: item, old value, what needs checking.
2. **Owner opens each official page in their own browser** (Claude gives the link, one item at a time). Claude
   may also read the page itself (WebFetch) to cross-check, but **the owner's confirmation is what counts**.
3. **For each item, the owner confirms 3 things:** the page still exists at that address, the name is right, and
   the number/limit/date matches. Claude never fills a number from memory.
4. **Claude records it:** `"verified": "YYYY-MM-DD"` on the item, plus the source URL. If something has moved or
   ended (a program can be discontinued), Claude removes it or updates it, and tells the owner.
5. **Claude runs the release gate:** `LL_RELEASE=1 flutter test test/rules_release_test.dart`. It lists every
   unverified item (year files: `review.verified`, `keyFigures`; `resources.json`: each resource + income limits).
   It must pass before any release. Unverified items are also hidden in the app, so nothing wrong is ever shown.
6. **Claude logs it** in STATUS.md (date, what changed) and commits: `Rules review <year>: verified by owner`.

## What gets checked (starter list; SPEC §2.12)
Tax numbers: standard mileage rate, SE tax rate and wage base, quarterly due dates, 1099-K reporting threshold,
meals %, any category/line changes.
Resources (name, URL, who it's for, any income limit): IRS Free File, VITA, TCE, Taxpayer Advocate Service,
IRS payment plans, Low Income Taxpayer Clinics, IRS Self-Employed Tax Center, IRS 1099-K page, IRS disaster
relief page, SCORE.

## Log
| Year file | Reviewed on | Notes |
|---|---|---|
| resources.json | 2026-11-01 | All 10 checked with the owner (screenshots). Moved URLs fixed (LITC, Free File). Free File $95,000 and VITA ~$70,244 recorded as 2025 (season just closed; page names no year: owner to confirm); 2026 limits "unpublished" (Free File reopens Jan 2027). Payment plans: fees noted. SCORE: owner chose keep + privacy note (location, ad partners). Candidate for next review: IRS "Gig economy tax center". |
| 2026.json form_1099k_threshold | 2026-11-01 | $20,000 in more than 200 transactions, per platform (page updated 2026-10-28). |
| (still open) | | Year files: quarterly dates, SE numbers, meals %, mileage 2025/2026, 1099-K 2025. |
| (old row) | | Data drafted 2026-11-01 in M6 part 1: resources.json (10 candidates, all unverified, limits null); mileage_rate + form_1099k_threshold placeholders (null) in 2025/2026.json. First review = next session. |
