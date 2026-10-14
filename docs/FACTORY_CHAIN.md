# Factory and finished goods

The optional factory completes the first Phase 2B processing slice:
**Forest → Sawmill → Factory → Cargo Terminal → Forest**. Installation is optional;
log-only and sawmill-only saves keep their existing services until you purchase it.

## Build and run

1. Pause with empty freight at the Forest. Install the £500 sawmill first.
2. Keep the freight route passing through the sawmill at **18,24**, then horizontal
   track at **23,24**, then the Terminal at **28,24**. A straight rail line is the
   simplest first layout. Leave columns 22–24, rows 22–23 clear for the factory.
3. Keep signals off the factory loading tile and give the whole train room to stop.
4. Click Forest, Sawmill or Terminal and choose **Build factory (£800)**.
   Its required waypoint is added without moving the train or changing its route
   geometry. Unsafe or ambiguous installation returns a reason and charges nothing.
5. Enable freight and resume. Logs unload at the sawmill; timber loads there and
   unloads at the factory; finished goods load at the factory and sell at the terminal.

The factory consumes **1 timber → 1 finished goods every 10 simulation seconds**.
Input and output stores each hold 200 units. The terminal pays **£40 per goods**;
logs/timber unloaded at intermediate industries pay nothing. Existing historical
log/timber sales are retained, without conversion or a second payout.

**Any/Half/Full** controls loading. Raw logs need enough for at least one sawmill
recipe. At a processing stop, Half/Full waits for its requested load or for the
finite available input batch to finish when it cannot fill the train. It never
leaves an enabled service empty. This prevents one shuttle waiting forever for
additional raw materials it must itself return to collect. Full input/output
storage stalls safely; unaccepted cargo remains aboard. Withdrawing an empty train
at either processor sends it back toward the Forest; already loaded cargo finishes
its delivery without collecting additional stock.

Tile/block reservations, switch locks, one-way restrictions and whole-body
clearance govern every leg. Reverse returns to the actual departure stop, including
Factory, keeps cargo aboard and earns no recovery payment. Repair a broken forward
route to resume from the physical position. Intermediate directives cannot be
removed or put in the wrong order while their industries are installed.

Click Factory for recipe, input/output stock, progress and throughput. Accounts
shows both industries, and Find can locate the factory. The initial building uses
the existing facility renderer; custom artwork can follow later.

## Data and saves

`resources/industries/factory.tres` and `resources/cargo/goods.tres` are versioned,
read-only prototypes. Runtime inventory and movement remain separate. Save schema
**38** preserves factory stock/progress and the goods freight stage. Version 37
migrates to an uninstalled, empty factory, preserving sawmill stocks, cash and train
positions. Loading validates stock conservation across both industries, paid
receipts, required loading tracks, directive order and physical freight stage before
mutating the game.

Tests cover production timing, bounded storage, real unload/load/payment, body
clearance at a manual signal, release, physical recovery, atomic invalid-save
rejection, old-save defaults and matching outcomes at 30/60/120 FPS.
