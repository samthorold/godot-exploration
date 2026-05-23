# Local mixing is one pass inside `evolve`

> **Superseded by [ADR-0004](0004-world-is-a-graph-of-typed-agents.md).** Mass-weighted diffusion was found to be defined-to-mush on a closed graph; the substrate is now a graph of typed agents updated by synchronous tick. The text below is preserved for history.


The vitality field — and any field added later — evolves via a single local mixing pass inside the world's one update function, `evolve(state, Δt, presence_history) → state'`. The pass runs over an adjacency graph that includes both tile↔tile edges and mobile-cell↔underfoot-tile edges; the player (and future agents) are nodes in the same graph. There is no separate "coupling" mechanism, no separate "coupling tick," and no call site outside `evolve`. Coupling is the same pass applied to the same graph.

## Why

ADR-0001 forbids the player from being a special case, and CONTEXT.md commits to `evolve` being the sole world-update function. Treating "coupling" as a thing outside `evolve` would create a second world-update path that violates both: state would change in two places, the player would get its own update mechanism, and the two-cadence (real-time / replay-on-reload) simplification would break because half the state-change wouldn't replay. Treating mobile cells as nodes in the same diffusion graph keeps state changes localised to `evolve` and the player non-special.

## Consequences

- Conservation between two coupled cells is a property of the operator, not a per-edge choice. The conserved quantity is `m·v` (mass-weighted by field capacity), not `v` alone — this is what makes mobile cells natural stabilisers/perturbers without special-case code.
- One rate parameter for the diffusion pass, not one per edge type.
- "What you stand near" emerges from tile↔tile edges in the same pass — no separate footprint mechanism.
- Adding an agent in future is "instantiate a mobile cell with a position"; the diffusion pass picks it up because it's a node in the graph.
- The prototype must run the diffusion pass over the full graph (tile↔tile and player↔tile) in the same call — splitting them would re-introduce the special case.
