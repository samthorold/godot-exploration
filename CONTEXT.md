# Context

Glossary of canonical terms used in this project. Implementation details belong elsewhere (code, ADRs).

## Core stance

### Living World
The world evolves over time, including in regions the player has already explored. Returning to a known place is as meaningful as venturing into unknown fog — what you remember may no longer be true.

This is the *reason to explore*: not to find static treasure, but to witness and re-witness a place that won't sit still.

### Trespass cycle
The recurring arc a player passes through with each new phenomenon: **panic → mastery → overreach → collapse → symbiosis**. The player arrives as an outsider, misreads the system as hostile, learns to manipulate it, breaks it by pushing too hard, and finally learns to move within it. Each new encounter restarts the cycle at smaller scale. The game teaches by seduction and consequence, not instruction. Exploration is what happens between collapse and symbiosis — the player moves again, but differently.

### Symbiosis
The end-state of a [[trespass-cycle]]. The player becomes useful to the ecosystem and the ecosystem becomes useful to the player. Not submission (passive), not mastery (extractive) — mutual benefit, earned through failure. The Sam trap: a player clever enough to reach mastery but too proud to let the system teach them through collapse never arrives at symbiosis. They keep extracting until the system rejects them.

## World dynamics

### Evolution
Autonomous change in the world over time, driven by [[rule]]s running on the [[substrate]]. The world is *continuously alive* — it changes in front of the player while they watch, not only behind their back. Implemented as a single deterministic function `world_tick(state, presence_history) → new_state` invoked at two cadences:

- **Loaded chunks** (inside view radius) tick at the world rate (default 4 Hz), so the player can observe evolution as it happens.
- **Unloaded chunks** replay-on-reload: when a chunk loads, all elapsed ticks are applied in sequence to advance its state. The result is the same as if the chunk had been ticking all along.

The two-cadence machinery (state retention for unloaded chunks, presence-history recording, replay-on-reload) is not yet implemented; today's prototype keeps all relevant chunks loaded for the duration of a session, so the question doesn't arise. The substrate decision in ADR-0004 makes the simplification well-defined: state at tick T is a deterministic function of state at tick 0 and presence-history through T.

### Traversal cost
Terrain is not binary passable/blocked. Movement cost is a function of the [[tile-agent]]'s current type and state: open Floor ≪ loose Rubble ≪ Cracked ≪ Wall (impassable). Cost can also depend on continuous internal state (e.g. a Floor with thick moss may be slower than bare Floor). Not yet relevant — the first trial substrate has no walls.

## Substrate

The world is a graph of typed [[agent]]s. There are no global fields. Each agent carries its own type and state; rules act per agent, reading neighbours. See [ADR-0004](docs/adr/0004-world-is-a-graph-of-typed-agents.md).

### Agent
The single primitive. Every thing in the world is an agent. An agent has a `type` (e.g. Floor, Wall, Moss, Player) and a small per-instance `state` struct. Each type has a [[rule]] that produces the agent's next-(type, state) given its neighbours. [[Tile-agent]]s have fixed positions on the grid; [[mobile-agent]]s do not. ADR-0001's "player is not a special case" is honoured trivially: the player is one agent type among many.

### Tile-agent
An agent at a fixed grid position. Every tile in the world is a tile-agent. Its type is what determines whether it is a wall, a floor, a moss patch, etc.; its state carries the continuous part (Wall.integrity, Moss.density). [[Type transition]]s let a tile change type mid-tick — a Wall whose integrity hits zero becomes Rubble.

### Mobile agent
An agent whose position is not fixed to a grid cell. The [[player-agent]] is the first; future NPCs will be others. A mobile agent's neighbours include the tile-agent underfoot and (for [[presence-coupling]] purposes) those adjacent to it. Its rule reads those neighbours and produces a next-(type, state, position).

### Tick
The unit of world time. The world advances one tick at a fixed rate (default 4 Hz, tunable), independent of render rate (60 fps). Within a tick, every agent computes its next-(type, state) in parallel (Jacobi-style: all reads from the current tick, all writes go to the next), then everything swaps. Per-type tick interval lets slow types fire less often (e.g. Wall every 100 ticks, Moss every tick) without a separate scheduler.

### Rule
A pure function per agent type: `rule(self, neighbours) → (next_type, next_state)`. The rule may keep the type the same (continuous evolution of state) or transform it (a [[type-transition]]). Rules are local — they read only the agent itself and its neighbours, never global state.

### Type transition
A rule's return of a `next_type` different from the agent's current type. Atomic: the transition fires at tick boundary, replacing the agent's type and resetting its state to the new type's initial state. Type transitions are the substrate's discrete-event mechanism — walls collapsing, spores germinating, things *happening*.

### Dynamics stability
The design constraint that the rule set must avoid four failure modes:

- **Quiescence** — all activity dies out and the world freezes into still-life.
- **Cycle lockup** — periodic, predictable, dead-feeling patterns.
- **Catastrophe propagation** — one rule mistune lets some state spread unboundedly and the world burns down in seconds.
- **Visual incoherence** — too many independent local effects, no large-scale structure, just noise.

Finding the middle is a feel question, not an analytic one — the prototype is the means. Unlike the old field-substrate's mush/butterfly framing, each failure mode here is fixable rule-by-rule rather than by re-tuning a single operator.

## Presence

### Presence
The player's only verb. The player has no toolkit, no inventory, no action button — *being-here-now* is the entire vocabulary. Where you are, how long you stay, what path you trace, what you stand on, what you stand near, *what you look at* — these are the game's expressive surface. All other "mechanics" are consequences of presence, not separate verbs. Presence has at least two modes — [[presence-coupling]] (the foot) and [[gaze-presence]] (the eye) — both expressed as the player-agent being a neighbour of the relevant tile-agents.

### Presence coupling
The strong, single-tile presence relation: the [[player-agent]] is a neighbour of the tile-agent it stands on (and, in principle, the tile-agents immediately adjacent). Those tile-agents' rules read the player as one of their neighbours; the player's rule reads the underfoot tile. No special weighting, no capacity, no separate "coupling" call site — it is the same neighbour-relation every other adjacency uses. "What you stand near" emerges because adjacent tile-agents update from their neighbours each tick, and the player is one of those neighbours; influence radiates outward at the rate the tile↔tile rules choose to propagate it. The eye's contribution is captured separately as [[gaze-presence]].

### Gaze presence
The weak, distributed presence relation: tile-agents in the [[player-agent]]'s field of view are also neighbours of the player, with reduced influence (the rule reads the gaze-neighbour as a distinct neighbour kind with lower weight than the underfoot tile). Observation thus changes the observed — and the observed shapes the observer back — slowly. The same field-of-view computation that drives perception ([[memory]] / [[truth]]) drives the gaze-neighbour relation: visibility *is* a form of presence.

Not yet implemented; today's prototype builds only [[presence-coupling]]. Gaze presence is designed and waiting — it adds an extra neighbour kind to the rule's signature, with no other substrate change.

### Player agent
The player's instance of a [[mobile-agent]]. The single instance of the Player type. Its rule reads the underfoot tile-agent (and eventually gaze-neighbour tile-agents) and produces the player's next state. Future internal dynamics (decay, growth) will be expressed in that rule. The player is therefore *non-static*: they become what they've been near, and what they've been near becomes them. Symmetry with the world (and with future agents) is the point.

## Diversity

### Emergent diversity
The diversity of life in the world is not hand-authored. Species, symbiotic relationships, and ecological roles emerge from the simulation. No two worlds share the same bestiary. The world is deeper than any player can fully catalogue — this is the source of the [[trespass-cycle]]'s endlessness. The only way to understand is to observe.

### Species
A cluster of [[mobile-agent]]s with similar [[strategy vector]]s, drifted apart from other clusters through reproductive isolation and selection pressure. No species is declared — speciation emerges when populations diverge. A species is a pattern the player recognises, not a category the simulation enforces.

### Strategy vector
The heritable trait of a [[mobile-agent]]: a set of numerical weights governing what to approach, what to flee, what to eat, speed, size, reproduction threshold, and similar parameters. All agents share the same reward (survive, reproduce) and the same rule function — strategy vectors determine *how*. Offspring inherit their parent's vector with small mutations. Selection pressure shapes populations over generations. The strategy vector *is* perception — no separate sensor model exists. Weights encode the compressed evolutionary memory of what mattered to a lineage's ancestors.

### Size
A strategy-vector trait that determines an agent's trophic position. Agents can only consume other agents smaller than themselves, at an energy cost proportional to the prey's size. Larger prey costs more energy and has a lower success rate. Being large costs more energy to maintain. This prevents runaway gigantism and creates natural trophic levels without declaring them.

### Warmup
The world simulates for many generations before the player arrives, producing a mature ecosystem with established [[species]], stable food webs, and deep evolutionary history. The player crash-lands into a world that was ancient and whole without them.

### Producer
An agent type that generates energy from nothing — the base of the food web. Moss is the first producer. Producers spread aggressively by default; their regulation comes from the food web (being eaten) and terrain constraints, not from cellular-automata population rules. Remove the consumers, producers take over. Remove the producers, everything above them collapses.

### Ecological roles
Structural roles that keep the world dynamically stable: producers, consumers, decomposers, engineers (organisms that reshape terrain). Roles are not prescribed per species — they emerge from the [[strategy vector]] a lineage happens to have. A species that eats moss and excretes floor is a grazer and a decomposer simultaneously.

## What is deliberately deferred

### Stakes (deferred)
The [[player-agent]]'s internal state can be depleted in principle, but no mechanic currently ends the game when it is. Stakes are deliberately deferred: until [[presence-coupling]] is built and *felt* under the new substrate, we don't know what depletion should mean or how fast it should happen. The intended future shape is rule-driven stakes (player transitions to a faded / ended state when internal state drops below a threshold), introduced once the core coupling dynamic has been lived with.

### Agents (deferred)
The substrate is already a graph of typed agents (ADR-0004) — what was deferred under the old field framing as "agents as a separate addition" is no longer separate. What remains deferred is:

- the **behaviour layer** for non-player mobile agents: goals, pathfinding, perception
- the **off-screen simulation** approach needed because mobile agents may travel across unloaded chunks, at which point [[evolution]]'s two-cadence simplification weakens and a coarser approximation will be needed.

Beyond gameplay variety, mobile agents play a [[dynamics-stability]] role: distributed non-player perturbations help hold the world against quiescence and cycle lockup, in concert with the rule set itself.

## Knowledge

### Memory
The player's record of what the world *was* at the moment they last saw it. Implemented atop the existing explored-bitmap fog of war. Persists across chunk loads. Distinct from [[truth]].

### Truth
The world's current state — what [[evolution]] has made of a place. Only revealed where the player currently has sight. Elsewhere, [[memory]] stands in for it, and may be wrong.

### Map lies
When [[memory]] and [[truth]] disagree because [[evolution]] has run in the player's absence, the player sees [[memory]] until they re-enter sight range, at which point the map snaps to [[truth]]. Stale memory may render visibly degraded (faded, off-colour) to signal untrust. The longer away, the less the map can be trusted.
