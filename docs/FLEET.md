# Fleet management

The Fleet toolbar button lets you buy, name, assign and sell individual trains.
Each train has a permanent ID, a model and its own speed/capacity upgrades.

## Update and try it

1. Close Godot. In GitHub Desktop select `codex/mouse-track-building`, then click
   Fetch origin and Pull origin. Reopen the existing project and run it.
2. Start a fresh game. Save version 15 contains fleet ownership and assignments;
   older development saves are intentionally not migrated.
3. Open **Fleet**. The game pauses. You begin with one Passenger Shuttle and one
   Log Hauler already assigned to their services, included in the starting game.
4. Choose **Fast Passenger — £650**, then click **Buy**. It appears as Stored.
5. With the purchased train selected, enter a name and click **Rename**.
6. Click **Assign to passenger**. At the start of a fresh game the original train
   is empty at its first stop, so it moves into storage and the new train takes over.
7. Close the window, connect the passenger route if needed, and resume. The fast
   train has fewer seats, higher speed and higher running costs.
8. Pause and inspect a station to buy capacity and speed upgrades separately.
   These upgrades belong to the assigned train and remain with it when stored.
9. Save through the toolbar. Reload restores owned trains, IDs, names, upgrades,
   assignments and the two active trains' journey states.

## Available models

All figures below are base values before upgrades; running cost is charged per
simulation second while a service is active, including ordinary station dwell.

| Model | Purchase price | Capacity | Speed | Running cost |
| --- | ---: | ---: | ---: | ---: |
| Passenger Shuttle | £400 | 20 passengers | 80 px/s | £1/s |
| Fast Passenger | £650 | 12 passengers | 120 px/s | £2/s |
| Log Hauler | £500 | 20 logs | 60 px/s | £1/s |
| Heavy Log Hauler | £650 | 40 logs | 40 px/s | £2/s |

## Replacing a train already in service

A replacement must be compatible with the service. The current train must be empty
and back at the first passenger stop, or at the forest for freight.

1. In Fleet select the assigned train and click **Withdraw service**.
2. Close Fleet and resume. Withdrawal allows the train to complete its round trip,
   deliver its remaining load and park at its first stop.
3. Open Fleet again, select a stored replacement and click **Assign**.
4. The old train becomes Stored, and the replacement is assigned and enabled.
   Close Fleet and resume when ready.

If a disconnected route traps a loaded freight train, repair its route so it can
complete delivery before replacing it. Replacement never deletes its cargo.
The freight loading rule and route stop list belong to the service and remain in
place after a swap. Each train retains its own upgrade levels.

## Storage and sale

- Only one train runs on each of the two current services. Buying spares does not
  increase simultaneous train traffic. Junctions, signals and reservations come next.
- Stored trains are off-map and incur no running costs. Physical depots and stabling
  tracks are future features. The fleet is limited to 100 owned trains for now.
- Only stored trains can be sold. The button shows the refund: half the model price
  plus half the installed upgrades' purchase costs, rounded down.
- Purchases, sales, names, withdrawals and assignments apply immediately. Closing
  Fleet does not undo them. Use the game Save button to retain changes on disk.
- Fleet investment records purchases and upgrades minus sale refunds. The two
  starter trains are provided without a purchase charge.
- Individual train names appear in the fleet list and station inspectors. Service
  names and stop order remain editable separately in **Routes**.

## Validation

Run from the project directory with Godot on PATH:

```sh
godot --headless --path . --script res://tests/test_fleet.gd
```

The integration test writes saves. On Linux, use separate `XDG_CONFIG_HOME`,
`XDG_DATA_HOME` and `XDG_CACHE_HOME` directories to protect your normal game saves.
The cloud checks use Godot 4.6.3. Windows GUI interaction still needs a local check.
