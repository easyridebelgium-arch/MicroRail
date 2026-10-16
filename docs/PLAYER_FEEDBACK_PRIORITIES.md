# October 2026 player-feedback decisions

Three reviews of the feature catalogue informed this revision: two attached
written responses and one response supplied in the conversation. These are
qualitative design reviews, not an independently observed usability study or
proof that the simulation is universally safe. Existing supported behaviour and
regression checks remain the implementation baseline.

## Agreed direction

Prefer a clearer first session, visible useful service and reasons to return over
adding many new simulation systems. Keep the current completed network, demand,
freight, finance and accessibility work. The catalogue's feature IDs identify items;
their numerical order does not imply development priority. The catalogue contains
131 IDs (50 current, 3 next, 70 future, 8 deferred), rather than the 112 mentioned
in one review. The separate v1 artwork pack has 112 proposed art entries.

| Sequence | Scope | Acceptance point |
| --- | --- | --- |
| 1 | Small first-service guide (F63) and rotating autosaves (F70) | A newcomer can connect stations, assign a service and recognise a final delivery; guidance is optional/repeatable. Automatic saves are bounded, configurable and cannot replace manual slots or the only valid recovery file on failure. |
| 2 | Useful service and bounded city growth (N01–N03) | Final deliveries are matched to the city request cohorts that generated them. Transfers do not multiply completed totals. Grace periods and unfinished trips prevent immediate penalties. Growth/decline is gradual, bounded, explained and configurable. |
| 3 | Service cards, persistent watchlists and progress (F13/F55) | A loaded game restores its own pinned stable IDs. Cards distinguish carried legs from final journeys and show measured costs/occupancy/punctuality/capacity denials. Optional reports and ranked actionable issues reveal progress without opaque scores. |
| 4 | Focused goals and scenarios (F64/F65), then contracts (F28) | A few achievable objectives and restrictions work on validated starts. Scoring, deadlines and recovery are clear. Loan/economy changes follow playtesting rather than assumption. |
| 5 | River/bridge variety (F37/F38/F58) | Maps require different railway choices. Crossing geometry, cost and connectivity work before elevation, tunnels, traction or weather effects are layered on. |
| 6 | Fair priorities and deeper quality (F02/F18) | Deterministic dispatch avoids starvation; richer reputation rewards documented service quality. Existing advisory arrival targets do not silently become penalties. |

**Priority 1 is now implemented:** [optional guide and first-delivery feedback](FIRST_SERVICE_GUIDE.md), plus [rotating autosaves/recovery](AUTOSAVES.md). [Useful-service measurement](USEFUL_SERVICE.md) is also implemented; [bounded city response](CITY_GROWTH.md) is now implemented as an initial conservative rule. [Service cards and saved company watchlists](SERVICE_PERFORMANCE.md) are implemented. The [actionable network summary](NETWORK_SUMMARY.md) is implemented. Optional progress reports and historical comparisons are next.

## Important design constraints

- A real completed journey is different from joining a queue or being carried on
  one leg. Attribute final completion once; preserve physical transfers and clocks.
- Use request cohorts/maturity windows rather than dividing today's deliveries by
  today's new requests. Long-distance service needs time to demonstrate results.
- Show destination coverage as well as volume. New towns must not collapse while
  their first railway is being built. Growth must not overwrite tracks/buildings.
- Start with an actionable network summary rather than a single health score;
  ordinary dwell and intentional holds are not failures.
- Expand the existing summary-first inspector rather than adding another competing
  diagnostic window. A selected-train blocker trace is the first spatial-overlay
  candidate. Any shortcut is remappable; Space already pauses the simulation.
- Passing-loop templates need clearance, geometry, route and signal-boundary
  validation; a pretty template is not a universal deadlock guarantee.
- Review the supplied tutorial trains, actual first-service costs and loan terms
  before making beginner assistance or bankruptcy recovery rules.
- Measure train-limit pressure before raising limits. One freight service is a
  real current restriction, not an art or UI problem.
- Tiny passenger sprites, simple photo tools and factual journals can proceed in
  small cosmetic batches, but must not delay service/growth clarity.
- Replay, terrain, protected autosaves and robust scenarios are not automatically
  cheap because related data or save code already exists. Keep their scope explicit.
- Maintenance, deeper workforce/finance, weather penalties, rivals and replay remain
  later/optional. Detailed staff rosters, power grids and multiplayer stay deferred.

## Feedback collection

Offer a five-question quick test in addition to the full catalogue questionnaire:

1. Could you start a working service?
2. What first confused you?
3. Could you explain why a stopped train was waiting?
4. What was satisfying or frustrating?
5. What would make you play again?

Record build, mode, seed, play time, display/UI scale and actual tasks for observed
tests. Use genuine screenshots for a shorter tester handout; generated concept
art must not be presented as gameplay. Keep technical save/version details in
the reproducible-problem section of the next public edition.

## Artwork batch accompanying the revision

The [v2 art pack](../art/generated/microrail_pack_v2/README.md) adds 16 feedback/
progress icon candidates and 16 city/station/passenger candidates, each exposed
as a named Godot AtlasTexture. A separate review scene shows large and intended-size
previews. Original artwork is retained. This batch **does not implement** the
first-service guide, rotating autosaves, city growth or service cards by itself.
The guide and autosaves have since been implemented in code; city growth and
service cards remain future work in the revised [roadmap](ROADMAP.md).
