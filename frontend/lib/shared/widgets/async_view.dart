import 'package:flutter/material.dart';

import 'loading/app_loading_indicator.dart';
import 'states/error_state_widget.dart';

/// Unifies the loading / error / data states for one-off [Future]s so every
/// FutureBuilder screen behaves consistently — no more infinite spinners on
/// a failed or hung future.
class AsyncView<T> extends StatelessWidget {
  final Future<T> future;
  final Widget Function(BuildContext context, T data) builder;
  final Widget? loading;
  final String errorMessage;
  final VoidCallback? onRetry;

  const AsyncView({
    super.key,
    required this.future,
    required this.builder,
    this.loading,
    this.errorMessage = 'Something went wrong.',
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ErrorStateWidget(message: errorMessage, onRetry: onRetry);
        }
        if (!snapshot.hasData) {
          return loading ?? const AppLoadingIndicator();
        }
        return builder(context, snapshot.data as T);
      },
    );
  }
}

/// Same loading/error/data unification as [AsyncView], but for a live
/// [Stream] (e.g. a Firestore snapshot listener) instead of a one-off Future.
class AsyncStreamView<T> extends StatelessWidget {
  final Stream<T> stream;
  final Widget Function(BuildContext context, T data) builder;
  final Widget? loading;
  final String errorMessage;
  final VoidCallback? onRetry;

  const AsyncStreamView({
    super.key,
    required this.stream,
    required this.builder,
    this.loading,
    this.errorMessage = 'Something went wrong.',
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<T>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ErrorStateWidget(message: errorMessage, onRetry: onRetry);
        }
        if (!snapshot.hasData) {
          return loading ?? const AppLoadingIndicator();
        }
        return builder(context, snapshot.data as T);
      },
    );
  }
}
