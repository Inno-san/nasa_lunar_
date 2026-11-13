"""Build data/osdr_facts.json (saved NASA OSDR fact cards) for the game.

Run from the project root:  python3 tools/build_osdr_facts.py
No API key is needed. For each study below, this script asks the OSDR search API for the real title
and public release date, so the cards always show a real study ID, date and link.

The kid-friendly sentence for each study is written by the team from the study description.
Check each sentence against the study page before the final release.
"""
import datetime
import json
import urllib.parse
import urllib.request

SEARCH = "https://osdr.nasa.gov/osdr/data/search?term={term}&size=5"
LINK = "https://osdr.nasa.gov/bio/repo/data/studies/{id}"

# study id -> (topic, who or what was studied, short text for ages 7-12)
FACTS = {
    "OSD-804": ("Bones", "Mice",
                "Mice lived on the space station for 37 days. Some of their leg bones got weaker. In space, bones carry less weight."),
    "OSD-486": ("Bones", "Mice",
                "Mice flew on the Space Shuttle for 15 days. Bone in the top of their skulls grew, even though leg bones usually get thinner."),
    "OSD-691": ("Muscles", "Mice",
                "Muscles get weaker in space. Scientists studied muscles of mice from the space station to learn why."),
    "OSD-111": ("Muscles", "Mice",
                "Scientists checked how leg muscles of mice changed after 30 days in orbit."),
    "OSD-342": ("Muscles and bones", "Mice",
                "In one study, a special treatment helped mice keep more muscle and bone during spaceflight."),
    "OSD-575": ("Astronaut health", "Humans",
                "Four private astronauts flew for 3 days on Inspiration4. Scientists took blood samples before and after to see how bodies react to space."),
    "OSD-903": ("Immune system", "Humans",
                "Scientists tested blood from two astronauts before and after a space trip. Some changes went back to normal after 3 months."),
    "OSD-751": ("Immune system", "Mice",
                "Space can change how the body fights germs. Scientists studied brains of mice that spent 37 days on the space station."),
    "OSD-918": ("Astronaut health", "Mice",
                "Long space trips can affect muscles, bones, the heart and the body's defences. Scientists studied mouse tissues of different ages."),
    "OSD-655": ("Space food", "Plants",
                "Astronauts grew and harvested leafy greens on the space station. Scientists tested how light colour changes the plants."),
    "OSD-268": ("Space food", "Plants",
                "Lettuce was grown on the space station. Scientists checked it on Earth to see if it was safe and healthy to eat."),
    "OSD-412": ("Space food", "Plants",
                "Scientists checked tiny living things called microbes on space-grown salad leaves to make sure the food is safe."),
    "OSD-622": ("Plants", "Plants",
                "Scientists studied how the leaves of small wheat plants change when they grow in space."),
    "OSD-678": ("Plants", "Plants",
                "Plants react to light in space. On the space station, scientists compared plants grown in light and in the dark."),
    "OSD-615": ("Plants", "Plants",
                "Scientists studied the roots of a small plant called Arabidopsis after it grew on the space station."),
    "OSD-992": ("Radiation", "Human cells in a lab",
                "Space radiation is made of fast, high-energy particles. In lab tests on human cells, it caused damage to DNA, the cell's instruction book."),
    "OSD-210": ("Radiation", "Seeds",
                "Scientists sent seeds on a high-altitude flight over Antarctica to see how cosmic radiation can change them."),
}


def lookup(study_id):
    url = SEARCH.format(term=urllib.parse.quote(study_id))
    with urllib.request.urlopen(url, timeout=60) as r:
        data = json.load(r)
    for hit in data["hits"]["hits"]:
        src = hit["_source"]
        if src.get("Accession") == study_id:
            released = datetime.datetime.fromtimestamp(
                float(src["Study Public Release Date"]), datetime.timezone.utc).date().isoformat()
            return src["Study Title"], released
    raise RuntimeError("Study not found in OSDR: " + study_id)


def main():
    facts = []
    for study_id, (topic, subject, text) in FACTS.items():
        title, released = lookup(study_id)
        facts.append({
            "id": study_id,
            "topic": topic,
            "studied": subject,
            "text": text,
            "study_title": title,
            "date": released,
            "link": LINK.format(id=study_id),
        })
    out = {
        "note": "Saved NASA OSDR data (not live). Fact cards are short, simplified summaries.",
        "source": "NASA Open Science Data Repository (osdr.nasa.gov)",
        "retrieved": datetime.date.today().isoformat(),
        "facts": facts,
    }
    with open("data/osdr_facts.json", "w", encoding="utf-8") as fh:
        json.dump(out, fh, indent=2, ensure_ascii=False)
        fh.write("\n")
    print("Saved data/osdr_facts.json with", len(facts), "facts")


if __name__ == "__main__":
    main()

