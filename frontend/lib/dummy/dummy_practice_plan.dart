import '../models/practice_plan_item.dart';

final List<PracticePlanItem> dummyPracticePlan = [
  const PracticePlanItem(
    rule: 'the_tight_noon',
    tajweedRule: 'Ghunnah (via An-Noon Al-Mushaddadah)',
    reason: 'Flagged incorrect in 3 of your last 5 sessions',
    errorCount: 3,
  ),
  const PracticePlanItem(
    rule: 'concealment',
    tajweedRule: 'Ikhfa',
    reason: 'Flagged incorrect in 2 of your last 5 sessions, needed extra attempts 1 time',
    errorCount: 2,
  ),
];
