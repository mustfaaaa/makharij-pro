import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Holds the app-wide [ThemeMode]. Full theming lands in Milestone 1;
/// this cubit only owns the light/dark toggle for now.
class ThemeCubit extends Cubit<ThemeMode> {
  ThemeCubit() : super(ThemeMode.light);

  void toggle() => emit(state == ThemeMode.light ? ThemeMode.dark : ThemeMode.light);
}
