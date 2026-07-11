import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/current_user_display.dart';
import '../../../../routes/route_names.dart';
import '../../../../shared/widgets/animated/pressable.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../../shared/widgets/navigation/app_drawer.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_radii.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_typography.dart';

// ── Quick-access important surahs (8, as in the mockup) ──────────────────────
const _quickSurahs = [
  (num: 73, name: 'Al-Muzzammil'),
  (num: 67, name: 'Al-Mulk'),
  (num: 36, name: 'Ya-Sin'),
  (num: 55, name: 'Ar-Rahman'),
  (num: 56, name: "Al-Waqi'ah"),
  (num: 32, name: 'As-Sajdah'),
  (num: 18, name: 'Al-Kahf'),
  (num: 112, name: 'Al-Ikhlas'),
];

// ── Prayer times (static prototype data, Islamabad) ──────────────────────────
class _Prayer {
  final String name;
  final String time;
  final IconData icon;
  const _Prayer(this.name, this.time, this.icon);
}

const _prayers = [
  _Prayer('Fajr', '3:24', Icons.nightlight_outlined),
  _Prayer('Dhuhr', '12:09', Icons.wb_sunny_outlined),
  _Prayer('Asr', '5:04', Icons.wb_twilight_outlined),
  _Prayer('Maghrib', '7:21', Icons.brightness_4_outlined),
  _Prayer('Isha', '8:56', Icons.dark_mode_outlined),
];
const _nextPrayerIndex = 3; // Maghrib

/// Home dashboard rebuilt to the provided mockup: dark Quran photo header
/// with greeting, Ayah of the Day, Last Read, Prayer times with countdown,
/// Today's goal, Quick Access surahs, and Invite friends. The original
/// drawer menu is preserved as requested.
class HomeDashboardScreen extends StatefulWidget {
  const HomeDashboardScreen({super.key});

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  Timer? _ticker;
  Duration _untilNext = Duration.zero;

  @override
  void initState() {
    super.initState();
    _computeCountdown();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _computeCountdown());
  }

  void _computeCountdown() {
    final now = DateTime.now();
    var maghrib = DateTime(now.year, now.month, now.day, 19, 21);
    if (maghrib.isBefore(now)) maghrib = maghrib.add(const Duration(days: 1));
    if (mounted) setState(() => _untilNext = maghrib.difference(now));
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String get _countdownText {
    final h = _untilNext.inHours;
    final m = (_untilNext.inMinutes % 60).toString().padLeft(2, '0');
    final s = (_untilNext.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final firstName = currentUserName();
    final bottomPad = AppSpacing.bottomNavClearance + MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: const AppDrawer(),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: bottomPad),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Photo header with Ayah of the Day written on it ──────────
            _HeaderImage(firstName: firstName),
            const SizedBox(height: AppSpacing.md),
            // ── Last Read ────────────────────────────────────────────────
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
              child: _LastReadCard(),
            ),
            const SizedBox(height: AppSpacing.lg),
            // ── Prayer times ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Prayer times',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                  GestureDetector(
                    onTap: () {},
                    child: Text('Monthly view',
                        style: TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.w600, fontSize: 14)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
              child: _NextPrayerCard(countdown: _countdownText),
            ),
            const SizedBox(height: AppSpacing.md),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
              child: _PrayerChipsRow(),
            ),
            const SizedBox(height: AppSpacing.lg),
            // ── Today's goal ─────────────────────────────────────────────
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
              child: _TodaysGoalCard(),
            ),
            const SizedBox(height: AppSpacing.lg),
            // ── Quick Access ─────────────────────────────────────────────
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
              child: _QuickAccessCard(),
            ),
            const SizedBox(height: AppSpacing.lg),
            // ── Invite friends ───────────────────────────────────────────
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
              child: _InviteFriendsCard(),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Header: mockup-style — greeting row on top, glowing mushaf in the
// middle, Ayah of the Day written directly on the photo, melting into the
// page background below. ─────────────────────────────────────────────────────
class _HeaderImage extends StatelessWidget {
  final String firstName;
  const _HeaderImage({required this.firstName});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 440,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/quran_dark.jpg',
              fit: BoxFit.cover, alignment: const Alignment(0, 0.3)),
          // Readability scrim: gentle at the top, deep beneath the ayah text.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.22, 0.48, 0.95],
                colors: [
                  Colors.black.withValues(alpha: 0.40),
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.62),
                ],
              ),
            ),
          ),
          // Final melt into the page background.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.86, 1.0],
                colors: [Colors.transparent, AppColors.background],
              ),
            ),
          ),
          // ── Ayah of the Day, written on the photo like the mockup ──────
          Positioned(
            left: AppSpacing.screenPadding,
            right: AppSpacing.screenPadding,
            bottom: 48,
            child: Column(
              children: [
                Text('AYAH OF THE DAY',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: AppColors.primaryLight,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        letterSpacing: 3.2)),
                const SizedBox(height: 10),
                Text('\u064a\u064e\u0627 \u0623\u064e\u064a\u064f\u0651\u0647\u064e\u0627 \u0627\u0644\u064e\u0651\u0630\u0650\u064a\u0646\u064e \u0622\u0645\u064e\u0646\u064f\u0648\u0627 \u0627\u0630\u0652\u0643\u064f\u0631\u064f\u0648\u0627 \u0627\u0644\u0644\u064e\u0651\u0647\u064e \u0630\u0650\u0643\u0652\u0631\u064b\u0627 \u0643\u064e\u062b\u0650\u064a\u0631\u064b\u0627',
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.rtl,
                    style: AppTypography.arabicVerse(
                        fontSize: 22, color: Colors.white, height: 1.7)),
                const SizedBox(height: 6),
                Text(
                  '"O you who have believed, remember Allah with much remembrance." \u2014 Al-Ahzab 33:41',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.78),
                      fontSize: 12.5,
                      height: 1.4),
                ),
              ],
            ),
          ),
          // ── Greeting row pinned to the very top, mockup style ───────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenPadding, 6, AppSpacing.screenPadding, 0),
                child: Row(
                  children: [
                    // Navigation menu (original drawer) before the greeting.
                    Builder(
                      builder: (context) => _GlassCircleButton(
                        icon: Icons.menu_rounded,
                        onTap: () => Scaffold.of(context).openDrawer(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Gold avatar exactly like the mockup.
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [AppColors.primaryLight, AppColors.primary],
                        ),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        firstName.isNotEmpty ? firstName[0].toUpperCase() : 'M',
                        style: const TextStyle(
                            color: Color(0xFF3A2C1B),
                            fontWeight: FontWeight.w800,
                            fontSize: 18),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Assalamu Alaikum',
                              style: TextStyle(
                                  color: AppColors.primaryLight,
                                  fontSize: 13,
                                  letterSpacing: 1.1,
                                  fontWeight: FontWeight.w600)),
                          Text(firstName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                    _GlassCircleButton(
                      icon: Icons.notifications_none_rounded,
                      onTap: () => context.push(RoutePaths.notifications),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dark translucent circle button used for the menu and the bell, matching
/// the mockup's header controls.
class _GlassCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _GlassCircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

// ── Last Read card ────────────────────────────────────────────────────────────
class _LastReadCard extends StatelessWidget {
  const _LastReadCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.lgRadius,
        boxShadow: [BoxShadow(color: AppColors.cardShadow, blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: AppColors.primarySurface, borderRadius: AppRadii.mdRadius),
            child: Icon(Icons.menu_book_rounded, color: AppColors.primaryDark, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('LAST READ',
                    style: TextStyle(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        letterSpacing: 1.8)),
                const SizedBox(height: 2),
                Text('Al-Fatihah',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                Text('Ayah 5 of 7 · Juz 1',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
          Pressable(
            onTap: () => context.push(RoutePaths.surahDetailsPath(1)),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              decoration: BoxDecoration(color: AppColors.primary, borderRadius: AppRadii.pillRadius),
              child: const Text('Continue',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Next-prayer card with live countdown ─────────────────────────────────────
class _NextPrayerCard extends StatelessWidget {
  final String countdown;
  const _NextPrayerCard({required this.countdown});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.lgRadius,
        boxShadow: [BoxShadow(color: AppColors.cardShadow, blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('NEXT · MAGHRIB',
                    style: TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        letterSpacing: 1.8)),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('7:21',
                        style: textTheme.displayLarge?.copyWith(
                            color: AppColors.primaryDark, fontWeight: FontWeight.w700, fontSize: 36, height: 1.0)),
                    const SizedBox(width: 6),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('PM',
                          style: textTheme.titleSmall?.copyWith(color: AppColors.primaryDark)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 14, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Text('Islamabad, Pakistan',
                        style: textTheme.bodySmall?.copyWith(color: AppColors.textMuted)),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('begins in', style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 2),
              Text(countdown,
                  style: textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 0.5)),
              const SizedBox(height: 6),
              Icon(Icons.nightlight_round, color: AppColors.primary, size: 22),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Five prayer chips with Maghrib highlighted ───────────────────────────────
class _PrayerChipsRow extends StatelessWidget {
  const _PrayerChipsRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (int i = 0; i < _prayers.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: _PrayerChip(prayer: _prayers[i], highlighted: i == _nextPrayerIndex)),
        ],
      ],
    );
  }
}

class _PrayerChip extends StatelessWidget {
  final _Prayer prayer;
  final bool highlighted;
  const _PrayerChip({required this.prayer, required this.highlighted});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: highlighted ? AppColors.primarySurface : AppColors.surface,
        borderRadius: AppRadii.mdRadius,
        border: Border.all(color: highlighted ? AppColors.primary : AppColors.border, width: highlighted ? 1.5 : 1),
        boxShadow: [BoxShadow(color: AppColors.cardShadow, blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          Icon(prayer.icon, size: 18, color: highlighted ? AppColors.primaryDark : AppColors.textSecondary),
          const SizedBox(height: 6),
          Text(prayer.name,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: highlighted ? FontWeight.w800 : FontWeight.w600,
                  color: highlighted ? AppColors.primaryDark : AppColors.textPrimary)),
          const SizedBox(height: 2),
          Text(prayer.time,
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: highlighted ? AppColors.primaryDark : AppColors.textSecondary)),
        ],
      ),
    );
  }
}

// ── Today's goal (green card) ─────────────────────────────────────────────────
class _TodaysGoalCard extends StatelessWidget {
  const _TodaysGoalCard();

  @override
  Widget build(BuildContext context) {
    const done = 7, total = 10;
    const pct = done / total;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: const Color(0xFF1F6E4E),
        borderRadius: AppRadii.lgRadius,
        boxShadow: [BoxShadow(color: AppColors.cardShadow, blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Today's goal",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.28),
                  borderRadius: AppRadii.pillRadius,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.local_fire_department_rounded, color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text('5-day streak',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('Listen to 10 ayahs of recitation',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 14)),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.22),
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.accentLight),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$done / $total ayahs completed',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12.5)),
              const Text('70%',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Quick Access card ─────────────────────────────────────────────────────────
class _QuickAccessCard extends StatelessWidget {
  const _QuickAccessCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.lgRadius,
        boxShadow: [BoxShadow(color: AppColors.cardShadow, blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bolt_rounded, color: AppColors.accent, size: 20),
              const SizedBox(width: 6),
              Expanded(
                child: Text('Quick Access',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              ),
              Text('${_quickSurahs.length} Surahs',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final s in _quickSurahs)
                Pressable(
                  onTap: () => context.push(RoutePaths.surahDetailsPath(s.num)),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: AppRadii.pillRadius,
                    ),
                    child: Text(s.name,
                        style: TextStyle(
                            color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13.5)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Invite friends card ───────────────────────────────────────────────────────
class _InviteFriendsCard extends StatelessWidget {
  const _InviteFriendsCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.lgRadius,
        boxShadow: [BoxShadow(color: AppColors.cardShadow, blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: AppColors.primarySurface, borderRadius: AppRadii.mdRadius),
                child: Icon(Icons.card_giftcard_rounded, color: AppColors.primaryDark, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Invite friends',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    Text('Share Makharij Pro and help others',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Pressable(
            onTap: () {
              HapticFeedback.selectionClick();
              AppSnackbar.show(context, 'Sharing will be available in the release build.');
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(color: AppColors.primarySurface, borderRadius: AppRadii.pillRadius),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_upward_rounded, size: 16, color: AppColors.primaryDark),
                  const SizedBox(width: 6),
                  Text('Share Now',
                      style: TextStyle(
                          color: AppColors.primaryDark, fontWeight: FontWeight.w700, fontSize: 13.5)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
