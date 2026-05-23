# Context

Glossary of canonical terms used in this project. Implementation details belong elsewhere (code, ADRs).

## Core stance

### Living World
The world evolves over time, including in regions the player has already explored. Returning to a known place is as meaningful as venturing into unknown fog — what you remember may no longer be true.

This is the *reason to explore*: not to find static treasure, but to witness and re-witness a place that won't sit still.

### Discovery (design register)
The primary emotional pull. The player explores because there is *stuff out there* — distinctive places, landmarks, things worth walking to. Sits on top of [[living-world]]: what's out there is also changing.

## World dynamics

### Evolution
Autonomous change in the world over time, driven by cellular-automata-style rules running forward. The world is *continuously alive* — it changes in front of the player while they watch, not only behind their back. Implemented as a single deterministic function `evolve(state, Δt, presence_history) → new_state` invoked at two cadences:

- **Loaded chunks** (inside view radius) tick in real time, so the player can observe evolution as it happens.
- **Unloaded chunks** replay-on-reload, advancing by the elapsed Δt in a single call. This is purely an optimization; the result is the same as if the chunk had been ticking all along.

The function is pure modulo `presence_history`, which records where the player has been so [[presence-influence]] can be replayed for unloaded chunks.

### Traversal cost
Terrain is not binary passable/blocked. Tiles carry a movement cost on a spectrum: open floor ≪ loose rubble ≪ packed earth ≪ cracked wall ≪ solid wall (impassable). Cost varies with the underlying terrain state and (eventually) with field values like [[vitality]].

## Fields

The world is modelled as a small stack of scalar fields per tile, evolving under [[evolution]]. Visible terrain is a *projection* of the current field values, not a stored type. Adding a new field (moisture, heat, etc.) is the canonical way to extend the world model.

### Rock density
The original field, inherited from the cave generator. Determines structural terrain — wall, cracked wall, rubble, floor — and the substrate other fields run on top of.

### Vitality
A scalar measure of "how alive" a tile is. Driven by *coupled growth-and-decay rules whose rates are functions of the local field stack* — chiefly [[rock-density]] today, other fields later. Both rules run continuously; neither wins permanently. The result is visibly churning patterns (Game-of-Life-like) that nonetheless *mean something* about the substrate (ecology-like): the player can read regions by their vitality character. Chosen as the second field specifically because it remains dynamic *with no player input* — its visible motion is the proof that the world is alive.

### Presence
The player's only verb. The player has no toolkit, no inventory, no action button — *being-here-now* is the entire vocabulary. Where you are, how long you stay, what path you trace, what you stand on, what you stand near — these are the game's expressive surface. All other "mechanics" are consequences of presence, not separate verbs.

### Presence coupling
Presence is *bidirectional*. The player is itself a small mobile field-stack (see [[fields]]) and when standing on a tile, the player's fields and the tile's fields exchange. The player gives and takes simultaneously, by the same mechanism, in opposite directions where gradients differ. Replaces the earlier (one-way) "presence influence" framing: the player is not a perturbation *imposed on* the world but a *part of* it, coupled by the same field rules.

### Player field-stack
The player carries their own field values — at minimum [[vitality]]. These evolve via [[presence-coupling]] with the tile underfoot and (likely) their own internal decay/growth rules, mirroring how tiles evolve. The player is therefore *non-static*: they become what they've been near, and what they've been near becomes them. Symmetry with the world is the point.

## What is deliberately deferred

### Stakes (deferred)
The player's [[player-field-stack]] can be depleted in principle, but no mechanic currently ends the game when it is. Stakes are deliberately deferred: until [[presence-coupling]] is built and *felt*, we don't know what depletion should mean or how fast it should happen. The intended future shape is field-driven stakes (player fades when their internal fields drop below a threshold), introduced once the core coupling dynamic has been lived with.

### Agents (deferred)
The "C layer" — other entities moving across chunks with their own goals — is deferred. Today the world is terrain + fields + player. Once agents exist, [[evolution]]'s two-cadence simplification weakens (agents may have moved across unloaded chunks) and a coarser off-screen simulation will be needed.

## Knowledge

### Memory
The player's record of what the world *was* at the moment they last saw it. Implemented atop the existing explored-bitmap fog of war. Persists across chunk loads. Distinct from [[truth]].

### Truth
The world's current state — what [[evolution]] has made of a place. Only revealed where the player currently has sight. Elsewhere, [[memory]] stands in for it, and may be wrong.

### Map lies
When [[memory]] and [[truth]] disagree because [[evolution]] has run in the player's absence, the player sees [[memory]] until they re-enter sight range, at which point the map snaps to [[truth]]. Stale memory may render visibly degraded (faded, off-colour) to signal untrust. The longer away, the less the map can be trusted.
