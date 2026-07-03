import '../models/practice_plan_item.dart';

final List<PracticePlanItem> dummyPracticePlan = [
  const PracticePlanItem(id: 'p1', surahName: 'Al-Kahf', reason: 'Recurring Ghunnah errors detected in your last 3 sessions', focusArea: 'Ghunnah'),
  const PracticePlanItem(id: 'p2', surahName: 'Ar-Rahman', reason: 'Shaddah accuracy dropped below 75% this week', focusArea: 'Shaddah'),
  const PracticePlanItem(id: 'p3', surahName: 'Al-Fatihah', reason: 'Great consistency — keep reinforcing your Makhraj strength', focusArea: 'Makhraj', isCompleted: true),
  const PracticePlanItem(id: 'p4', surahName: 'Al-Mulk', reason: 'Madd elongation was slightly short in verse 3', focusArea: 'Madd'),
];
