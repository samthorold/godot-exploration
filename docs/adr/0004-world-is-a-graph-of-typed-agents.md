# World is a graph of typed agents

The world is a graph of **typed agents** updated by synchronous tick. Tile-agents occupy fixed grid positions; mobile-agents move (the player is the first). Every agent has a `type` (Floor, Wall, Moss, Rubble, …) and a small per-instance state. Every type has a rule that, given the agent and its neighbours, produces a next-(type, state). The world ticks at a fixed rate (default 4 Hz, tunable), independent of render rate. Per-type tick intervals let slow types fire less often than fast types without separate scheduling.

This supersedes ADR-0002 and ADR-0003.

## Why

ADR-0002 committed to mass-weighted local mixing — conservative diffusion on the tile graph plus mobile-cell↔tile edges. In session it became clear the operator is *mathematically defined* to converge to a uniform field on a closed graph: mush isn't a tuning problem, it's the operator's signature behaviour. The design's language ("ecology-like", "Game-of-Life-like", "distinctive places", "walls participate") is the language of agent-based modelling. We were paying field costs to express agent intuitions.

A reaction-diffusion patch (add a non-conservative term) would fix the math while keeping the field framing, but it doesn't fit the design language: tile *kinds* become thresholded regions of one field rather than first-class differently-behaving things, and adding heterogeneity means stacking projections rather than typing agents.

Pure ABM aligns the substrate with the design intent at the cost of giving up the elegant single-operator architecture. We accept that cost: per-type rules replace one-rule-with-thresholds.

The tick model was preferred over per-frame continuous-time updates because (a) the ABM literature is written in ticks and we want to read it without translation, (b) the two-cadence simplification (CONTEXT.md / Evolution) becomes well-defined — state at tick T is a deterministic function of state at tick 0 and presence-history through T, (c) the chunky "world breathes in beats" aesthetic fits "Game-of-Life-like" better than imperceptible per-frame drift, (d) decoupling render rate from world rate is bog-standard fixed-timestep game-loop code.

## Consequences

- ADR-0002 superseded. There is no single mixing operator; per-type rules replace it. Conservation, when desired, is per-rule discipline rather than an architectural property.
- ADR-0003 superseded. Tile types are first-class stored values, not projections of a density field. Per-agent continuous state survives (Wall may have `integrity`, Moss may have `density`), but as agent-local state, not as a global field.
- ADR-0001 strengthened. The player is one agent among many. "Presence" is adjacency: the player's underfoot and adjacent tile-agents read the player as one of their neighbours; the player's rule reads them. No special weighting, no capacity parameter.
- Continuous traversal cost (formerly derived from density) is now derived from the per-agent state of the tile under the player.
- The deferred Agents layer in CONTEXT.md is no longer a separate addition — the substrate is already agent-based. What remains deferred is the *behaviour layer* of mobile-agent rules (goals, pathfinding) and cross-chunk simulation.
- New failure modes replace mush: **quiescence** (everything settles into still-life), **cycle lockup** (predictable periodic patterns), **catastrophe propagation** (one rule mistune burns the world down), **visual incoherence** (no large-scale structure). Each is fixable rule-by-rule rather than by re-tuning a single operator.
- The current prototype's `vitality` and `density` fields, the `evolve` per-frame pass, and the mass-weighted `_mix` are anachronisms. A substantive rewrite is implied; not done in the same step as this decision.
