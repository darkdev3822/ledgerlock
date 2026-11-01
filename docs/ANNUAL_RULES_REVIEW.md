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
| mileage_rate | 2026-11-01 | 2025: 70¢. 2026: 72.5¢ Jan 1-Jun 30, 76¢ from Jul 1 (mid-year change; stored as dated changes). |
| SE tax (2026) | 2026-11-01 | 15.3% (12.4 SS + 2.9 Medicare), $400 minimum, 2026 wage base $184,500 (SE tax page, updated 2026-10-30). |
| SE tax (2025) | 2026-11-01 | 2025 Schedule SE: 92.35% (4a), $400 (4c), 12.4%+2.9% (10, 11), wage base $176,100 (line 7). |
| quarterly dates (2026) | 2026-11-01 | 2026 Form 1040-ES: Apr 15, Jun 15, Sep 15 2026, Jan 15 2027 (skip Jan if filed by Feb 1 2027 and paid). |
| quarterly dates (2025) | 2026-11-01 | 2025 Form 1040-ES: Apr 15, Jun 16, Sep 15 2025, Jan 15 2026 (skip Jan if filed by Feb 2 2026). |
| covers periods (2026) | 2026-11-01 | Pub 505 (2026) payment-period table matches. |
| meals (2025) | 2026-11-01 | Pub 463 (2025 returns, Feb 27 2026): 50% limit. |
| covers periods (2025) | 2026-11-01 | Pub 505 (2025) table matches. |
| **STILL OPEN** | | **2026:** 92.35% (2026 Schedule SE) and meals 50% (2026 Pub 463), both due Jan/Feb 2027; Free File + VITA 2026 limits (Jan 2027). **2025:** 1099-K threshold (instructions Rev. 12-2026 name no year). Then set review.verified in both year files and run the release gate. |
| **Accuracy gaps found** | 2026-11-01 | SE maths ignores the wage base and the 0.9% Additional Medicare Tax ($200k single / $250k MFJ / $125k MFS). Both need the user's W-2 wages, which the app doesn't ask for. Fix in M6. |
| (old row) | | Data drafted 2026-11-01 in M6 part 1: resources.json (10 candidates, all unverified, limits null); mileage_rate + form_1099k_threshold placeholders (null) in 2025/2026.json. First review = next session. |
