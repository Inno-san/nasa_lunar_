# Lunar Outpost: Mission 01 - Mechanics (v1.1)
All numbers are game values. Source of truth: data/rules.json.

## Overview
Top-down 2D lunar base. E (or tap) near a facility opens its dashboard: Power Station, Life Support, Greenhouse, Radiation Shelter, Communications Room. 10 days, 6 AP/day. Walking is free. No day timer; only storm countdowns (20 s warned, 10 s surprise).

## Start values (max)
Battery 60 (100), Oxygen 70 (100), Food 45 (100), Water 30 (40), Health 100 (100), Shield 1 (3), Science 0.

## Power
Solar +36/day, base load 6. Life Support Eco/Normal/High: cost 8/14/20, oxygen +4/+10/+16. Greenhouse Off/Low/High: cost 0/8/14, water 0/3/5, food 0/5/10, food arrives start of day N+2. Shield upkeep 2 per level. Default balance 36-6-14-8-2 = +6.
Payment order: base load, Life Support, shield upkeep, Greenhouse. If short, cut: (1) Greenhouse off, (2) Life Support to Eco, (3) shield upkeep suspended (shield = level 0 for storms that day), (4) Life Support off. Battery never below 0. Explain every cut.

## Oxygen, food, water
Oxygen change = LS output - 10; at 0: health -25. Food -8/day; at 0: health -10. Water +2/day; if too low, greenhouse drops one level and the player is told.

## Storms
Gameplay severity 1-3 (team-assigned; not a measured dose). Damage = ceil(base x (1 - 0.2 x shield) x lockdown_factor); base 10/20/35.
Lockdown: 4 PU, factor 0.5, pauses greenhouse that day. Battery < 4 PU: factor 0.75, battery to 0, console explains. Not in shelter in time: 1.0.
Warnings: severity 1 gets 1-day warning; severity 2-3 only if a forecast arrived.
Damage (no lockdown / lockdown): S1 shield0..3: 10,8,6,4 / 5,4,3,2. S2: 20,16,12,8 / 10,8,6,4. S3: 35,28,21,14 / 18,14,11,7.

## Comms (2-day delay, gameplay simplification)
Forecast 1 AP, 4 PU: arrives start of day N+2, shows storms in days N+2..N+4. Advice 1 AP, 4 PU: arrives in 2 days. Resupply 1 AP, 6 PU, send by day 6, arrives in 3 days: +25 oxygen or +25 food or +15 water.

## Actions
Experiment 2 AP/10 PU (+10 science). Change LS mode 1 AP. Emergency oxygen 1 AP/6 PU (+10). Change greenhouse mode 1 AP. Upgrade shield 2 AP/12 PU (max 3). Repair pump 2 AP/8 PU. Repair panel 2 AP.

## Day-end order
1 Power. 2 Oxygen. 3 Food (add crates, subtract 8). 4 Water. 5 Storm phase. 6 Health (penalties; else if no storm +3). 7 Next day: refill AP, deliver messages, show event.

## Win/loss
Win: end of day 10 with health >= 50. Stars: 1 win; 2 health >= 80; 3 also science >= 30. Lose: health reaches 0 (friendly replay).

## Test (day 5)
Start: battery 50, oxygen 70, food 30, water 26, shield 2, LS Normal, GH Low. Actions: pump fix (2 AP, 8 PU), forecast (1 AP, 4 PU), experiment (2 AP, 10 PU) -> battery 28. Resolution: power 28+36-6-14-8-4 = 32; oxygen 70; food 30+5-8 = 27; water 26-3+2 = 25; health 100.

## Educational requirements
Daily plain-language feedback; OSDR fact cards with source and date; storm screen shows the linked DONKI record and says damage is simplified; tap-to-explain tooltips; Credits with NASA attribution.
