import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/cubit/theme_cubit.dart';
import '../../../../app/cubit/verse_text_size_cubit.dart';
import '../../../../models/qari.dart';
import '../../../../routes/route_names.dart';
import '../../../../services/api_config.dart';
import '../../../../services/preferences_service.dart';
import '../../../../services/service_locator.dart';
import '../../../../shared/ui/list_row.dart';
import '../../../../shared/widgets/feedback/app_dialogs.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../../shared/widgets/pickers/verse_text_size_picker.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../../theme/app_spacing.dart';

/// Settings: only what the app actually supports, grouped the way people look
/// for it. Every row reads and writes a real, persisted preference or opens an
/// existing screen.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late bool _notifications = Services.prefs.notificationsEnabled;
  late TranslationMode _translation = Services.prefs.translationMode;
  late bool _transliteration = Services.prefs.showTransliteration;
  List<Qari> _qaris = const [];

  @override
  void initState() {
    super.initState();
    Services.rattil.getQaris().then((q) {
      if (mounted) setState(() => _qaris = q);
    }).catchError((_) {});
  }

  static String _themeLabel(ThemeMode mode) => switch (mode) {
        ThemeMode.light => 'Light',
        ThemeMode.dark => 'Dark',
        ThemeMode.system => 'Match device',
      };

  static String _translationLabel(TranslationMode m) => switch (m) {
        TranslationMode.off => 'Off',
        TranslationMode.onTap => 'When you tap an ayah',
        TranslationMode.always => 'Under every ayah',
      };

  Future<T?> _choose<T>({required String title, required List<(T, String, String?)> options, required T current}) {
    return showModalBottomSheet<T>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screenPadding, 0, AppSpacing.screenPadding, AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(sheetContext).textTheme.headlineSmall),
              const SizedBox(height: AppSpacing.sm),
              RadioGroup<T>(
                groupValue: current,
                onChanged: (v) => Navigator.of(sheetContext).pop(v),
                child: Column(
                  children: [
                    for (final (value, label, subtitle) in options)
                      RadioListTile<T>(
                        contentPadding: EdgeInsets.zero,
                        value: value,
                        title: Text(label),
                        subtitle: subtitle == null ? null : Text(subtitle),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Where this device looks for the MakharijPro server. The app already tries
  /// the address it was built with, the last one that worked, and localhost --
  /// this is for the case where none of those are right: type the machine's
  /// address, or have the app look for it on this network. Debug builds only.
  Future<void> _editBackendAddress() async {
    const findSentinel = '\u0000find';
    final controller = TextEditingController(text: Services.prefs.backendBaseUrl ?? '');
    final answer = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Backend address'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'The machine running the MakharijPro server, for example '
              '192.168.1.23:8000. Leave it empty to let the app choose.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(hintText: '192.168.1.23:8000'),
              onSubmitted: (v) => Navigator.of(context).pop(v),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(findSentinel),
            child: const Text('Find it for me'),
          ),
          FilledButton(onPressed: () => Navigator.of(context).pop(controller.text), child: const Text('Save')),
        ],
      ),
    );
    if (answer == null || !mounted) return;

    if (answer == findSentinel) {
      await _findBackend();
      return;
    }

    await ApiConfig.setBaseUrl(answer);
    final reachable = await ApiConfig.canReach(ApiConfig.baseUrl);
    if (!mounted) return;
    setState(() {});
    AppSnackbar.show(
      context,
      reachable
          ? 'The server answered at ${ApiConfig.baseUrl}'
          : 'Saved, but nothing answered at ${ApiConfig.baseUrl} yet',
    );
  }

  /// Asks every address on this Wi-Fi whether it is the MakharijPro server.
  Future<void> _findBackend() async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(width: 16),
            Expanded(child: Text('Looking for the server on this network')),
          ],
        ),
      ),
    );
    final found = await ApiConfig.findOnLocalNetwork();
    if (!mounted) return;
    Navigator.of(context).pop();
    setState(() {});
    AppSnackbar.show(
      context,
      found != null
          ? 'Found the server at $found'
          : 'No server answered on this network. Check that it is running, and that both are on the same Wi-Fi.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = context.watch<ThemeCubit>().state;
    final verseSize = context.watch<VerseTextSizeCubit>().state;
    final preferred = _qaris.where((q) => q.qariId == Services.prefs.preferredQariId).firstOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.screenPadding, AppSpacing.sm, AppSpacing.screenPadding, AppSpacing.xl),
        children: [
          const SectionHeader(title: 'Appearance'),
          ListRow(
            icon: Icons.contrast_rounded,
            title: 'Theme',
            subtitle: _themeLabel(themeMode),
            showDivider: false,
            onTap: () async {
              final picked = await _choose<ThemeMode>(
                title: 'Theme',
                current: themeMode,
                options: const [
                  (ThemeMode.system, 'Match device', 'Follows the light or dark setting on your phone'),
                  (ThemeMode.light, 'Light', null),
                  (ThemeMode.dark, 'Dark', null),
                ],
              );
              if (picked != null && context.mounted) context.read<ThemeCubit>().setMode(picked);
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          const SectionHeader(title: 'Reading'),
          ListRow(
            icon: Icons.format_size_rounded,
            title: 'Quran text size',
            subtitle: verseSize.label,
            onTap: () => VerseTextSizePicker.show(context),
          ),
          ListRow(
            icon: Icons.translate_rounded,
            title: 'Translation',
            subtitle: _translationLabel(_translation),
            onTap: () async {
              final picked = await _choose<TranslationMode>(
                title: 'Translation',
                current: _translation,
                options: [
                  for (final m in TranslationMode.values) (m, _translationLabel(m), null),
                ],
              );
              if (picked == null) return;
              await Services.prefs.setTranslationMode(picked);
              setState(() => _translation = picked);
            },
          ),
          ListRow(
            icon: Icons.abc_rounded,
            title: 'Transliteration',
            subtitle: 'Under each ayah. Needs a connection.',
            showDivider: false,
            trailing: Switch.adaptive(
              value: _transliteration,
              onChanged: (v) async {
                await Services.prefs.setShowTransliteration(v);
                setState(() => _transliteration = v);
              },
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const SectionHeader(title: 'Listening'),
          ListRow(
            icon: Icons.graphic_eq_rounded,
            title: 'Reciter in the reader',
            subtitle: preferred?.nameEnglish ?? 'The reciter with the most surahs',
            showDivider: false,
            onTap: _qaris.isEmpty
                ? () => AppSnackbar.show(context, 'Reciters could not be loaded. Check your connection.', isError: true)
                : () async {
                    final picked = await _choose<String>(
                      title: 'Reciter in the reader',
                      current: preferred?.qariId ?? '',
                      options: [
                        for (final q in _qaris)
                          (q.qariId, q.nameEnglish, q.availableSurahs.length >= 114 ? 'Whole Quran' : '${q.availableSurahs.length} surahs'),
                      ],
                    );
                    if (picked == null || picked.isEmpty) return;
                    await Services.prefs.setPreferredQariId(picked);
                    setState(() {});
                  },
          ),
          const SizedBox(height: AppSpacing.lg),
          const SectionHeader(title: 'Notifications'),
          ListRow(
            icon: Icons.notifications_none_rounded,
            title: 'Notifications',
            subtitle: 'Milestones and updates in the app',
            showDivider: false,
            trailing: Switch.adaptive(
              value: _notifications,
              onChanged: (v) async {
                setState(() => _notifications = v);
                await Services.prefs.setNotificationsEnabled(v);
              },
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const SectionHeader(title: 'Account'),
          ListRow(icon: Icons.person_outline_rounded, title: 'Edit profile', onTap: () => context.push(RoutePaths.editProfile)),
          ListRow(
            icon: Icons.lock_outline_rounded,
            title: 'Change password',
            subtitle: 'We email you a secure link',
            showDivider: false,
            onTap: () => context.push(RoutePaths.forgotPassword),
          ),
          const SizedBox(height: AppSpacing.lg),
          const SectionHeader(title: 'Support'),
          ListRow(icon: Icons.help_outline_rounded, title: 'Help and questions', onTap: () => context.push(RoutePaths.helpFaq)),
          ListRow(icon: Icons.mail_outline_rounded, title: 'Contact us', onTap: () => context.push(RoutePaths.contact)),
          ListRow(
            icon: Icons.info_outline_rounded,
            title: 'About MakharijPro',
            showDivider: false,
            onTap: () => context.push(RoutePaths.about),
          ),
          if (ApiConfig.isConfigurable) ...[
            const SizedBox(height: AppSpacing.lg),
            const SectionHeader(
              title: 'Developer',
              subtitle: 'Debug builds only. Where this device looks for the MakharijPro server.',
            ),
            ListRow(
              icon: Icons.dns_outlined,
              title: 'Backend address',
              subtitle: '${ApiConfig.baseUrl} · ${ApiConfig.source}',
              showDivider: false,
              onTap: _editBackendAddress,
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          ListRow(
            icon: Icons.logout_rounded,
            title: 'Sign out',
            destructive: true,
            showDivider: false,
            onTap: () async {
              final confirmed = await AppDialogs.confirm(
                context,
                title: 'Sign out?',
                message: 'Your recitations and progress stay saved to your account.',
                confirmLabel: 'Sign out',
                cancelLabel: 'Stay signed in',
                isDestructive: true,
              );
              if (confirmed != true) return;
              await Services.auth.signOut();
              if (context.mounted) context.go(RoutePaths.welcome);
            },
          ),
        ],
      ),
    );
  }
}
