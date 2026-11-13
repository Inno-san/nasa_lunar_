# Data sources

| Source | Used for | Live or cached |
|---|---|---|
| NASA DONKI (CCMC) | Real flare, CME and SEP records that inspire the storm scenarios (days 4, 8, 10) | Cached JSON (data/donki_cached.json) |
| NASA OSDR | Educational fact cards (space biology and astronaut health) | Cached JSON (data/osdr_facts.json) |
| OSDR RadLab | One real ISS dose-rate reading for the shelter dashboard (labelled as ISS data) | Cached |
| CSA food production toolkit | Kid-friendly wording for greenhouse cards | Cached text |
| NASA Image and Video Library | Optional menu and credits images | Cached |

## DONKI address note
CCMC replaced the host kauai.ccmc.gsfc.nasa.gov with ccmc.gsfc.nasa.gov; endpoint paths after /DONKI/ are unchanged (per the CCMC DONKI page). The fetch script tries api.nasa.gov/DONKI with a key first, then the CCMC address. Test before relying on either.

## Notes
- Get a personal NASA API key. DEMO_KEY is heavily rate-limited (30 per hour, 50 per day per IP).
- Gameplay severity (1-3) is assigned by the team and is not a measured dose.
- The Mars Rover Photos and legacy APOD APIs are archived; do not depend on them.
- Label cached data as saved NASA data in the game. Never present static data as live.
