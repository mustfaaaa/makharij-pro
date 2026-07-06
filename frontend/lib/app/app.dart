import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../features/recitation/presentation/bloc/recitation_cubit.dart';
import '../routes/app_router.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'cubit/auth_cubit.dart';
import 'cubit/hasanah_cubit.dart';
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
        BlocProvider(create: (_) => HasanahCubit()),
        BlocProvider(create: (_) => AuthCubit()),
        // App-level singleton: the recitation flow spans four pushed routes
        // (Recitation -> Listening -> Processing -> Result), so its state
        // machine must survive navigation between them.
        BlocProvider(create: (_) => RecitationCubit()),
      ],
      child: BlocBuilder<ThemeCubit, ThemeMode>(
        builder: (context, themeMode) {
          // Drive the brightness-aware palette from the toggle, then build a
          // single matching theme. Every widget re-reads AppColors on this
          // rebuild, so the whole app flips light <-> dark.
          AppColors.brightness = themeMode == ThemeMode.dark ? Brightness.dark : Brightness.light;
          return MaterialApp.router(
            title: 'MakharijPro AI',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.build(),
            routerConfig: appRouter,
          );
        },
      ),
    );
  }
}
