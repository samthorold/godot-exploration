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

The two-cadence machinery (state retention for unloaded chunks, presence_history recording, replay-on-reload) is not yet implemented; today's prototype keeps all relevant chunks loaded for the duration of a session, so the question doesn't arise.

The function is pure modulo `presence_history`, which records where the player has been so [[presence-coupling]] can be replayed for unloaded chunks.

### Traversal cost
Terrain is not binary passable/blocked. Tiles carry a movement cost on a spectrum: open floor ≪ loose rubble ≪ packed earth ≪ cracked wall ≪ solid wall (impassable). Cost varies with the underlying terrain state and (eventually) with field values like [[vitality]].

## Fields

The world is modelled as a small stack of scalar fields per tile, evolving under [[evolution]]. Visible terrain is a *projection* of the current field values, not a stored type. Adding a new field (moisture, heat, etc.) is the canonical way to extend the world model.

### Rock density
The original field, inherited from the cave generator. Stored per-tile as a continuous float in [0, 1]; structural terrain (wall, cracked wall, rubble, floor) and traversal cost are *projections* of this field, not separately-stored types (ADR-0003). The substrate other fields run on top of.

### Vitality
A scalar measure of "how alive" a tile is. Driven by *coupled growth-and-decay rules whose rates are functions of the local field stack* — chiefly [[rock-density]] today, other fields later. Both rules run continuously; neither wins permanently. The result is visibly churning patterns (Game-of-Life-like) that nonetheless *mean something* about the substrate (ecology-like): the player can read regions by their vitality character. Chosen as the second field specifically because it remains dynamic *with no player input* — its visible motion is the proof that the world is alive.

### Dynamics stability
The design constraint that the vitality field must land between two failure modes: *mush* (diffusion dominates, all character smooths into uniform value) and *butterfly* (sensitivity dominates, a single perturbation cascades across the world). The eventual growth/decay rules and the distributed perturbations from [[agents]] are what hold the middle; without either, the field tends toward mush. Finding the middle is a feel question, not an analytic one — the prototype is the means.

Today's prototype is deliberately positioned at the mush end: only diffusion runs, no growth/decay, no agents. This is *not* a bug to work around — it is the trajectory we want to observe firsthand before designing the counterweights, because the eventual rules will be designed against intuitions earned by feeling mush actually happen. Do not add a placeholder counterweight to "fix" the prototype's homogenisation; that decision was made deliberately.

### Local mixing
A pass within [[evolution]], not a parallel mechanism. The single local rule by which two cells of a field exchange value: symmetric, conservative, diffusion-shaped, *mass-weighted by [[field-capacity]]*. Runs inside `evolve` over an adjacency graph that includes both tile↔tile edges and [[mobile-field-cell]]↔underfoot tile edges — the player is just a (high-capacity) node in that graph. There is no separate "coupling" rule; coupling is the same pass applied to the same graph. The conserved quantity across any coupled pair is `m·v`, not `v` alone — bigger reservoirs barely move per exchange, smaller ones equilibrate fast.

### Field capacity
A per-cell scalar `m` setting how much each cell resists changing its field value during [[local-mixing]]. Tile cells have `m = 1`. [[Mobile-field-cell]]s have `m > 1`. The operator equilibrates pairs at the mass-weighted mean `(m_a·v_a + m_b·v_b) / (m_a + m_b)`, so a high-capacity cell pulls neighbours toward itself while barely shifting. This is the structural encoding of the player (and future agents) acting as a stabiliser of chaotic regions and a perturber of harmonious ones: in a uniform region a high-capacity differently-valued node creates gradient (introduces dynamics); in a fluctuating region the same node low-pass-filters local variation (dampens). No special-case code — just a per-cell property the operator already consumes.

### Presence
The player's only verb. The player has no toolkit, no inventory, no action button — *being-here-now* is the entire vocabulary. Where you are, how long you stay, what path you trace, what you stand on, what you stand near, *what you look at* — these are the game's expressive surface. All other "mechanics" are consequences of presence, not separate verbs. Presence has at least two modes — [[presence-coupling]] (the foot) and [[gaze-presence]] (the eye) — both realised as edges in the same [[local-mixing]] graph.

### Presence coupling
The strong, single-tile presence edge: ([[mobile-field-cell]], underfoot tile) in the [[local-mixing]] adjacency graph. Bidirectional and conservative by construction, because the operator is. Not a distinct rule or a separate call — it is the same diffusion pass already running over tile↔tile edges, with mobile cells included as nodes wherever they currently are. "What you stand near" emerges from neighbouring tile↔tile edges in the same pass; there is no separate "footprint" mechanism. The eye's contribution is captured separately as [[gaze-presence]].

### Gaze presence
The weak, distributed presence edges: every tile in the [[mobile-field-cell]]'s field of view is connected to the cell by an additional edge in the [[local-mixing]] graph, at lower coupling strength than the footprint edge (smaller effective κ, larger capacity-asymmetry, or both). Observation thus changes the observed — and the observed shapes the observer back — by the same operator, slowly. No new mechanism, no new pass: just additional edges of the existing graph. The same field-of-view computation that drives perception ([[memory]] / [[truth]]) drives coupling — visibility *is* a form of presence.

Not yet implemented; today's prototype builds only [[presence-coupling]] (the foot). Gaze presence is designed and waiting — it will slot in as additional edges in the existing diffusion pass, with no other code changes.

### Mobile field-cell
A field-stack with a position that moves through the world. The [[player-field-stack]] is the first instance; future [[agents]] will be others. A mobile cell couples to whichever tile it currently occupies via [[local-mixing]] — the same operator that mixes tile↔tile — so the player is never a special case in the field code. Mobile cells have [[field-capacity]] > 1 (tiles default to 1), which is how their stabilising/perturbing effect on the field is encoded structurally rather than via special-case behaviour.

### Player field-stack
The player's instance of a [[mobile-field-cell]]. Carries at minimum [[vitality]]. Evolves via [[presence-coupling]] with the tile underfoot and (eventually) its own internal decay/growth rules, mirroring how tiles evolve. The player is therefore *non-static*: they become what they've been near, and what they've been near becomes them. Symmetry with the world (and with future agents) is the point.

## What is deliberately deferred

### Stakes (deferred)
The player's [[player-field-stack]] can be depleted in principle, but no mechanic currently ends the game when it is. Stakes are deliberately deferred: until [[presence-coupling]] is built and *felt*, we don't know what depletion should mean or how fast it should happen. The intended future shape is field-driven stakes (player fades when their internal fields drop below a threshold), introduced once the core coupling dynamic has been lived with.

### Agents (deferred)
The "C layer" — other entities moving across chunks with their own goals — is deferred. Today the world is terrain + fields + player. When agents arrive, they will be [[mobile-field-cell]]s using the same [[local-mixing]] rule as the player; no field-code change is required to add them. Beyond gameplay variety, agents play a [[dynamics-stability]] role: distributed non-player perturbations help hold the vitality landscape against diffusion's homogenising tendency, in concert with the eventual growth/decay rules. What is deferred is their *behaviour layer* (goals, pathfinding) and the off-screen simulation needed because they may move across unloaded chunks — [[evolution]]'s two-cadence simplification weakens at that point and a coarser approximation will be needed.

## Knowledge

### Memory
The player's record of what the world *was* at the moment they last saw it. Implemented atop the existing explored-bitmap fog of war. Persists across chunk loads. Distinct from [[truth]].

### Truth
The world's current state — what [[evolution]] has made of a place. Only revealed where the player currently has sight. Elsewhere, [[memory]] stands in for it, and may be wrong.

### Map lies
When [[memory]] and [[truth]] disagree because [[evolution]] has run in the player's absence, the player sees [[memory]] until they re-enter sight range, at which point the map snaps to [[truth]]. Stale memory may render visibly degraded (faded, off-colour) to signal untrust. The longer away, the less the map can be trusted.
