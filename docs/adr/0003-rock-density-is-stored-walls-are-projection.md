# Rock density is the stored field; wall-ness is a projection

Each tile stores rock-density as a float, not a boolean wall flag. "Is wall" is a projection: `density > IMPASSABLE_THRESHOLD`. Visible terrain tier and (eventual) traversal cost are also projections of the same field. The boolean wall-flag inherited from the cave generator is removed.

## Why

The design commits to a spectrum for traversal cost (CONTEXT.md, Traversal cost) and to evolution rules whose rates are functions of density (CONTEXT.md, Vitality). Both require continuous values; a boolean can't express either. Vitality's initial condition also wants the continuous landscape, and the operator (ADR-0002) is happiest running on a uniformly-defined field. Keeping the boolean would mean re-doing the same widening three times for three different reasons.

## Consequences

- WorldGen still uses the boolean CA for cave structure, then post-processes to a float density via a neighbourhood-mean pass.
- Rendering can later split into visual tiers without changing the underlying representation.
- The player's "wall-ness" check stays a one-line threshold; no movement-code restructure today.
- Continuous traversal cost is now a one-line change when we want it (replace the threshold with a cost function).
