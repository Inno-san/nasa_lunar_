"""Build data/donki_cached.json (saved NASA DONKI records) for the game.

Run from the project root:  python3 tools/fetch_nasa_data.py
No key is needed: DONKI is read from the CCMC address (api.nasa.gov/DONKI returned 404 when tested).
Never commit an API key. If you ever need one, pass it as an environment variable (NASA_API_KEY).

The three storms below are real May 2024 solar flares. The gameplay severity (1-3) is chosen by the
team and is NOT a measured radiation dose.
"""
import datetime
import json
import os
import urllib.request

BASE = "https://ccmc.gsfc.nasa.gov/DONKI/WS/get/{ep}?startDate={s}&endDate={e}"

# game event id -> (DONKI flare id, severity, plain-language text for kids)
PICKS = {
    "storm_1": ("2024-05-07T05:58:00-FLR-001", 1,
                "A medium-strong solar flare. A flare is a sudden flash of energy from the Sun."),
    "storm_2": ("2024-05-10T06:27:00-FLR-001", 2,
                "A very strong solar flare. Bursts like this can send extra radiation toward space."),
    "storm_3": ("2024-05-14T16:46:00-FLR-001", 3,
                "One of the strongest flares of that month. Astronauts would shelter from storms like this."),
}


def fetch(endpoint, start, end):
    url = BASE.format(ep=endpoint, s=start, e=end)
    with urllib.request.urlopen(url, timeout=60) as r:
        return json.load(r)


def main():
    flares = {f["flrID"]: f for f in fetch("FLR", "2024-05-01", "2024-05-31")}
    records = []
    for event_id, (flr_id, severity, text) in PICKS.items():
        f = flares[flr_id]
        records.append({
            "game_event": event_id,
            "severity": severity,
            "donki_id": f["flrID"],
            "type": "Solar flare",
            "flare_class": f["classType"],
            "peak_time": f["peakTime"],
            "link": f["link"],
            "kid_text": text,
        })
    out = {
        "note": "Saved NASA DONKI data (not live). Severity 1-3 is a game label, not a measured dose.",
        "source": "NASA DONKI, CCMC (ccmc.gsfc.nasa.gov/DONKI)",
        "retrieved": datetime.date.today().isoformat(),
        "records": records,
    }
    os.makedirs("data", exist_ok=True)
    with open("data/donki_cached.json", "w") as fh:
        json.dump(out, fh, indent=2)
    print("Saved data/donki_cached.json with", len(records), "records")


if __name__ == "__main__":
    main()
