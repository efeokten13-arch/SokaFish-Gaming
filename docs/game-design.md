# Fishing Game: Design Overview (working draft, 19 Nov 2026)

## The idea in one line
A Roblox fishing game. You row a kayak out to fish, land fish with a timing bar (rarer fish are harder), then choose for each catch: keep it in your island's fish pool to earn money per hour, or sell it in the main hall to buy better gear. Better boats unlock new oceans, and the last ocean allows boat-vs-boat battles.

## Core loop
1. Row out from the pier in your boat.
2. Cast with your rod and bait. Rod, bait and fishing spot decide which fish can appear.
3. Reel in with the bar minigame: not too fast, not too slow. A rarer fish means a harder bar.
4. Fill your boat's storage, then row back.
5. For each fish, either keep it in a pool on your private island (passive income) or sell it in the main hall.
6. Spend money on better rod, bait and boats.

## Map (first ocean, built in Studio)
- **Main island:** big island with the Main Hall (sell counter and boat shop), spawn point, and palm trees.
- **L-shaped wooden pier:** boat slips on the inside of the L. The starter kayak waits here.
- **8 private islands:** bean-shaped, each with a small dock and a double fish pool in the bay between the arms.
- **Fishing spots:** near, medium and far from the pier. Roaming fish hordes are planned (you chase them in your boat for better fish).
- **Sea:** 3,000 x 3,000 studs, light turquoise water.

## Boats
- Start: wooden kayak with a paddle, basic rod, basic bait. First fish: cod.
- Rowing: W/S forward and back, A/D steer. Paddle strokes alternate sides.
- Storage slots grow with boat tier: 3, 5, 7, 9. One slot is protected, so its fish are never lost if the boat sinks.
- If you die or your boat sinks, you respawn at the main harbor.
- Bigger and faster boats are bought later with fishing money.

## Oceans
- **Warm ocean:** safe, starter area, treasure chests among the loot.
- **Deep ocean:** better fish, with dangers (details still to come).
- **Mystery ocean:** last area. Players fight boat-vs-boat. Players have no guns, the boats carry cannons.
- You unlock each ocean by owning a good enough boat. Each has its own colours.

## Rarity and income
- Rarity is set by bait tier, rod luck and where you fish. Rarer fish give a harder reeling bar.
- Fish kept in a pool earn money per hour, from about 1 for common fish up to about 10k for the rarest.
- Inspiration: the "Throw Food For Animals" structure (bait tiers, luck stat, income per second, variants and sizes). We copy the structure only, not names, art or numbers.

## Payments (added last, not now)
- Planned, but built after the free game is fun.
- Keep all economy numbers in one place so passes and boosts can plug in later.
- Roblox has extra rules for paid random items (odds disclosure, regional limits), so start with fixed purchases like passes and extra slots.

## Built so far
- Big map (main island, pier, 8 private islands, palms, hall, pool zones, fishing spot markers).
- Wooden kayak that floats, steers and moves, with a rowing animation and a paddle held in both hands.

## Still to design or build
- Reeling bar minigame.
- Fish list and rarity tiers for the warm ocean (cod is the first).
- Sell counter, storage slots (3/5/7/9, one protected), money and saving data.
- Fish pools: capacity, income per hour, offline earnings.
- Fish hordes that roam and a cap on players per horde.
- Deep ocean dangers, treasure chests, ship wars rules (what is lost when a boat sinks).
- Mobile controls for rowing, reeling and cannons.
