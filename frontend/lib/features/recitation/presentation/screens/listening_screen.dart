import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../dummy/dummy_ayahs.dart';
import '../../../../routes/route_names.dart';
import '../../../../shared/widgets/buttons/app_icon_button.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_typography.dart';
import '../bloc/recitation_cubit.dart';

class ListeningScreen extends StatefulWidget {
  final int surahNumber;
  const ListeningScreen({super.key, required this.surahNumber});

  @override
  State<ListeningScreen> createState() => _ListeningScreenState();
}

class _ListeningScreenState extends State<ListeningScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  final int _currentAyah = 0;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ayah = dummyFatihahAyahs[_currentAyah];
    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Listening...', style: TextStyle(color: Colors.white)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Center(
                  child: Text(
                    ayah.arabicText,
                    style: AppTypography.arabicVerse(fontSize: 28, color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
            _Waveform(),
            const SizedBox(height: AppSpacing.xl),
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final scale = 1 + (_pulseController.value * 0.15);
                return Transform.scale(scale: scale, child: child);
              },
              child: AppIconButton(
                icon: Icons.stop_rounded,
                size: 76,
                background: Colors.white,
                iconColor: AppColors.primary,
                onPressed: () {
                  context.read<RecitationCubit>().stopAndProcess();
                  context.pushReplacement(RoutePaths.processingPath(widget.surahNumber));
                },
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text('Tap to finish recitation', style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}

class _Waveform extends StatefulWidget {
  @override
  State<_Waveform> createState() => _WaveformState();
}

class _WaveformState extends State<_Waveform> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final _rand = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))
      ..addListener(() => setState(() {}))
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(24, (i) {
          final height = 6.0 + _rand.nextInt(36);
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 4,
            height: height,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(color: Colors.white70, borderRadius: BorderRadius.circular(2)),
          );
        }),
      ),
    );
  }
}
