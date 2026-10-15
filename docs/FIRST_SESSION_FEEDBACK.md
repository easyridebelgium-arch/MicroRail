# First-session playtest and follow-up

The October 2026 playtest used scripted mouse input on the earlier catalogue
build. It exercised the tutorial, seed 42 with four cities, station construction,
one passenger service and management panels. It did not assess real-monitor feel,
audio/animation, signals, timetables, freight or loans in play.

## Evidence that changes the priorities

- The tutorial already starts its passenger service automatically when A–B is
  connected. A new route wizard is not needed for that first tutorial step.
- A–B adds 15 tiles for £150 and earns £100. Delivering 25 passengers earns the
  next objective reward. The getting-started guide now explains the existing flow.
- The reviewed sandbox service used two £300 stations, £120 track and a £400
  train: £1120 capital. Reported operating profit was £610 over about 10.5 game
  hours, or roughly £58/hour. Approximate simple payback is 19.3 game hours if
  that rate continues, excluding financing and later changes. This is one run,
  not a balance target or a universal seed result.
- The city sandbox starts with £5000. A £380 rail link alone is not most of that
  budget, although choosing a poor first connection can still make startup harder.
  Compare routes and actual operating outcomes before changing starting cash/fares.

## Implemented small fix

| Report | Change |
| --- | --- |
| Starting stations obscured by panels/header | Fresh Map/Goals preferences are collapsed. Explicit existing preferences remain saved. After layout settles, the camera frames the tutorial stations below the header and beside open left panels. Home uses the same framing. |
| Ribbon wraps at 1280 × 720 | Automatic compact layout uses 44 px minimum controls, smaller icons and tighter spacing at smaller logical viewport sizes. At default scale both tutorial and city controls fit a single row. Larger UI scales may wrap to preserve accessibility. |
| Platform connection instructions are difficult to act on | Connect mode marks tutorial loading tiles and both ends of five-tile city platforms with outlines and horizontal arrows. The header and rejection message explain starting at an end and dragging left/right along rails. No invisible snapping changes the chosen construction origin. |
| New tutorial opens with faults the player did not cause | Unbuilt passenger starter route and pre-freight-objective freight route are not current incidents. Freight becomes actionable at its objective; established routes, holds and deadlocks still report normally. An initial header instruction explains A–B and automatic train startup. |

No save schema, fares, train movement, reservations or objective rewards change.
New artwork from the previous batch remains available through the separate review
scene; this fix does not silently replace the artist's toolbar graphics.

## Next UI refinements from this playtest

1. Put optional headway/timetable/journey-target controls behind an Advanced
   scheduling section while retaining route eligibility explanations near stops.
2. Explain demand response, waiting satisfaction, replacement and disabled Fleet
   actions in plain language. Preserve exact refusal reasons and keyboard access.
3. Add measured station queue count/bar with class/capacity distinctions and
   colour-independent cues, before decorative passenger crowds.
4. Continue dialog/ribbon styling consistency, including a proper Station icon.
5. Consider an explicit sandbox first-service shortcut and a nearest-pair/cost
   suggestion, without overriding chosen routes or building automatically.
6. Evaluate distance-sensitive fares and longer-route incentives alongside useful
   destination coverage/growth. Do not change fares from one short-line result.

These fit the early usability work in the [roadmap](ROADMAP.md). Rotating autosaves
and useful-service/city-growth work remain next substantive milestones.

## Validation

`tests/test_first_session.gd` exercises default panels, opening diagnostics, 720p
single-row ribbon (including the sandbox Station button), 720p/1080p tutorial
station visibility, £150 A–B construction, route-damage warnings, five-tile platform
end markers, single-tile extension cost and actionable wrong-side rejection.
Related toolbar, panel-preference, mouse-track, Problems and notification suites
guard existing controls and diagnostic behaviour. These are headless layout and
behaviour checks; final readability and mouse feel still need a real playtest.
