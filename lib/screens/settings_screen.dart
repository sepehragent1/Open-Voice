import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../services/app_settings.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _changeLanguage(
    BuildContext context,
    AppSettings settings,
    AppLanguage language,
  ) async {
    try {
      await settings.setLanguage(language);
    } catch (error) {
      if (!context.mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.settingsSaveError('$error'))));
    }
  }

  Future<void> _changeTheme(
    BuildContext context,
    AppSettings settings,
    AppTheme theme,
  ) async {
    try {
      await settings.setTheme(theme);
    } catch (error) {
      if (!context.mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.settingsSaveError('$error'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  l10n.settingsSubtitle,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          l10n.language,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<AppLanguage>(
                          initialValue: settings.language,
                          decoration: InputDecoration(
                            labelText: l10n.language,
                            border: const OutlineInputBorder(),
                          ),
                          items: [
                            DropdownMenuItem(
                              value: AppLanguage.english,
                              child: Text(l10n.english),
                            ),
                            DropdownMenuItem(
                              value: AppLanguage.persian,
                              child: Text(l10n.persian),
                            ),
                            DropdownMenuItem(
                              value: AppLanguage.system,
                              child: Text(l10n.systemDefault),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              _changeLanguage(context, settings, value);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          l10n.theme,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<AppTheme>(
                          initialValue: settings.theme,
                          decoration: InputDecoration(
                            labelText: l10n.theme,
                            border: const OutlineInputBorder(),
                          ),
                          items: [
                            DropdownMenuItem(
                              value: AppTheme.light,
                              child: Text(l10n.light),
                            ),
                            DropdownMenuItem(
                              value: AppTheme.dark,
                              child: Text(l10n.dark),
                            ),
                            DropdownMenuItem(
                              value: AppTheme.system,
                              child: Text(l10n.systemDefault),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              _changeTheme(context, settings, value);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
