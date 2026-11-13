"""Build cached NASA DONKI JSON for the game. Run locally; never commit your API key.
Usage: NASA_API_KEY=xxx python tools/fetch_nasa_data.py
Tries api.nasa.gov/DONKI (key) first, then the CCMC address (ccmc.gsfc.nasa.gov/DONKI/WS/get).
Test both before the event; the CCMC path is inferred from the old kauai host format.
"""
import json, os, urllib.request, urllib.error

KEY = os.environ.get("NASA_API_KEY", "DEMO_KEY")
SOURCES = [
    ("https://api.nasa.gov/DONKI/{ep}?startDate={s}&endDate={e}&api_key=" + KEY),
    "https://ccmc.gsfc.nasa.gov/DONKI/WS/get/{ep}?startDate={s}&endDate={e}",
]

def fetch(endpoint, start, end):
    last = None
    for tpl in SOURCES:
        url = tpl.format(ep=endpoint, s=start, e=end)
        try:
            with urllib.request.urlopen(url, timeout=30) as r:
                return json.load(r)
        except (urllib.error.URLError, urllib.error.HTTPError, ValueError) as err:
            last = err
    raise RuntimeError(f"All DONKI sources failed for {endpoint}: {last}")

if __name__ == "__main__":
    data = {
        "note": "Saved DONKI records (not live)",
        "SEP": fetch("SEP", "2024-01-01", "2024-12-31"),
        "FLR": fetch("FLR", "2024-05-01", "2024-05-31"),
        "CME": fetch("CME", "2024-05-01", "2024-05-31"),
    }
    os.makedirs("data", exist_ok=True)
    with open("data/donki_cached.json", "w") as f:
        json.dump(data, f, indent=1)
    print("Saved data/donki_cached.json")
