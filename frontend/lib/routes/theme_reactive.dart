import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../app/cubit/theme_cubit.dart';

/// Wraps a screen so it rebuilds whenever [ThemeCubit] changes.
///
/// go_router persists each route's Page/Navigator across rebuilds by
/// design — StatefulShellBranch keeps all four tabs mounted for state
/// preservation, and any pushed route sitting behind the active one stays
/// mounted too. Since `AppColors` is a bare static field rather than a
/// proper InheritedWidget, only whichever screen actually triggers a
/// rebuild picks up a theme change; every other already-built screen (a
/// `const` widget instance) keeps showing its old colors until something
/// else happens to force it to rebuild — the "wrong theme on some screens"
/// glitch. `context.watch<ThemeCubit>()` here registers this element as a
/// direct dependent, so Flutter marks it dirty on every theme change
/// regardless of go_router's caching, and the non-const [builder] call
/// guarantees the wrapped screen actually gets rebuilt in turn.
class ThemeReactive extends StatelessWidget {
  final WidgetBuilder builder;
  const ThemeReactive({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeCubit>();
    return builder(context);
  }
}
