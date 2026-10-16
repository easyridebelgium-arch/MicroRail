# Starting a tutorial or seeded city game

Run the project normally (**F5**). On the title screen, choose one of the four
save slots, then **New game in selected slot**. The chooser offers:

- **City sandbox:** enter a whole-number seed or press **Random** beside the seed
  field, then choose 3–8 cities on the 80×50
  map. There are four industry sites. The company starts paused with £5000 and
  no prebuilt stations, rails, locomotives or routes. The same seed and city count
  reproduce the initial layout. The seed remains a decimal string to preserve
  large values exactly. Maximum: `9223372036854775807`.
- **City growth:** Normal, Slower (quarter rates), or Frozen. This rule is saved
  with the company and can be changed in in-game Settings. Growth has limits and
  a day of protection against decline; [rules and feedback](CITY_GROWTH.md).
- **Tutorial — three stations:** the original A/B/C map, £1000, original trains
  and introductory objectives remain available as an explicit choice.

In a running game, **Load → Start fresh game in selected slot** opens the same
chooser. Cancel keeps the current company paused. Choosing New Game replaces the
company in memory and leaves the selected slot's manual save intact. Its previous
manual file becomes the backup only when explicitly saved. Enabled autosaves begin
a fresh interval for the new company and rotate that slot's separate recovery copies
as game time advances; they never replace the manual save.
Invalid seed/count settings disable Start and display a reason.

**Random** picks a different valid non-negative 63-bit seed and immediately updates
validation. It keeps your city count, mode and save slot. You can edit or copy the
result before starting. The button exists in both the title and in-game chooser;
it uses a separate UI-only random generator and never advances a running company's
simulation RNG, finances or saves.

## Building the first city service

For help, click **Guide** beside Map/Goals or use **Menu → First service guide**.
The optional checklist suggests nearby cities and tracks a real first delivery;
it does not make purchases or configure routes for you. [Guide details](FIRST_SERVICE_GUIDE.md).

1. Select **Station** and place one near each of two cities. Four cells below a
   city centre is a useful starting location. The preview shows footprint,
   catchment, price and refusal reasons. A new station normally costs £300.
2. Connect the two horizontal platforms with track. Keep their five platform tiles
   intact and put junctions outside them. Resetting a tool returns to Connect.
3. In **Fleet**, buy a passenger shuttle (£400), select its departure and destination
   stations, then start a service. Close the editor and resume.
4. Save to the desired slot. Continue/Load can restore this company normally;
   see [city save guarantees](CITY_SAVES.md).

Two stations and the shuttle cost £1000, leaving £4000 for track and operations.
The preview quotes those current prices, not an automatic free starter network.
Functional checks build a working first service with positive cash in seven
layouts across seeds 0, 42, 99999 and the maximum seed, including both 3- and
8-city boundaries. This verifies representative startup affordability; long-term
balancing, scenario scoring and later difficulty settings remain future work.

The chooser previews geometry using its own seeded generator. It consumes no live
simulation RNG, finances or train state. Acceptance validates again before starting.
The normal menu's explicit choice overrides development city command-line flags;
those flags and `scenes/dev/city_preview.tscn` remain available for direct testing.

City populations now supply [passenger trip requests](CITY_DEMAND.md), with exclusive
station access and visible unmet-demand reasons. Population remains fixed; growth/
decline is next. Tutorial rewards do not run in the city sandbox. Root save version
is 41; older saves migrate without moving trains or changing accepted passengers.

The shared dialog scrolls and clamps to the viewport. On Godot 4.6.3, the
new-game suite passes 54 headless functional checks covering Random seed selection,
title launch, in-game acceptance/cancel, invalid configuration, save/backup
protection, startup construction and 200% UI scaling. A local visual review remains
useful for appearance and input feel.

## Seeded scenarios

Choose **Seeded scenario** for fixed presets with saved goals. First Connection
requires 40 final journeys from at least two resident origins; Three Town Link
requires 75 from all three origins and disables borrowing. Each origin needs at
least five completions. Both start with £5000 and have no deadline or bonus award.
See [full rules and scope](SEEDED_SCENARIOS.md).
