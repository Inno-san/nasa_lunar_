# Project context for AI coding agents
Project: Lunar Outpost: Mission 01 (NASA Space Apps Challenge 2026). Godot 4, GDScript only, Web export (single-threaded). Audience: ages 7-12.

Rules for the agent:
1. data/rules.json is the single source of truth for balance numbers. Never hardcode them.
2. Read docs/game_mechanics.md before changing any rule. If a rule is ambiguous, ask.
3. UI never keeps its own copy of game values; listen to GameState.state_changed.
4. No live NASA API calls in the game. Use cached JSON in data/ and label it as saved NASA data.
5. Never commit API keys. No external plugins.
6. Use placeholder art until sprites arrive; keep art swappable.
7. Short, plain language for kids; explain terms in tooltips.
8. Small commits on feature branches; open pull requests.
9. Game values are simplified, not real engineering specs or NASA measurements; say so in the UI.
