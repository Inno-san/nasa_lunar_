# Game architecture

Autoloads: GameState (meters, day, AP, try_action, end_day), Rules (loads data/rules.json), EventManager, NasaData (cached JSON), MessageQueue (delayed comms and food crates).
Scenes: LunarBase with Astronaut (CharacterBody2D), 5 facilities (Area2D + Press E prompt), CanvasLayer with HUD and dashboards.
Signals: facility.interaction_requested(facility_id) -> DashboardManager opens dashboard. Dashboards call GameState.try_action(action_id). GameState.state_changed -> HUD and dashboards refresh.
Day flow: GameState.end_day() runs the resolution order, then EventManager starts the storm phase if scheduled.
