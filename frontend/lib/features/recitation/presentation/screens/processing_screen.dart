import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../routes/route_names.dart';
import '../../../../shared/widgets/states/error_state_widget.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_spacing.dart';
import '../bloc/recitation_cubit.dart';
import '../bloc/recitation_state.dart';

class ProcessingScreen extends StatefulWidget {
  final int surahNumber;
  const ProcessingScreen({super.key, required this.surahNumber});

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final List<String> _steps = [
    'Uploading audio...',
    'Extracting MFCC features...',
    'Comparing with reference recitation...',
    'Generating feedback...',
  ];
  int _stepIndex = 0;
  Timer? _stepTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
    _stepTimer = Timer.periodic(const Duration(milliseconds: 550), (timer) {
      if (_stepIndex < _steps.length - 1) {
        setState(() => _stepIndex++);
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _stepTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<RecitationCubit, RecitationState>(
      listener: (context, state) {
        if (state.status == RecitationStatus.result) {
          context.pushReplacement(RoutePaths.resultPath(widget.surahNumber));
        }
      },
      builder: (context, state) {
        if (state.status == RecitationStatus.error) {
          return Scaffold(
            body: ErrorStateWidget(
              title: 'Analysis failed',
              message: state.errorMessage ?? 'Something went wrong while analyzing your recitation.',
              onRetry: () => context.read<RecitationCubit>().stopAndProcess(),
            ),
          );
        }
        return Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RotationTransition(
                  turns: _controller,
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: SweepGradient(colors: [AppColors.primarySurface, AppColors.primary, AppColors.primarySurface]),
                    ),
                    padding: const EdgeInsets.all(6),
                    child: const CircleAvatar(backgroundColor: AppColors.background),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text('Analyzing Your Recitation', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: AppSpacing.sm),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Text(
                    _steps[_stepIndex],
                    key: ValueKey(_stepIndex),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
