# Game architecture

Autoloads: Rules (loads data/rules.json), NasaData (cached JSON), EventManager (loads data/events.json), AudioManager (procedural tones + walk/SFX mute hooks), Explain (7 tap-to-explain science term modals), GameState (meters, day, AP, delayed comms and food crates, try_action, end_day).
Scenes: MainMenu (briefing card, 3-slide tutorial, credits, 7 science word buttons) and LunarBase with Astronaut (CharacterBody2D + AnimatedSprite2D + PetFollower), 5 facilities (Area2D + 2D building sprites + Press E/Click prompt), CanvasLayer with HUD, DashboardManager, StormOverlay, DaySummary, EventPopup, and EndScreen.
Signals: facility.interaction_requested(facility_id) -> DashboardManager opens dashboard. Dashboards call GameState.try_action(action_id). GameState.state_changed -> HUD and dashboards refresh.
Day flow: GameState.end_day() runs the resolution order, then starts the StormOverlay countdown phase if a storm is scheduled on that day.
