# Station amenities

Each passenger station (A, B, C) can buy three amenities from its station panel,
below the Train capacity and Speed buttons. Building needs the game paused and enough money.

| Amenity | Price | Waiting limit | Arrivals | Needs |
|---|---|---|---|---|
| Shelter | £300 | +50 | +5% | — |
| Waiting room | £700 | +100 | +10% | Shelter |
| Kiosk | £400 | +25 | +10% | — |

Every station starts at a waiting limit of 100 and no bonus. Effects add up per
station and never affect other stations. Train capacity still never creates passengers;
only amenities raise arrivals.

## How the bonus works

Arrivals use whole passengers. The percentage is carried in hundredths per station
(`carry`, 0–99), so a 25% bonus gives 375 arrivals over 100 batches of 3. No extra
random numbers are used: a station with no amenities generates exactly the old batch,
so existing seeded runs are unchanged. If the queue is full, surplus arrivals are lost
as before. Recovery overflow above the limit is still never discarded.

## Saves

Save version **26** adds `amenities: {owned: {a: [...], b: [...], c: [...]}, carry: {...}}`.
Version 25 saves migrate with no amenities. A load is rejected when an amenity is unknown or
duplicated, a Waiting room lacks its Shelter, or a carry is outside 0–99.

Code: `scripts/core/amenities.gd` (pure rules), station panel and generation hooks in
`main.gd`. Test: `tests/test_amenities.gd`.
