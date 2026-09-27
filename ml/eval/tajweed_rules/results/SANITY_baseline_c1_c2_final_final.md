# Sanity check: baseline → c1_c2_final → final

## Correct natural madd (expert)
- **1:1 ٱللَّهِ** (expert, clip abdurrahmaan_as_su) — expected `للَااهِ` (ا×2, natural)
  - baseline: heard `للَااهِ` · emitted ا×2 · timing 0.71 tempo units · verdict **correct**
  - c1_c2_final: heard `للَااهِ` · emitted ا×2 · timing 0.71 tempo units · verdict **correct**
  - final: heard `للَااهِ` · emitted ا×2 · timing 0.71 tempo units · verdict **correct**
- **1:1 ٱلرَّحْمَٰنِ** (expert, clip abdurrahmaan_as_su) — expected `ررَحمَاانِ` (ا×2, natural)
  - baseline: heard `ررَحمَاانِ` · emitted ا×2 · timing 1.00 tempo units · verdict **correct**
  - c1_c2_final: heard `ررَحمَاانِ` · emitted ا×2 · timing 1.00 tempo units · verdict **correct**
  - final: heard `ررَحمَاانِ` · emitted ا×2 · timing 1.00 tempo units · verdict **correct**

## Munfasil held short (expert, valid qasr)
- **2:76 قَالُوٓا۟** (expert, clip abdurrahmaan_as_su) — expected `قَاالُۥۥۥۥ` (ۥ×4, munfasil)
  - baseline: heard `قَاالُۥۥۥۥ` · emitted ۥ×4 · timing 2.00 tempo units · verdict **correct**
  - c1_c2_final: heard `قَاالُۥۥۥۥ` · emitted ۥ×4 · timing 2.00 tempo units · verdict **correct**
  - final: heard `قَاالُۥۥۥۥ` · emitted ۥ×4 · timing 2.00 tempo units · verdict **correct**
- **2:76 قَالُوٓا۟** (expert, clip abdurrahmaan_as_su) — expected `قَاالُۥۥۥۥ` (ۥ×4, munfasil)
  - baseline: heard `قَاالُۥۥۥۥ` · emitted ۥ×4 · timing 1.80 tempo units · verdict **correct**
  - c1_c2_final: heard `قَاالُۥۥۥۥ` · emitted ۥ×4 · timing 1.80 tempo units · verdict **correct**
  - final: heard `قَاالُۥۥۥۥ` · emitted ۥ×4 · timing 1.80 tempo units · verdict **correct**

## Lazim (expert)
- **1:7 ٱلضَّآلِّينَ** (expert, clip abdurrahmaan_as_su) — expected `لَضضَااااااللِۦۦۦۦن` (ا×6, lazim)
  - baseline: heard `لَضضَااااااللِۦۦۦۦن` · emitted ا×6 · timing 11.09 tempo units · verdict **correct**
  - c1_c2_final: heard `لَضضَااااااللِۦۦۦۦن` · emitted ا×6 · timing 11.09 tempo units · verdict **correct**
  - final: heard `لَضضَااااااللِۦۦۦۦن` · emitted ا×6 · timing 11.09 tempo units · verdict **correct**
- **2:1 الٓمٓ** (expert, clip abdurrahmaan_as_su) — expected `ءَلِفلَااااااممممِۦۦۦۦۦۦم` (ا×6, lazim)
  - baseline: heard `ءَلِفلَااااااممممِۦۦۦۦۦۦم` · emitted ا×6 · timing n/a · verdict **correct**
  - c1_c2_final: heard `ءَلِفلَااااااممممِۦۦۦۦۦۦم` · emitted ا×6 · timing n/a · verdict **correct**
  - final: heard `ءَلِفلَااااااممممِۦۦۦۦۦۦم` · emitted ا×6 · timing n/a · verdict **correct**

## Lazim, learner, measured short
- **1:7 ٱلضَّآلِّينَ** (in_correct, clip 1bfcbcae-b49a-4cb1) — expected `لَضضَااااااللِۦۦۦۦن` (ا×6, lazim)
  - baseline: heard `لَتَاااااالِۦۦن` · emitted ا×6 · timing 5.50 tempo units · verdict **shaddah**
  - c1_c2_final: heard `لَتَاااااالِۦۦن` · emitted ا×6 · timing 5.50 tempo units · verdict **shaddah** — “The “ل” in “ٱلضَّآلِّينَ” should sound doubled (shaddah) — that didn’t come through clearly. Listen back. In “ٱلضَّآلِّينَ”, “ض” sounded closer to “ت” — listen back and check its articulation point (makhraj).”
  - final: heard `لَتَاااااالِۦۦن` · emitted ا×6 · timing 5.50 tempo units · verdict **shaddah** — “The “ل” in “ٱلضَّآلِّينَ” should sound doubled (shaddah) — that didn’t come through clearly. Listen back. In “ٱلضَّآلِّينَ”, “ض” sounded closer to “ت” — listen back and check its articulation point (makhraj).”
- **1:7 ٱلضَّآلِّينَ** (in_correct, clip 3cda165a-3c25-46b8) — expected `لَضضَااااااللِۦۦۦۦن` (ا×6, lazim)
  - baseline: heard `لَااتَاالِۦۦن` · emitted ا×2 · timing 2.00 tempo units · verdict **madd**
  - c1_c2_final: heard `لَااتَاالِۦۦم` · emitted ا×2 · timing 2.00 tempo units · verdict **makhraj** — “Most of “ٱلضَّآلِّينَ” didn’t match what was expected — listen back, then try it again slowly.”
  - final: heard `لَااتَاالِۦۦن` · emitted ا×2 · timing 2.00 tempo units · verdict **madd** — ““ٱلضَّآلِّينَ” expects about 6 counts of elongation (madd). About 2 came through — listen back and compare. The “ل” in “ٱلضَّآلِّينَ” should sound doubled (shaddah) — that didn’t come through clearly. Listen back.”

## Aarid at the ayah's end (learner, agreed correct)
- **1:4 ٱلدِّينِ** (correct, clip 01407b55-130b-4d30) — expected `ددِۦۦۦۦن` (ۦ×4, aarid)
  - baseline: heard `ددِۦۦن` · emitted ۦ×2 · timing 1.56 tempo units · verdict **correct**
  - c1_c2_final: heard `ددِۦۦن` · emitted ۦ×2 · timing 1.33 tempo units · verdict **correct**
  - final: heard `ددِۦۦن` · emitted ۦ×2 · timing 1.33 tempo units · verdict **correct**
- **1:4 ٱلدِّينِ** (correct, clip 0301491f-7cdb-4c8c) — expected `ددِۦۦۦۦن` (ۦ×4, aarid)
  - baseline: heard `ددِۦۦن` · emitted ۦ×2 · timing 1.56 tempo units · verdict **correct**
  - c1_c2_final: heard `ددِۦۦن` · emitted ۦ×2 · timing 1.33 tempo units · verdict **correct**
  - final: heard `ددِۦۦن` · emitted ۦ×2 · timing 1.33 tempo units · verdict **correct**

## Final-word madd lost at the end (learner, agreed correct)
- **1:2 ٱلْعَٰلَمِينَ** (correct, clip 40ee8b37-69c8-4035) — expected `لعَاالَمِۦۦۦۦن` (ۦ×4, aarid)
  - baseline: heard `لعَاالَمِ` · emitted None×0 · timing n/a · verdict **madd**
  - c1_c2_final: heard `لعَاالَمِۦۦۦۦن` · emitted ۦ×4 · timing 6.29 tempo units · verdict **correct**
  - final: heard `لعَاالَمِ` · emitted None×0 · timing n/a · verdict **madd** — ““ٱلْعَٰلَمِينَ” expects about 4 counts of elongation (madd). None came through — listen back and compare. The “ن” in “ٱلْعَٰلَمِينَ” didn’t come through — listen back and check.”
- **1:6 ٱلْمُسْتَقِيمَ** (correct, clip 79ab4b58-115b-4ce1) — expected `لمُستَقِۦۦۦۦم` (ۦ×4, aarid)
  - baseline: heard `لمُستَقِۦۦ` · emitted None×0 · timing n/a · verdict **madd**
  - c1_c2_final: heard `لمُستَقِۦۦم` · emitted ۦ×2 · timing 4.25 tempo units · verdict **correct**
  - final: heard `لمُستَقِۦۦم` · emitted ۦ×2 · timing 4.25 tempo units · verdict **correct**

## Correct ghunnah (learner, agreed correct)
- **108:1 إِنَّآ** (correct, clip 00483495-1a25-4fa2) — expected `ءِننننَاااا` (ن×4)
  - baseline: heard `ءِننننَاااا` · emitted ن×4 · timing 6.00 tempo units · verdict **correct**
  - c1_c2_final: heard `ءِننننَاااا` · emitted ن×4 · timing 6.00 tempo units · verdict **correct**
  - final: heard `ءِننننَاااا` · emitted ن×4 · timing 6.00 tempo units · verdict **correct**
- **110:3 إِنَّهُۥ** (correct, clip 0b30a2fe-97f3-42ef) — expected `ءِننننَهُۥۥ` (ن×4)
  - baseline: heard `ءِننننَهُۥۥ` · emitted ن×4 · timing 4.27 tempo units · verdict **correct**
  - c1_c2_final: heard `ءِننننَهُۥۥ` · emitted ن×4 · timing 4.27 tempo units · verdict **correct**
  - final: heard `ءِننننَهُۥۥ` · emitted ن×4 · timing 4.27 tempo units · verdict **correct**

## Short ghunnah (learner)
- **109:4 مَّا** (in_correct, clip 028c9231-3ab0-41ab) — expected `ممممَاا` (م×4)
  - baseline: heard `ۥۥمَاا` · emitted م×1 · timing 2.00 tempo units · verdict **ghunnah**
  - c1_c2_final: heard `ۥۥمَاا` · emitted م×1 · timing 2.00 tempo units · verdict **ghunnah** — “The nasal hum (ghunnah) on “م” in “مَّا” sounded shorter than the two counts expected — listen back.”
  - final: heard `ۥۥمَاا` · emitted م×1 · timing 2.00 tempo units · verdict **ghunnah** — “The nasal hum (ghunnah) on “م” in “مَّا” sounded shorter than the two counts expected — listen back.”
- **111:4 حَمَّالَةَ** (in_correct, clip 324c68ae-3ab5-4991) — expected `حَممممَاالَتَ` (م×4)
  - baseline: heard `حَمَلتَ` · emitted م×1 · timing 2.00 tempo units · verdict **madd**
  - c1_c2_final: heard `` · emitted –×– · timing n/a · verdict **not recited**
  - final: heard `حَمَلتَ` · emitted م×1 · timing 2.00 tempo units · verdict **madd** — ““حَمَّالَةَ” expects about 2 counts of elongation (madd). None came through — listen back and compare. The nasal hum (ghunnah) on “م” in “حَمَّالَةَ” sounded shorter than the two counts expected — listen back.”

## Ikhfa said as a plain noon (learner)
- **114:4 مِن** (in_correct, clip 20f7af2f-31ed-4c8c) — expected `مِںںں` (ں×3)
  - baseline: heard `ن` · emitted ن×1 · timing n/a · verdict **makhraj**
  - c1_c2_final: heard `ن` · emitted ن×1 · timing n/a · verdict **ghunnah** — ““مِن” expects an ikhfa — the noon/meem hidden into the next letter with a nasal hum. It came through as a clear “ن” instead — listen back. The “م” in “مِن” didn’t come through — listen back and check.”
  - final: heard `ن` · emitted ن×1 · timing n/a · verdict **ghunnah** — ““مِن” expects an ikhfa — the noon/meem hidden into the next letter with a nasal hum. It came through as a clear “ن” instead — listen back. The “م” in “مِن” didn’t come through — listen back and check.”
- **113:2 مِن** (in_correct, clip 2dd6cb87-4572-4928) — expected `مِںںں` (ں×3)
  - baseline: heard `مِن` · emitted ن×1 · timing n/a · verdict **makhraj**
  - c1_c2_final: heard `مِن` · emitted ن×1 · timing 1.33 tempo units · verdict **ghunnah** — ““مِن” expects an ikhfa — the noon/meem hidden into the next letter with a nasal hum. It came through as a clear “ن” instead — listen back.”
  - final: heard `مِن` · emitted ن×1 · timing n/a · verdict **ghunnah** — ““مِن” expects an ikhfa — the noon/meem hidden into the next letter with a nasal hum. It came through as a clear “ن” instead — listen back.”

## Correct ikhfa (learner)
- **111:3 نَارًۭا** (correct, clip 07d06b72-10d2-486e) — expected `نَاارَںںں` (ں×3)
  - baseline: heard `نَاارَںںں` · emitted ں×3 · timing 2.29 tempo units · verdict **correct**
  - c1_c2_final: heard `نَاارَںںں` · emitted ں×3 · timing 2.29 tempo units · verdict **correct**
  - final: heard `نَاارَںںں` · emitted ں×3 · timing 2.29 tempo units · verdict **correct**
- **113:3 وَمِن** (in_correct, clip 0880c4d3-8a8c-4e61) — expected `وَمِںںں` (ں×3)
  - baseline: heard `وَمِںںں` · emitted ں×3 · timing 2.50 tempo units · verdict **correct**
  - c1_c2_final: heard `وَمِںںں` · emitted ں×3 · timing 2.50 tempo units · verdict **correct**
  - final: heard `وَمِںںں` · emitted ں×3 · timing 2.50 tempo units · verdict **correct**

## Madd cut short (controlled edit of expert audio)
- **31:10 دَآبَّةٍۢ** (abdurrahmaan_as_sudais/031010) — madd ×6, timing 13.60 before the edit
  - baseline: emitted ا×6 · timing after 5.00 · verdict **correct**
  - c1_c2_final: emitted ا×6 · timing after 5.00 · verdict **correct**
  - final: emitted ا×6 · timing after 5.00 · verdict **correct**
- **55:39 جَآنٌّۭ** (abdurrahmaan_as_sudais/055039) — madd ×6, timing 11.45 before the edit
  - baseline: emitted ا×6 · timing after 6.55 · verdict **correct**
  - c1_c2_final: emitted ا×6 · timing after 6.55 · verdict **correct**
  - final: emitted ا×6 · timing after 6.55 · verdict **correct**

## Natural madd over-stretched (controlled edit)
- **79:5 فَٱلْمُدَبِّرَٰتِ** (abdurrahmaan_as_sudais/079005) — madd ×2, timing 1.60 before the edit
  - baseline: emitted ا×2 · timing after 13.33 · verdict **makhraj**
  - c1_c2_final: emitted ا×2 · timing after 13.33 · verdict **makhraj**
  - final: emitted ا×2 · timing after 13.33 · verdict **makhraj**
- **109:6 دِينُكُمْ** (yasser_ad_dussary/109006) — madd ×2, timing 2.00 before the edit
  - baseline: emitted ۦ×2 · timing after 1.80 · verdict **correct**
  - c1_c2_final: emitted ۦ×2 · timing after 1.80 · verdict **correct**
  - final: emitted ۦ×2 · timing after 1.80 · verdict **correct**

## Ghunnah cut short (controlled edit)
- **101:9 فَأُمُّهُۥ** (alafasy/101009) — ghunnah ×4, timing 5.50 before the edit
  - baseline: emitted م×4 · timing after 2.55 · verdict **correct**
  - c1_c2_final: emitted م×4 · timing after 2.55 · verdict **correct**
  - final: emitted م×4 · timing after 2.55 · verdict **correct**
- **11:56 مُّسْتَقِيمٍۢ** (abdurrahmaan_as_sudais/011056) — ghunnah ×4, timing 4.00 before the edit
  - baseline: emitted م×1 · timing after 1.67 · verdict **ghunnah**
  - c1_c2_final: emitted م×1 · timing after 1.67 · verdict **ghunnah**
  - final: emitted م×1 · timing after 1.67 · verdict **ghunnah**

