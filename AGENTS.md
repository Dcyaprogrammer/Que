# Que

Use Lua and LÖVE for this single-player mahjong roguelike.
Read `SYSTEM_PROMPT.md` and `doc/idea.md` when present before working on the game;
these local documents are currently ignored by Git. The idea document distinguishes
confirmed goals from rules that still need prototype validation.

The first prototype validates one stage: adjust the hand, choose when to score,
and spend limited resources. Unfinished hands can score. Tile value, local groups,
and completed hands must each matter. Expand to shops and multi-stage runs after
the core loop has been playtested.

## Project skills

Read the matching skill before its task. Skills are installed in `.agents/skills/`
from [awesome-gamedev-agent-skills](https://github.com/gamedev-skills/awesome-gamedev-agent-skills).

- LÖVE code, configuration, or debugging: [love2d-core](.agents/skills/love2d-core/SKILL.md).
- Tile instances, deck zones, scoring, effects, or run rules: [card-game](.agents/skills/card-game/SKILL.md).
- A playable experiment to validate a mechanic: [prototype-fast](.agents/skills/prototype-fast/SKILL.md).
- Animation, scoring feedback, timing, or input feel: [game-feel](.agents/skills/game-feel/SKILL.md).
- Generating, sourcing, or validating art: [create-game-assets](.agents/skills/create-game-assets/SKILL.md).

Adapt engine-neutral patterns to Lua/LÖVE and follow this project's rules when a
skill's example assumes a different game. Consult the official
[LÖVE wiki](https://love2d.org/wiki/) and [source](https://github.com/love2d/love)
for the installed engine version when implementing engine behavior.
