# Presence as the only verb

The player has no inventory, no action button, no toolkit — *being-here-now* is the entire vocabulary. Where the player is, how long they stay, and the path they trace are the game's only expressive surface. All consequences (effects on the world, effects on the player) flow from this single coupling, not from separate verbs.

## Why

The game is a [[living-world]]: the world evolves continuously, the player is part of that evolution, and the player's own state evolves through coupling with the tiles they stand on. Adding action verbs (digging, picking up, attacking, crafting) would introduce a *second* causal channel between player and world that competes with presence-coupling for design weight. Keeping presence as the sole verb forces every interesting dynamic to be expressed through *where you choose to be*, which is the discipline the design is built on.

## Considered alternatives

- **Pure witness** (no influence at all). Honest, but too thin — Discovery feels unearned when the player has no dialogue with the world.
- **Light actor** (a small toolkit of gentle verbs — touch, mark, gather). Tends to sprawl into menus and dilutes the central mechanic.
- **Full actor** (inventory, conflict, tools). Drags the design toward roguelike/survival genre conventions the project deliberately doesn't want.
- **One-verb actor** (presence + one explicit verb like *plant*, *name*, *call*). Strong contender; rejected because *presence itself*, made bidirectional, already does what a one-verb design would do, without adding a button.

## Consequences

- "Presence influence" is renamed to **presence coupling** and is bidirectional: the player and the tile under them exchange field values by the same mechanism. The player is a small mobile field-stack; the world is a large static-position one.
- No UI elements for actions. Any future UI is for *perception* (map, player state) rather than *action*.
- Future stakes (deferred) must be expressible as consequences of where the player has been — not as failure to perform an action.
- Future agents (deferred) interact with the world via the same field system, so the discipline scales: the player is not a special case.
