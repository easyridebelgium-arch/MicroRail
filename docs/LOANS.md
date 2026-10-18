# Bank loans

Open **Accounts → Bank loans**. The Bank opens paused and shows terms, available
cash, principal, accrued interest, overdue payments and the next billing time.
Borrowing and early repayment are available while paused. Close and resume to run.

## Initial offers

One loan can be active at a time. No opening fee or early-repayment fee applies.

| Amount borrowed | Hourly principal instalment | First payment | Total if paid on time |
| --- | --- | --- | --- |
| £1,000 | £100 | £110 | £1,055 |
| £2,500 | £250 | £275 | £2,640 |
| £5,000 | £500 | £550 | £5,275 |

Interest is **1% of outstanding principal per game hour**, accrued on simulation
ticks. Ten hourly principal instalments are scheduled, starting one hour after
borrowing. One game hour is **60 simulation seconds**: the first payment takes
one real minute at 1×, about 30 seconds at 2×, 12 seconds at 5× or 6 seconds at 10×,
provided the simulation runs without pauses/slow frames. Pausing stops accrual and
payments. These are game-hour rates, not annual real-world banking rates.

The game uses whole pounds. Fractional interest is retained precisely as an integer
tick remainder, then rounded up at each billing or early payoff. The displayed
on-time totals include this rounding. Interest falls as principal is repaid.

## Automatic payments and arrears

On each due tick, available positive cash pays billed interest first, then due
principal. Payments cannot push cash below zero. A shortfall remains overdue and
is paid automatically from later available income, after that tick's normal train
expenses and receipts. Existing operating costs can still make cash negative.

Interest continues on unpaid principal, including after the scheduled ten-hour
term if principal remains unpaid. There is no compound interest or extra late fee.
New borrowing is disabled until the old principal and interest are fully settled.
A missed bill produces a visible notice and a loan-overdue event. Accounts/Bank
continue showing the arrears even after the notice expires.

**Repay full balance early** pays all remaining principal plus accrued interest
and cancels future bills. The button displays the exact payoff and is disabled
when available cash is insufficient. A failed repayment changes neither cash nor
the loan. Loan proceeds and principal repayments are financing flows; interest paid
is shown separately from the status bar's operating profit.

## Persistence and implementation

Save version **27** stores principal, accrued/billed interest, fractional carry,
remaining instalments, due amounts, exact next/last ticks and lifetime payment
ledgers. Version 26 migrates to zero debt; existing cash, routes, positions and
simulation clock are preserved. All four slots and their backups retain independent
loan state. Validation rejects fractional or inconsistent debt, stale due ticks,
invalid ledgers and impossible instalment counts before applying a load.

`scripts/core/loans.gd` owns pure integer finance rules. The coordinator credits
borrowed cash once, advances debt in fixed simulation order, deducts payments once
and records borrowing/payment/overdue events. The Bank and Accounts only display
those rules. Variable rates, multiple lenders, credit ratings, insolvency rules,
loans against assets and cash-flow forecasts remain later economy work.

Validation: `tests/test_loans.gd` covers quotes, full terms, arrears, interest-first
partial payment, no cash overdraft, early payoff, same-tick duplicate prevention,
30/60/120 FPS equality, paused accrual, v26 migration and v27 save/load validation.

## Optional icon

Export a transparent, native **24 × 24 px** PNG with its symbol inside 20 × 20 px:

`assets/ui/toolbar/icons/loans.png`

The Bank loans button uses this file if present; it retains its text label while
the asset is absent. Keep the editable source in
`art/ui/toolbar/source/loans.kra`. Generate a source image using the prompt below,
then use the existing Krita guide to trim, simplify and export at native size.

> Create an original standalone UI icon for MicroRail, a low-resolution railway
> management game. Crisp pixel art, flat front-facing view, no perspective or
> isometric angle. A compact steel-blue bank silhouette with a triangular roof
> and three sturdy columns, beside one small gold coin and a simple inward arrow
> suggesting borrowed funds. Clear silhouette, minimal detail, consistent thick
> pixel strokes, upper-left highlights. Restrained palette: dark navy #1B2836,
> steel #52687A, pale highlights #E7EEF4, blue #54B9EC and muted gold #D8AE48.
> Designed to remain readable as a 20 × 20 pixel symbol centred on a transparent
> 24 × 24 canvas. Icon only: no button frame, words, currency lettering, watermark,
> scenery, checkerboard pattern, gradients, blur or soft shadows. Match the attached
> toolbar icons if provided. Use genuine alpha transparency.
