import '../models/tajweed_rule.dart';

final List<TajweedRule> dummyTajweedRules = [
  const TajweedRule(
    id: 'r1',
    title: 'Makhraj (Articulation Point)',
    arabicExample: 'قَ - كَ',
    shortDescription: 'The precise point in the mouth/throat where each letter originates.',
    fullExplanation: 'Makhraj refers to the exact location in the vocal tract where a letter\'s sound is produced. Correct makhraj distinguishes similar-sounding letters like ق (Qaf) and ك (Kaf). Mispronouncing the makhraj can change the meaning of a word entirely.',
    category: 'Articulation',
    isBookmarked: true,
  ),
  const TajweedRule(
    id: 'r2',
    title: 'Ghunnah (Nasalization)',
    arabicExample: 'نّ - مّ',
    shortDescription: 'A nasal sound held for two counts on ن and م when they carry a shaddah.',
    fullExplanation: 'Ghunnah is a compulsory nasal sound produced from the nasal cavity, applied whenever ن or م carries a shaddah, and in certain noon/meem sakinah rules such as Ikhfa and Idgham. It should be held for approximately two counts.',
    category: 'Nasalization',
  ),
  const TajweedRule(
    id: 'r3',
    title: 'Shaddah (Doubling)',
    arabicExample: 'رَبَّنَا',
    shortDescription: 'A diacritic indicating a letter is doubled and pronounced with emphasis.',
    fullExplanation: 'Shaddah (ّ) doubles the letter it sits on, requiring the reciter to pause briefly on the letter before releasing it with emphasis. Skipping the shaddah changes both the sound and often the grammatical meaning of the word.',
    category: 'Emphasis',
    isBookmarked: true,
  ),
  const TajweedRule(
    id: 'r4',
    title: 'Madd (Elongation)',
    arabicExample: 'قَالَ - يَقُولُ',
    shortDescription: 'Rules governing how long a vowel sound should be elongated.',
    fullExplanation: 'Madd refers to the prolongation of a vowel sound, typically triggered by the letters ا، و، ي. The natural madd (Madd Tabee\'i) is held for two counts, while other categories such as Madd Muttasil or Madd Munfasil require longer elongation depending on context.',
    category: 'Elongation',
  ),
  const TajweedRule(
    id: 'r5',
    title: 'Qalqalah (Echoing Bounce)',
    arabicExample: 'قْ - طْ - بْ - جْ - دْ',
    shortDescription: 'A slight echoing bounce produced on five letters when they carry sukoon.',
    fullExplanation: 'Qalqalah applies to the letters ق ط ب ج د when they occur with sukoon. The letter is pronounced with a slight bounce or vibration rather than a flat stop, especially noticeable at the end of a word or ayah.',
    category: 'Articulation',
  ),
  const TajweedRule(
    id: 'r6',
    title: 'Ikhfa (Concealment)',
    arabicExample: 'مِنْ شَيْءٍ',
    shortDescription: 'Concealing the noon sakinah/tanween sound before certain letters.',
    fullExplanation: 'Ikhfa occurs when noon sakinah or tanween is followed by one of 15 specific letters. The noon sound is concealed — neither fully pronounced nor fully dropped — and blended with a light ghunnah into the following letter.',
    category: 'Noon Rules',
  ),
];
