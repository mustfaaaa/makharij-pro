"""Build frontend/assets/quran/quran_scripts.json: the Quran in the two scripts
the reader offers -- Uthmani (Madinah mushaf) and IndoPak -- lined up word for
word with the text the app already has.

Why a second text rather than a second font
-------------------------------------------
A Quran font only looks right with the text it was made for. The King Fahd
Complex's two fonts each come with their own encoding of the Quran:

  Uthmani  KFGQPC HAFS Uthmanic Script   <- quran.com `text_qpc_hafs` (per word)
  IndoPak  KFGQPC Nastaleeq              <- quran.com `text_qpc_nastaleeq_hafs`

Both fonts draw the ayah-end circle from the ayah's own digits, and the IndoPak
one draws the sign above that circle as well -- the ruku (ع), the sajda, and the
waqf signs that sit at an ayah's end -- from a glyph the text places right after
the number. So those marks are in the right places because the text says so, not
because this tool guesses.

Why lined up with quran_full.json
---------------------------------
quran_full.json is the text the recitation analysis indexes words by: the
backend's word mapping reads it, live highlighting reports positions in it, and
every stored verdict points into it. It must not change. So each ayah here is a
list of display strings *parallel to that file's space-separated tokens*: token
i of quran_full.json is drawn as entry i here, in the chosen script. The Basmala
the app prefixes to ayah 1 is included, and so are the waqf-mark tokens -- as
empty strings where the script carries its marks inside the words instead.

Words normally correspond one to one. Where a script spells a word as two
(بَعْدَ مَا / بَعْدَمَا) or one as two words, the tokens are matched by their
letters instead; the report at the end lists every such ayah and checks the
letters of every word in the Quran.

Ruku numbers (IndoPak counting, 558) and sajda numbers come from the same API.

    backend/.venv/Scripts/python.exe ml/tools/build_quran_scripts.py

Downloads are cached under ml/data/quran_com/ (git-ignored), so a rebuild after
the first run is offline.
"""
from __future__ import annotations

import json
import sys
import time
import unicodedata
import urllib.request
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
SOURCE = REPO / "frontend" / "assets" / "quran" / "quran_full.json"
TARGET = REPO / "frontend" / "assets" / "quran" / "quran_scripts.json"
CACHE = REPO / "ml" / "data" / "quran_com"

API = ("https://api.quran.com/api/v4/verses/by_chapter/{c}?words=true&word_fields=text_qpc_hafs"
       "&fields=text_qpc_hafs,text_qpc_nastaleeq_hafs,ruku_number,sajdah_number,rub_el_hizb_number,"
       "hizb_number,juz_number,page_number,manzil_number&per_page=50&page={p}")

# Tokens of quran_full.json that are a mark rather than a word: the waqf signs,
# the start of a hizb quarter (۞) and the place of sajda (۩).
MARK_TOKEN_CHARS = set("ۖۗۘۙۚۛۜ۞۩")
HIZB = "۞"
SEP = "|"   # never occurs in Quran text


def is_mark_token(token: str) -> bool:
    return all(c in MARK_TOKEN_CHARS or unicodedata.category(c).startswith("M") for c in token)


def basmala_prefix_len(surah: int, ayah: int, tokens: list[str]) -> int:
    """Mirrors the app (surah_details_screen._basmalaWords) and the backend."""
    return 4 if ayah == 1 and surah not in (1, 9) and len(tokens) > 4 else 0


# ── fetching ────────────────────────────────────────────────────────────────

def fetch_chapter(c: int) -> list[dict]:
    path = CACHE / f"{c:03d}.json"
    if path.exists():
        return json.loads(path.read_text(encoding="utf-8"))
    verses, page = [], 1
    while True:
        request = urllib.request.Request(API.format(c=c, p=page),
                                         headers={"User-Agent": "curl/8.5.0", "Accept": "application/json"})
        for attempt in range(4):
            try:
                with urllib.request.urlopen(request, timeout=60) as response:
                    data = json.load(response)
                break
            except OSError as exc:
                print(f"  retry {c}:{page} ({exc})")
                time.sleep(2 + 3 * attempt)
        else:
            raise SystemExit(f"could not fetch surah {c}")
        verses += data["verses"]
        page = data["pagination"].get("next_page")
        if not page:
            break
        time.sleep(0.15)
    CACHE.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(verses, ensure_ascii=False), encoding="utf-8")
    return verses


# ── matching words by their letters ─────────────────────────────────────────

_LETTER_FOLD = {
    "أ": "ا", "إ": "ا", "آ": "ا", "ٱ": "ا", "ٰ": "ا", "ى": "ي", "ی": "ي", "ۦ": "ي",
    "ک": "ك", "ڪ": "ك", "ۥ": "و", "ؤ": "ء", "ئ": "ء", "ة": "ه", "ۃ": "ه",
}


def skeleton(text: str) -> str:
    """Bare letters, so two spellings of one word compare equal-ish."""
    out = []
    for ch in text:
        ch = _LETTER_FOLD.get(ch, ch)
        cat = unicodedata.category(ch)
        if not cat.startswith("L") or 0xFB50 <= ord(ch) <= 0xFEFF:
            continue          # marks, digits, spaces, waqf glyphs
        if out and out[-1] == ch:
            continue          # shaddah / madd doubling is spelled differently
        out.append(ch)
    return "".join(out)


def _distance(a: str, b: str) -> float:
    """Edit distance between two skeletons, as a share of the longer one."""
    a, b = skeleton(a), skeleton(b)
    if not a and not b:
        return 0.0
    prev = list(range(len(b) + 1))
    for i, ca in enumerate(a, 1):
        row = [i]
        for j, cb in enumerate(b, 1):
            row.append(min(prev[j] + 1, row[j - 1] + 1, prev[j - 1] + (ca != cb)))
        prev = row
    return prev[-1] / max(len(a), len(b))


def assign_by_letters(words: list[str], tokens: list[str]) -> list[list[int]]:
    """Which script tokens make up each of `words`, matched by their letters.

    An alignment over both sequences where a word takes one token, two tokens
    (بَعْدَمَا against بَعْدَ مَا), or shares one token with the next word (إِلْ +
    يَاسِينَ against إِلۡ يَاسِينَ -- drawn on the first word, the second left
    empty). The cheapest path by letter distance wins.
    """
    n, m = len(words), len(tokens)
    INF = float("inf")
    cost = [[INF] * (m + 1) for _ in range(n + 1)]
    back: list[list[tuple | None]] = [[None] * (m + 1) for _ in range(n + 1)]
    cost[0][0] = 0.0
    for i in range(n + 1):
        for j in range(m + 1):
            here = cost[i][j]
            if here == INF:
                continue
            moves = []
            if i < n and j < m:
                moves.append((1, 1, _distance(words[i], tokens[j])))
            if i < n and j + 1 < m:
                moves.append((1, 2, _distance(words[i], tokens[j] + tokens[j + 1]) + 0.05))
            if i + 1 < n and j < m:
                moves.append((2, 1, _distance(words[i] + words[i + 1], tokens[j]) + 0.05))
            for di, dj, c in moves:
                if here + c < cost[i + di][j + dj]:
                    cost[i + di][j + dj] = here + c
                    back[i + di][j + dj] = (di, dj)
    owners: list[list[int]] = [[] for _ in words]
    i, j = n, m
    while i or j:
        di, dj = back[i][j]
        i, j = i - di, j - dj
        owners[i] = list(range(j, j + dj))    # a 2:1 step leaves words[i + 1] empty
    return owners


def similar(a: str, b: str) -> bool:
    """Loose agreement between two spellings of the same word."""
    a, b = skeleton(a), skeleton(b)
    if not a or not b:
        return a == b
    common = sum(1 for x, y in zip(sorted(a), sorted(b)) if x == y)
    return len(set(a) & set(b)) / max(len(set(a)), len(set(b))) >= 0.6 or common >= 0.6 * max(len(a), len(b))


# ── one ayah ────────────────────────────────────────────────────────────────

def split_nastaleeq(text: str) -> tuple[list[str], str]:
    """Words (waqf glyphs attached) and the ayah-end token (digits + its sign)."""
    parts = text.split(" ")
    end = parts.pop() if parts and parts[-1][:1].isdigit() else ""
    words: list[str] = []
    for part in parts:
        if words and is_mark_token(part):
            words[-1] += part          # a stray mark written as its own token
        else:
            words.append(part)
    return words, end


def line_up(tokens: list[str], prefix: int, script_words: list[str], basmala: list[str],
            keep_hizb: bool, report: list, key: str, label: str) -> list[str]:
    """Display strings parallel to `tokens` (quran_full.json's), in one script."""
    out = [""] * len(tokens)
    for i in range(prefix):
        out[i] = basmala[i]
    word_positions = [i for i in range(prefix, len(tokens)) if not is_mark_token(tokens[i])]
    for i in range(prefix, len(tokens)):
        if is_mark_token(tokens[i]) and keep_hizb and HIZB in tokens[i]:
            out[i] = HIZB
    ours = [tokens[i] for i in word_positions]

    if len(script_words) == len(ours):
        owners = [[j] for j in range(len(ours))]
    else:
        owners = assign_by_letters(ours, script_words)
        report.append((label, key, [tokens[i] for i in word_positions],
                       [" ".join(script_words[j] for j in o) for o in owners]))
    for k, i in enumerate(word_positions):
        out[i] = " ".join(script_words[j] for j in owners[k])
    return out


def main() -> int:
    data = json.loads(SOURCE.read_text(encoding="utf-8"))
    chapters = {c: fetch_chapter(c) for c in range(1, 115)}

    fatihah = chapters[1][0]
    basmala_u = [w["text_qpc_hafs"] for w in fatihah["words"] if w["char_type_name"] == "word"]
    basmala_n, _ = split_nastaleeq(fatihah["text_qpc_nastaleeq_hafs"])
    assert len(basmala_u) == len(basmala_n) == 4

    realigned: list = []
    disagreements: list = []
    ruku_end_glyphs: dict[str, set] = {"ruku end": set(), "not": set()}
    surahs_out = []

    for surah in data["surahs"]:
        sn = surah["number"]
        verses = chapters[sn]
        if len(verses) != len(surah["ayahs"]):
            raise SystemExit(f"surah {sn}: {len(verses)} verses from the API, {len(surah['ayahs'])} in the app")
        ayahs_out = []
        for index, (ayah, verse) in enumerate(zip(surah["ayahs"], verses)):
            key = f"{sn}:{ayah['number']}"
            if verse["verse_key"] != key:
                raise SystemExit(f"order mismatch at {key}")
            tokens = ayah["arabicText"].split(" ")
            prefix = basmala_prefix_len(sn, ayah["number"], tokens)

            u_words = [w["text_qpc_hafs"] for w in verse["words"] if w["char_type_name"] == "word"]
            u_end = next(w["text_qpc_hafs"] for w in verse["words"] if w["char_type_name"] == "end")
            n_words, n_end = split_nastaleeq(verse["text_qpc_nastaleeq_hafs"])

            u = line_up(tokens, prefix, u_words, basmala_u, True, realigned, key, "uthmani")
            n = line_up(tokens, prefix, n_words, basmala_n, False, realigned, key, "indopak")

            positions = [i for i in range(prefix, len(tokens)) if not is_mark_token(tokens[i])]
            for label, drawn in (("uthmani", u), ("indopak", n)):
                for k, i in enumerate(positions):
                    if not drawn[i]:
                        continue
                    # A script word drawn over this one and the next (which is
                    # then empty) is compared against both.
                    ours = tokens[i]
                    if k + 1 < len(positions) and not drawn[positions[k + 1]]:
                        ours += tokens[positions[k + 1]]
                    if not similar(ours, drawn[i]):
                        disagreements.append((label, key, i, ours, drawn[i]))

            nxt = verses[index + 1]["ruku_number"] if index + 1 < len(verses) else None
            ends_ruku = nxt != verse["ruku_number"]
            sign = n_end.lstrip("٠١٢٣٤٥٦٧٨٩")
            ruku_end_glyphs["ruku end" if ends_ruku else "not"].add(sign)

            ayahs_out.append({
                "u": SEP.join(u),
                "n": SEP.join(n),
                "ue": u_end,
                "ne": n_end,
                "r": verse["ruku_number"],
                **({"s": verse["sajdah_number"]} if verse.get("sajdah_number") else {}),
                "j": verse["juz_number"],
            })
        surahs_out.append(ayahs_out)

    TARGET.write_text(json.dumps({
        "source": "quran.com API v4 (text_qpc_hafs per word, text_qpc_nastaleeq_hafs per ayah, "
                  "ruku_number and sajdah_number); built by ml/tools/build_quran_scripts.py",
        "fonts": {"u": "KFGQPC HAFS Uthmanic Script", "n": "KFGQPC Nastaleeq"},
        "surahs": surahs_out,
    }, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")

    print(f"wrote {TARGET.relative_to(REPO)} ({TARGET.stat().st_size / 1e6:.2f} MB)")
    print(f"ayahs lined up by letters rather than one-to-one: {len(realigned)}")
    for label, key, ours, shown in realigned:
        print(f"  {label:8} {key:8} {' | '.join(ours)}")
        print(f"  {'':8} {'':8} {' | '.join(shown)}")
    print(f"words whose letters disagree after lining up: {len(disagreements)}")
    for row in disagreements[:40]:
        print("  ", row)
    shared = ruku_end_glyphs["ruku end"] & ruku_end_glyphs["not"]
    print(f"IndoPak ayah-end glyphs used only at ruku ends: {len(ruku_end_glyphs['ruku end'] - shared)}, "
          f"also used elsewhere: {sorted(hex(ord(g[0])) for g in shared if g)}")
    return 1 if disagreements else 0


if __name__ == "__main__":
    sys.exit(main())
