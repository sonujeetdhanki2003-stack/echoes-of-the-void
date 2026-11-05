# ECHOES OF THE VOID — asset specification (shared by all helpers)

Godot project: game  (the parent worker owns it; helpers write
ONLY into their own output folders listed in their brief, never into scripts/ or scenes/, and never run Godot on this project).
Story, areas, enemies, cinematics: DESIGN.md (read it first).

## Art direction
Realistic, cinematic, AAA-inspired hard sci-fi (think Dead Space / Alien Isolation / Prometheus, but original). Believable
industrial design: panel seams, bolts, chamfers/bevels on every hard edge (bevel modifier, 2-3 segments, harden normals),
greebles, hazard stripes, stencilled labels. The alien organism ("the Echo") is crystalline flesh: dark violet-black
glassy crystal growths with inner cyan/violet glow (emission), wet dark tissue between the crystals. Colour keys:
station = off-white / gunmetal / safety orange accents; Echo = black-violet crystal + cyan/magenta glow.

## Technical conventions (every model)
- Blender 4.2.3 headless, Python scripts kept in your own task dir so every asset can be regenerated:
  blender -b --python-exit-code 1 -P script.py   (start it with output to a log file
  and start_new_session=True; poll the log; `timeout -k 5 N` on everything; one Blender process at a time per helper).
- Export: glTF 2.0 binary (.glb), +Y up (exporter default), apply modifiers, export only the asset (no cameras/lights),
  `export_animation_mode='ACTIONS'` so every action is its own clip, `export_force_sampling=True`, 30 fps,
  `export_def_bones=True` for characters, no shape-key animation unless noted. Godot extracts embedded textures itself.
- Units: metres, real scale. Origin: centre of the base / between the feet on the ground plane (z=0 in Blender).
- Facing: the character/creature/weapon faces Blender **-Y** ("front" view).
- Materials: Principled BSDF only (base colour, metallic, roughness, normal map, emission). Image textures ≤1024 px for the
  astronaut and the boss, ≤512 px for everything else (JPG for colour/ORM, PNG only where alpha is needed). Prefer baked or
  procedural-then-baked detail over raw procedural nodes (Godot can't read Blender node trees, only image textures and
  constant values). Name materials meaningfully; glowing parts use a material whose name starts with `Emit` (emission colour
  set, strength 2-6); glass = name starts with `Glass` (alpha blend, roughness low).
- Poly budgets (triangles): astronaut ≤ 30k, sentinel ≤ 25k, stalker ≤ 15k, brute ≤ 25k, herald ≤ 45k, each weapon ≤ 8k,
  kit pieces ≤ 3k, props ≤ 6k, shuttle ≤ 25k, spire ≤ 8k.
- Animations: 30 fps, in place (no root motion; the root bone stays at the origin, the hips may bob), loops perfectly
  seamless (last frame == first frame pose), proper animation principles: anticipation, follow-through, overlapping
  action, weight shift, arcs, easing; no robotic linear interpolation; no foot sliding beyond what in-place cycles need.
- For every .glb write a sidecar JSON next to it (same name, .json): dimensions, triangle count, bone names, clip list with
  {name, seconds, loop, ground_speed_mps for locomotion cycles, events: {hit: s, footsteps: [s..], ...}}, sockets
  (bone or node names) and notes. The parent codes against this file.
- Verify every GLB in a SMALL scratch Godot project inside your own task dir (copy nothing big): headless
  `godot --headless --path <scratch> --import` then a tiny script that loads the glb, prints the node
  tree, skeleton bone names, AnimationPlayer clip names and lengths, and the AABB. Fix anything Godot reads differently.
- Look at your work: render small EEVEE preview sheets (≤ 800 px wide, a few poses/angles) and LOOK at them (attach_image
  skill) before calling anything done; iterate until it looks genuinely good. Delete preview renders when done.
- Disk is tight (keep the box above 4 GB free; check `df -h /home/user`): your scratch must stay under 400 MB; delete frame
  renders, temp .blend backups (`*.blend1`) and caches as you go.
- Licences: everything you make yourself is original. If you use any third-party file (only CC0: Poly Haven, ambientCG,
  Kenney, Quaternius; NO Mixamo, NO accounts, NO payments), open its licence page, confirm CC0, and add a line to
  game/docs/credits/<your-area>.md with name, source URL, licence.
