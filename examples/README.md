# Examples

Interactive Livebook tutorials that build the figures above the fold of the
[project README](../README.md) in stages — face-on, tilted, then animated - while explaining the
library calls and the math behind them.

- [Drawing the Solar System](orbits.livemd) — osculating orbits from JPL DE440: every `Astro.Orbit`
  function, Kepler's equation, and the ellipse-as-unit-circle SVG technique, rendered as two
  diagrams
- [Mapping Nearby Stars](stars.livemd) — the 100 nearest stellar systems, propagated through
  `Astro.Star` and drawn as a rotating 3D map

Open them in [Livebook](https://livebook.dev) (or `livebook server examples` from the repo root).
Each notebook downloads its data on first run and writes the SVG snapshots next to itself.

The NIF build needs a C toolchain and liberfa at link time. Inside this repo's devenv:
`devenv shell`, then open the notebook.

<p align="center">
  <img 
    src="https://raw.githubusercontent.com/sgiath/ex_astro/master/examples/inner-system.svg" 
    width="49%" 
    alt="Inner solar system with the main asteroid belt, true scale"
  />
  <img 
    src="https://raw.githubusercontent.com/sgiath/ex_astro/master/examples/solar-system.svg" 
    width="49%" 
    alt="The nine planets, radially compressed"
  />
</p>

<p align="center">
  <img 
    src="https://raw.githubusercontent.com/sgiath/ex_astro/master/examples/nearby-stars.svg" 
    width="72%" 
    alt="Rotating 3D map of the 100 nearest stellar systems, centered on Sol"
  />
</p>
