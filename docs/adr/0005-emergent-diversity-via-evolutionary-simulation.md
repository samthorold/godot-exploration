# Emergent diversity via evolutionary simulation

Species are not hand-authored. The diversity of life in the world emerges from evolutionary simulation: mobile agents share a single rule function parameterised by a heritable **strategy vector** of numerical weights. Offspring inherit their parent's vector with small mutations. Selection pressure — not design — determines what species exist, what they eat, and how they behave. The world simulates for many generations before the player arrives, producing a mature ecosystem the player crash-lands into.

This supersedes the current hardcoded Grazer type.

## Why

The design targets Scavengers Reign's feeling of incomprehensible, teeming diversity — a world so rich that no player could catalogue it. A hand-authored bestiary caps out: every species is one you designed, every encounter is one you planned. Emergent diversity means the world genuinely surprises both designer and player, and the [[trespass cycle]] never runs out of new phenomena to restart against.

The alternative — a large hand-authored bestiary — gives tighter control over individual encounters but doesn't produce the feeling of trespass into something ancient and complete without you. It also doesn't scale: the number of interesting food-web configurations is combinatorial, and authoring them is a content treadmill.

Strategy vectors (numerical weights) were chosen over richer representations (small rule programs, neural networks) because weights are **legible**. The player's only tool is observation, so they need to be able to watch an organism and deduce what it cares about from how it moves. Black-box strategies would make the trespass cycle's mastery phase impossible — you can't learn rules you can't see.

## Consequences

- The current `Grazer.gd` with its hardcoded steering weights, perception radius, and grazing rules becomes a prototype ancestor. The production system replaces it with a single mobile-agent rule function that reads a per-instance strategy vector.
- **All mobile agents share one rule function.** The strategy vector — not the code — determines whether an agent is a grazer, predator, scavenger, or something with no name. Agent "types" are clusters in weight-space that the player recognises, not categories the simulation enforces.
- **Moss rules change.** Conway-style population rules (die if <2 or >4 neighbours) are replaced with aggressive spreading (grow to any adjacent floor with ≥1 moss neighbour). Regulation comes from the food web — being eaten — not from cellular automata. Moss is the base producer; remove consumers and it covers the world.
- **Size with energy cost** determines predation. Agents can only consume agents smaller than themselves, at a cost proportional to prey size. Larger prey has lower success rate. Being large costs more energy to maintain. Trophic levels emerge from size distribution, not from declared roles.
- **Perception is implicit.** No sensor model, no field-of-view for mobile agents. The strategy vector *is* perception — weights encode the compressed evolutionary memory of what mattered to a lineage's ancestors. An agent that flees fast-movers does so because ancestors that didn't were eaten.
- **Warmup is required.** World generation includes an evolutionary simulation phase — many generations of agents living, reproducing, dying, and speciating — before the player spawns. The player arrives into an ancient ecosystem, not a fresh one.
- **Action space is fixed.** All agents can: move (weighted steering), consume tile, consume agent, reproduce. Terrain engineering (agents that reshape the physical environment) is a future addition to this same action space.
- The dynamics-stability failure modes from ADR-0004 apply with greater force. Evolutionary simulation adds new risks: **monoculture collapse** (one strategy dominates and everything else goes extinct), **evolutionary stagnation** (mutation rate too low, populations stop adapting), **arms-race divergence** (predator-prey co-evolution spirals size or speed toward infinity). Tuning mutation rate, energy costs, and size scaling is the primary balancing work.
