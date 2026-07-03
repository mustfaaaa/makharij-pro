import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../features/recitation/presentation/bloc/recitation_cubit.dart';
import '../routes/app_router.dart';
import '../theme/app_theme.dart';
import 'cubit/theme_cubit.dart';

class MakharijProApp extends StatelessWidget {
  const MakharijProApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => ThemeCubit()),
        // App-level singleton: the recitation flow spans four pushed routes
        // (Recitation -> Listening -> Processing -> Result), so its state
        // machine must survive navigation between them.
        BlocProvider(create: (_) => RecitationCubit()),
      ],
      child: BlocBuilder<ThemeCubit, ThemeMode>(
        builder: (context, themeMode) {
          return MaterialApp.router(
            title: 'MakharijPro AI',
            debugShowCheckedModeBanner: false,
            themeMode: themeMode,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            routerConfig: appRouter,
          );
        },
      ),
    );
  }
}
