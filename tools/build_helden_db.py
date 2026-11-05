#!/usr/bin/env python3
"""
Baut die Helden-Datenbank (assets/data/helden.json) für den E&P Team-Analyzer.
Autor: FGSeRaser – https://github.com/FGSeRaser

Datenquelle: HeroPlan (https://heroplan.github.io, GPL-3.0),
             die Daten stammen aus den offiziellen Spiel-Konfigurationen.

Aufruf:
    python3 tools/build_helden_db.py <pfad-zum-heroplan-repo> [ausgabe.json]

Das HeroPlan-Repo bekommst du mit:
    git clone --depth 1 https://github.com/heroplan/heroplan.github.io.git
"""
import json
import os
import re
import sys
from collections import Counter, defaultdict
from datetime import datetime

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import wissen as W  # noqa: E402

# Wachstumsformel aus dem Spiel (identisch zu HeroPlan utils.js)
RARITY_PARAMS = {
    5: (4, 265, [16, 36]),
    4: (5, 225, [18, 41]),
    3: (6, 123, [23, 52]),
    2: (7, 93, []),
    1: (8, 31, []),
}
STAR_BASE_POWER = {1: 0, 2: 10, 3: 30, 4: 50, 5: 90}
FARBEN = {"Red": "rot", "Blue": "blau", "Green": "gruen", "Yellow": "gelb", "Purple": "lila", "All": "alle"}


def stat_ladder(base, rarity):
    per_level, true_level, lb_adds = RARITY_PARAMS.get(rarity, (0, 0, []))
    per_mil = 1000 + true_level * per_level
    out = [int(base * per_mil / 1000)]
    for add in lb_adds:
        per_mil += 8 * (per_level + add)
        out.append(int(base * per_mil / 1000))
    while len(out) < 3:
        out.append(out[-1])
    return out


def power(rarity, a, d, h):
    return STAR_BASE_POWER.get(rarity, 0) + int(a * 0.35 + d * 0.28 + h * 0.14) + 35


def lade(pfad):
    with open(pfad, encoding="utf-8") as f:
        return json.load(f)


def prefix_lookup(table, hid):
    """Kostüme haben keinen eigenen Namen -> längster passender Präfix (wie HeroPlan)."""
    if hid in table:
        return table[hid]
    best = ""
    for k in table:
        if hid.startswith(k) and len(k) > len(best):
            best = k
    return table[best] if best else None


# ---- Text-Erkennung als Ersatz, falls HeroPlan keine Kategorien hat ----
TEXT_REGELN = [
    (r"\ball enemies\b", "hit_aoe"), (r"\bthe target and nearby\b", "hit_three"),
    (r"\bsingle\b|\bthe target\b", "hit_single"),
    (r"poison", "dot_poison"), (r"\bburn", "dot_burn"), (r"bleed", "dot_bleed"), (r"frost", "dot_frost"),
    (r"water damage", "dot_water"), (r"sand damage", "dot_sand"), (r"curse", "dot_curse"),
    (r"damage over \d+ turns", "dot"),
    (r"defense (by|of) -|defense.*decreas|reduc\w* .*defense", "def_down"),
    (r"attack (by|of) -|reduc\w* .*attack", "atk_down"),
    (r"accuracy", "acc_down"),
    (r"mana generation (by|of) -|mana generation .*(blocked|stopped)", "mana_debuff"),
    (r"mana (by|of) -\d|reduces? .*mana", "mana_cut"),
    (r"dispel", "dispel"), (r"steal", "steal_buff"), (r"cleanse", "cleanse"),
    (r"immune to (new )?status ailments", "ailment_immune"),
    (r"recover \d+%|heal", "heal"), (r"over \d+ turns.*heal|heal.*over \d+ turns", "heal_ot"),
    (r"revive", "revive"), (r"boost(ed)? health", "health_boost"),
    (r"taunt", "taunt"), (r"counterattack|reflect\w* \d+% damage", "counter"),
    (r"dodge", "dodge"), (r"mimic", "mimic"),
    (r"defense (by|of) \+|increases? .*defense", "def_up"),
    (r"attack (by|of) \+|increases? .*attack", "atk_up"),
    (r"mana generation (by|of) \+", "mana_up"),
    (r"minion", "minions"), (r"fiend", "fiend"), (r"silence|sleep|paraly", "special_block"),
    (r"insanity", "insanity"), (r"bypass", "bypass"), (r"never misses", "unmissable"),
    (r"cannot be healed|healing .*-\d+%", "heal_block"),
]


def text_effekte(zeilen_en):
    t = " ".join(zeilen_en).lower()
    out = set()
    for rx, key in TEXT_REGELN:
        if re.search(rx, t):
            out.add(key)
    if out & {"dot_poison", "dot_burn", "dot_bleed", "dot_frost", "dot_water", "dot_sand", "dot_curse"}:
        out.add("dot")
    return out


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    hp = sys.argv[1]
    ziel = sys.argv[2] if len(sys.argv) > 2 else os.path.join(
        os.path.dirname(os.path.abspath(__file__)), "..", "assets", "data", "helden.json")

    chars = lade(f"{hp}/data/characters.json")["charactersConfig"]["heroes"]
    skills_de = lade(f"{hp}/data/heroes_skills_de.json")
    skills_en = lade(f"{hp}/data/heroes_skills_en.json")
    typen = lade(f"{hp}/data/heroes_skill_types.json")
    L = lambda n: lade(f"{hp}/langs_json/{n}_de.json")  # noqa: E731
    LE = lambda n: lade(f"{hp}/langs_json/{n}_en.json")  # noqa: E731
    fancy_en, klassen_en, familien_en = LE("heroes_name_fancy"), LE("class"), LE("family")
    tempo_en, aether_en, skill_namen_en = LE("speed"), LE("aether_power"), LE("skill_name")
    namen, fancy = L("heroes_name"), L("heroes_name_fancy")
    namen_en = lade(f"{hp}/langs_json/heroes_name_en.json")
    klassen, familien, tempo, aether = L("class"), L("family"), L("speed"), L("aether_power")
    skill_namen, quelle = L("skill_name"), L("source")

    heute = datetime.now()
    by_id = {c["id"]: c for c in chars}

    # Kostüm-Nummern (C1, C2 …) je Elternheld nach Datum
    kostuem_nr = {}
    kinder = defaultdict(list)
    for c in chars:
        if c.get("parentHeroId"):
            kinder[c["parentHeroId"]].append(c)
    sonder = {"cute": "Toon", "toon": "Toon", "glass": "Glas", "stylish": "Stilvoll"}

    def sonderart(kid):
        endung = kid.split("_costume_")[-1]
        return sonder.get(endung)

    for parent, ks in kinder.items():
        normal = [k for k in sorted(ks, key=lambda k: (k["canBeReceivedDate"], k["id"]))
                  if not sonderart(k["id"])]
        for i, k in enumerate(normal, 1):
            kostuem_nr[k["id"]] = f"C{i}"
        for k in ks:
            if sonderart(k["id"]):
                kostuem_nr[k["id"]] = sonderart(k["id"])

    passive_tab = {}
    familien_tab = {}
    helden = []
    statistik = Counter()
    unbekannte_tags = Counter()

    for c in chars:
        hid = c["id"]
        datum = c.get("canBeReceivedDate", "")
        if any(x in hid for x in ("trainer", "guestip", "temp1", "rider_hero")):
            statistik["trainer/platzhalter"] += 1
            continue
        if c.get("isGuest") or c.get("trainerType"):
            statistik["gast/trainer"] += 1
            continue
        # Datum 2200 = im Spiel angelegt, aber noch ohne Termin (empuzzled listet sie schon)
        datum_offen = datum.startswith("2200")
        if datum_offen:
            statistik["noch ohne termin"] += 1

        r = c["rarity"]
        a = stat_ladder(c["baseAttack"], r)
        d = stat_ladder(c["baseDefense"], r)
        h = stat_ladder(c["baseHealth"], r)
        werte = [[a[i], d[i], h[i], power(r, a[i], d[i], h[i])] for i in range(3)]

        sk_de = (skills_de.get(hid) or [{}])[0]
        sk_en = (skills_en.get(hid) or [{}])[0]
        spezial = (sk_de.get("skills") or [{}])[0]
        spezial_en = (sk_en.get("skills") or [{}])[0]

        # Passive
        pids = []
        for p in sk_de.get("passiveSkills") or []:
            pid = p.get("id")
            if not pid:
                continue
            pids.append(pid)
            if pid not in passive_tab:
                p_en = next((q for q in (sk_en.get("passiveSkills") or []) if q.get("id") == pid), {})
                passive_tab[pid] = {"t": (p.get("title") or "").replace("\n", " ").replace("- ", ""),
                                    "x": p.get("text") or "",
                                    "te": (p_en.get("title") or "").replace("\n", " ").replace("- ", ""),
                                    "xe": p_en.get("text") or ""}

        # Familie (Bonus-Text einmal pro Familie)
        fam = c.get("family") or ""
        if fam and fam not in familien_tab:
            familien_tab[fam] = {"n": familien.get(fam, fam), "b": sk_de.get("familyBonus") or [],
                                 "ne": familien_en.get(fam, fam), "be": sk_en.get("familyBonus") or []}

        # Effekte aus HeroPlan-Kategorien
        fx = set()
        tagquelle = typen.get(hid)
        if tagquelle is None and c.get("parentHeroId"):
            tagquelle = typen.get(c["parentHeroId"])
        hat_tags = False
        if tagquelle:
            for liste in tagquelle.values():
                for tag in liste:
                    hat_tags = True
                    if tag in W.TAG_MAP:
                        fx.update(W.TAG_MAP[tag])
                    else:
                        unbekannte_tags[tag] += 1
        if not hat_tags:
            fx |= text_effekte(spezial_en.get("lines") or [])
            statistik["text-erkennung"] += 1

        # Passive -> zusätzliche Effekte und Immunitäten
        schutz = {}
        for pid in pids:
            for rx, keys in W.PASSIV_GIBT:
                if re.search(rx, pid):
                    fx.update(keys)
            for rx, s in W.PASSIV_SCHUTZ:
                if re.search(rx, pid):
                    for k, v in s.items():
                        schutz[k] = max(schutz.get(k, 0), v)
        fx = sorted(k for k in fx if k in W.EFFEKTE)

        parent = c.get("parentHeroId")
        name = namen.get(hid) or (prefix_lookup(namen, hid) if parent else None) or \
            (namen.get(parent) if parent else None) or hid
        name_en = namen_en.get(hid) or (prefix_lookup(namen_en, hid) if parent else None) or name

        held = {
            "id": hid,
            "n": name,
            "en": name_en,
            "ti": fancy.get(hid) or (fancy.get(parent) if parent else "") or "",
            "s": r,
            "e": FARBEN.get(c["element"], c["element"].lower()),
            "k": klassen.get((c.get("classType") or "").lower(), c.get("classType") or ""),
            "fa": fam,
            "sp": c["manaSpeedId"],
            "spn": tempo.get(c["manaSpeedId"], c["manaSpeedId"]),
            "d": datum[:10],
            "q": quelle.get(c.get("origin") or "", c.get("origin") or ""),
            "w": werte,
            "b": [c["baseAttack"], c["baseDefense"], c["baseHealth"]],
            "skn": skill_namen.get(c.get("specialId") or "", spezial.get("id") or ""),
            "sk": spezial.get("lines") or [],
            "p": pids,
            "fx": fx,
            "ae": aether.get(c.get("aetherGift") or "", ""),
            # Englisch
            "tie": fancy_en.get(hid) or (fancy_en.get(parent) if parent else "") or "",
            "ke": klassen_en.get((c.get("classType") or "").lower(), c.get("classType") or ""),
            "kk": (c.get("classType") or "").lower(),
            "spe": tempo_en.get(c["manaSpeedId"], c["manaSpeedId"]),
            "skne": skill_namen_en.get(c.get("specialId") or "", ""),
            "ske": spezial_en.get("lines") or [],
            "aee": aether_en.get(c.get("aetherGift") or "", ""),
        }
        if schutz:
            held["im"] = schutz
        if parent:
            held["c"] = parent
            held["ct"] = kostuem_nr.get(hid, "Kostüm")
        if datum_offen:
            held["neu"] = 1
            held["d"] = ""
            if (spezial.get("id") or "") == "tackle":
                held["uv"] = 1  # Fähigkeit im Spiel noch Platzhalter
        else:
            try:
                if datetime.strptime(datum[:10], "%Y-%m-%d") > heute:
                    held["neu"] = 1
            except ValueError:
                pass
        helden.append(held)
        statistik["helden"] += 1
        if parent:
            statistik["kostueme"] += 1

    helden.sort(key=lambda x: (-x["s"], x["n"].lower(), x.get("ct", "")))

    ausgabe = {
        "version": heute.strftime("%Y-%m-%d"),
        "quelle": "HeroPlan – heroplan.github.io (GPL-3.0), Daten aus den offiziellen Spieldateien",
        "autor": "FGSeRaser – github.com/FGSeRaser",
        "effekte": {k: {"l": v[0], "g": v[1], "le": W.EFFEKTE_EN[k]} for k, v in W.EFFEKTE.items()},
        "bedrohungen": {k: {**v, "le": W.BEDROHUNGEN_EN[k][0], "te": W.BEDROHUNGEN_EN[k][1]}
                        for k, v in W.BEDROHUNGEN.items()},
        "leidenBedrohungen": W.LEIDEN_BEDROHUNGEN,
        "rollen": {k: {**v, "le": W.ROLLEN_EN[k]} for k, v in W.ROLLEN.items()},
        "truppen": {
            "passive": {k: {"de": v[0], "en": v[1], "rollen": v[2]} for k, v in W.TRUPPEN_PASSIVE.items()},
            "legendaer": [{"name": n, "k1": k1, "k2": k2, "p": p} for n, k1, k2, p in W.TRUPPEN_LEGENDAER],
            "episch": W.TRUPPEN_EPISCH,
            "manaSchwellen": W.MANA_SCHWELLEN,
            "klassen": {k: {"de": klassen.get(k, k), "en": klassen_en.get(k, k)} for k in W.KLASSEN},
        },
        "familien": familien_tab,
        "passive": passive_tab,
        "helden": helden,
    }
    os.makedirs(os.path.dirname(os.path.abspath(ziel)), exist_ok=True)
    with open(ziel, "w", encoding="utf-8") as f:
        json.dump(ausgabe, f, ensure_ascii=False, separators=(",", ":"))

    print(f"Fertig: {ziel}  ({os.path.getsize(ziel) / 1024 / 1024:.1f} MB)")
    for k, v in statistik.items():
        print(f"  {k}: {v}")
    print(f"  passive: {len(passive_tab)}, familien: {len(familien_tab)}")
    if unbekannte_tags:
        print("  Unbekannte Kategorien:", unbekannte_tags.most_common())


if __name__ == "__main__":
    main()
