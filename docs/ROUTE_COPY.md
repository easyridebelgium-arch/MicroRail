# Copy a passenger route

1. Pause and open **Routes**. Select the service whose route you want to change.
2. In **Copy route from**, choose another passenger service and press **Copy to draft**.
3. Review the stop sequence, Shuttle/Loop mode, per-leg waypoints and platform choices.
   The target keeps its own name and assigned train; you can rename it separately.
4. Press **Apply**. Route changes require the target train to be empty and physically
   at the proposed first stop. Its starting platform cannot change underneath it.
   Connectivity and consist clearance checks still apply. A refused edit changes nothing.

The source train can be running. Copying reads instructions only; it does not copy
positions, passengers, upgrades, coaches, holds or withdrawal state. Nested waypoint
edits are independent. Close and reopen Routes to discard an unapplied draft.

To expand the fleet, first buy a stored passenger train in **Fleet**, then start a new
passenger service on a clear starting platform. Select that new service in Routes
and copy a route whose first stop matches its physical location. Copying does not
purchase a train or create an additional service, and it is not a reroute command
for a stranded train. Freight remains its fixed Forest–Terminal service.

Stop/Up/Down and mode changes keep waypoints associated with matching station pairs.
When a leg disappears, its directives are removed from the draft and a warning names
the affected leg. Re-add the intended waypoints to the new legs before applying,
or discard the draft. Stops can be dragged to reorder them in the Routes list (`RouteEditor.move_stop_to`, same
result as Up/Down). Fleet can also start a stored passenger train as a copy of an existing
service ("Copy of …" next to Start new passenger service, `Main.duplicate_passenger_service`):
it starts at the source's first stop on platform 1 with its own name and the source's
stops, mode, waypoints, platforms and Auto marks; if the copy cannot be applied the default
service remains and Routes can fix it. Tests: `tests/test_service_duplication.gd`.

## Validation

`tests/test_route_copy.gd` covers deep-copy isolation, live source/target preservation,
draft discard, validated application, refusal on a moving target, save/load,
vanished-leg warnings, freight exclusion and reachable Apply at 200% UI scale.
The copy stores ordinary service instructions, so no save schema change is needed.

## Linked services

Several trains can run one route: in Fleet choose "Linked to …" instead of "Copy of …".
A linked service stores `"link": "<source key>"`; on every Apply, `ServiceRoutes.propagate`
copies the source's stops, mode, waypoints, platforms and Auto marks onto it. It keeps its
own name, train and first-stop platform. Links are one level deep (a link to a linked
service is stored as a link to its source), only passenger services can be linked, and
removing the source unlinks its dependants. In Routes a linked service shows
"Linked to …", its route controls are locked, and **Unlink** keeps the current route as an
independent service. Because each linked train still follows the same single-track hold and
Auto platform rules, trains sharing a route take turns instead of colliding. A source edit
is refused for the whole Apply while any linked train is away from its first stop, like any
other route edit. Tests: `tests/test_linked_services.gd`.

Passenger route copying also carries the source's first/later directional departure
timetables. The target retains its own name, train and independent headway setting;
linked trains use their source's headway and departure tables.
