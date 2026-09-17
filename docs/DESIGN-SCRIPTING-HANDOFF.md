# GPT / Fable work split

User direction, September 16: GPT handles physical/visual design, UI and
buttons; Fable handles scripting and gameplay/economy planning.

## Ownership

| Area | Owner |
| --- | --- |
| House exteriors, room appearance, props, materials, textures, icons | GPT |
| UI layouts, button appearance, typography, spacing, visual states, motion specification | GPT |
| Visual assets and Studio model/GUI hierarchies, where tools support them | GPT |
| Luau implementation, including UI construction, bindings and interaction logic | Fable |
| Prices, income/capacity formulas, progression and game rules | Fable |
| Remotes, authoritative transactions, saving, migrations and automated tests | Fable |
| Gameplay/master-plan sequencing | Fable, following user decisions |
| Phone/desktop appearance review against the approved design | GPT |
| User-facing creative and gameplay decisions | User |

GPT may write asset-generation/build tooling when needed to produce art;
runtime gameplay/UI scripting belongs to Fable unless the user explicitly
assigns an exception. GPT supplies exact visual specifications for UI code.

## One feature, one handoff

1. Fable supplies a brief: stable feature/asset IDs, required states, data
   fields/actions, footprint or screen constraints, integration location and
   any measured performance budget. Unknown budgets are marked pending.
2. GPT produces concepts and then the chosen visual assets. The user selects
   art where a design decision is needed. Existing approvals carry forward.
3. GPT supplies a handoff: asset paths/IDs, dimensions, pivot/front direction,
   named connection points, UI hierarchy, palette/fonts, responsive rules,
   state examples, and what remains a mockup rather than a usable model.
4. Fable implements/integrates those assets and runs functional checks.
5. GPT reviews the integrated visuals at phone and desktop sizes. Appearance
   corrections go to the visual asset/spec; code corrections return to Fable.

Suggested visual states: Draft → Chosen → Assets ready → Integrated →
Visually checked. Do not label a concept image a finished Roblox model.

## Repo / Studio coordination

- Use one repo as the source of truth and a shared PROGRESS.md handoff.
- GPT primarily works in `assets/` and feature-specific visual documents.
  Fable primarily owns `src/`, functional tests and planning documents.
- List exact files before a task if either needs the other's area. Avoid
  concurrent edits to shared files such as Config, House, ClientMain and
  PROGRESS; append handoffs serially.
- For simultaneous work, use separate branches/worktrees or separate clones
  with small feature commits. Agree on one active Rojo source for each Studio
  session; do not have two machines/agents overwrite the same live place.
- Manual Studio visual work must be exported/saved into the repo or recorded
  as published asset IDs. A Rojo-managed script edited only in Studio can be
  replaced by the filesystem version.
- This workflow is not authorization to publish, push, create tasks or send
  messages to another agent automatically.

## Current feature split

Fable owns the late-game economy and house ID migration in
`LATE-GAME-ECONOMY-PLAN.md`. Its latest recorded decisions in §11 supersede
earlier recommendations: individual house ownership, schema 26 stable IDs,
accepted modeled pace, and Option A2 rebirth income after RB10.

GPT's next visual work can proceed independently: complete the exterior
concepts for new houses, establish cozy/modern/royal trophy-room designs,
and design the house catalogue UI for individually owned houses. Fable wires
buy/move-in actions, affordability, ownership and trophy-room behavior.
No runtime code changes are required merely to adopt this work split.
