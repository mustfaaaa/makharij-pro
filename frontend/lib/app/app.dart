import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../features/recitation/presentation/bloc/recitation_cubit.dart';
import '../routes/app_router.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'cubit/auth_cubit.dart';
import 'cubit/hasanah_cubit.dart';
import 'cubit/quran_script_cubit.dart';
import 'cubit/theme_cubit.dart';
import 'cubit/verse_text_size_cubit.dart';

class MakharijProApp extends StatelessWidget {
  const MakharijProApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => ThemeCubit()),
        BlocProvider(create: (_) => VerseTextSizeCubit()),
        BlocProvider(create: (_) => QuranScriptCubit()),
        BlocProvider(create: (_) => HasanahCubit()),
        BlocProvider(create: (_) => AuthCubit()),
        // App-level singleton: the recitation flow spans four pushed routes
        // (Recitation -> Listening -> Processing -> Result), so its state
        // machine must survive navigation between them.
        BlocProvider(create: (_) => RecitationCubit()),
      ],
      child: BlocBuilder<ThemeCubit, ThemeMode>(
        builder: (context, themeMode) => _ThemedApp(themeMode: themeMode),
      ),
    );
  }
}

/// Resolves the chosen [ThemeMode] against the device's own brightness and
/// builds the app in the result.
///
/// This is a [StatefulWidget] with a [WidgetsBindingObserver] rather than a
/// plain builder because of [ThemeMode.system]: when the user flips their
/// phone into dark mode while the app is open, nothing in the widget tree
/// would otherwise change, so the app would keep rendering light until the
/// next unrelated rebuild. [didChangePlatformBrightness] is the signal that
/// this actually happened.
class _ThemedApp extends StatefulWidget {
  final ThemeMode themeMode;
  const _ThemedApp({required this.themeMode});

  @override
  State<_ThemedApp> createState() => _ThemedAppState();
}

class _ThemedAppState extends State<_ThemedApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    // Only matters in system mode, but rebuilding unconditionally is cheap
    // and keeps the condition in one place (the resolve below).
    if (mounted) setState(() {});
  }

  Brightness get _effectiveBrightness {
    switch (widget.themeMode) {
      case ThemeMode.light:
        return Brightness.light;
      case ThemeMode.dark:
        return Brightness.dark;
      case ThemeMode.system:
        return WidgetsBinding.instance.platformDispatcher.platformBrightness;
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = _effectiveBrightness;

    // Drive the brightness-aware palette, then build a single matching theme.
    // Every widget re-reads AppColors on this rebuild, so the whole app flips
    // light <-> dark.
    AppColors.brightness = brightness;

    // The status bar sits on top of the app's own background, so its icons
    // have to be the opposite of the page: dark glyphs on the cream theme,
    // light glyphs on the parchment one. Nothing set this app-wide before,
    // which left the clock and battery invisible in one of the two themes.
    final isDark = brightness == Brightness.dark;
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: AppColors.background,
      systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    ));

    final theme = AppTheme.build();

    return MaterialApp.router(
      title: 'MakharijPro AI',
      debugShowCheckedModeBanner: false,
      // Both slots get the already-resolved theme: AppColors is a global that
      // has just been set to `brightness`, so building a second ThemeData for
      // the other mode here would produce the *same* colours and mislead.
      // The resolution happens above, in _effectiveBrightness.
      theme: theme,
      routerConfig: appRouter,
      builder: (context, child) {
        // Clamp runaway system font scaling. The layouts carry a lot of fixed
        // heights, and past ~1.3x those start clipping their own text; below
        // 1.0 nothing breaks, so only the top end is capped. Users who need
        // more than this are better served by the in-app verse text size,
        // which scales the Arabic without touching the chrome.
        final scaler = MediaQuery.textScalerOf(context).clamp(
          minScaleFactor: 0.85,
          maxScaleFactor: 1.3,
        );
        final content = child ?? const SizedBox.shrink();

        // Cap the content width once, here, instead of per screen.
        //
        // ResponsiveCenter had reached only 7 of 28 screens, so on a tablet
        // most of the app stretched a phone layout edge to edge: 900px lines
        // of body text, and a bottom nav pinned to the far corners. Doing it
        // in MaterialApp.builder covers every route, plus dialogs and bottom
        // sheets, which per-screen wrapping never did.
        //
        // On a phone this is a literal no-op -- the branch returns the child
        // untouched below the breakpoint.
        return LayoutBuilder(
          builder: (context, constraints) {
            final mq = MediaQuery.of(context).copyWith(textScaler: scaler);
            const maxWidth = 640.0;
            if (constraints.maxWidth <= maxWidth) {
              return MediaQuery(data: mq, child: content);
            }
            return ColoredBox(
              color: AppColors.background,
              child: Center(
                child: SizedBox(
                  width: maxWidth,
                  height: constraints.maxHeight,
                  // Report the *capped* size downstream, so helpers like
                  // `isTablet` and `gridColumns` describe the box the layout
                  // actually has rather than the whole display.
                  child: MediaQuery(
                    data: mq.copyWith(
                      size: Size(maxWidth, constraints.maxHeight),
                    ),
                    child: content,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
