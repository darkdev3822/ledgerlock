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
5. **Claude runs the tests.** The rules test fails if any item for the shipping year has no `verified` date.
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
| (none yet: first review happens in M6, when §2.12 is built) | | |
