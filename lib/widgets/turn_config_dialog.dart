import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/turn_config.dart';

class TurnConfigDialog extends StatefulWidget {
  const TurnConfigDialog({super.key, this.initialConfig});

  final TurnConfig? initialConfig;

  @override
  State<TurnConfigDialog> createState() => _TurnConfigDialogState();
}

class _TurnConfigDialogState extends State<TurnConfigDialog> {
  final _nameController = TextEditingController();
  final _urlController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final config = widget.initialConfig;
    if (config != null) {
      _nameController.text = config.name;
      _urlController.text = config.turnUrl;
      _usernameController.text = config.username;
      _passwordController.text = config.password;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _saveConfig() {
    final l10n = AppLocalizations.of(context)!;
    final name = _nameController.text.trim();
    final url = _urlController.text.trim();
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    final uriMatch = RegExp(r'^turns?:([^\s]+)$').firstMatch(url);
    final authority = uriMatch?.group(1);
    final endpoint = authority == null ? null : Uri.tryParse('//$authority');
    var validPort = true;
    if (endpoint?.hasPort ?? false) {
      try {
        validPort = endpoint!.port > 0 && endpoint.port <= 65535;
      } on FormatException {
        validPort = false;
      }
    }
    if (name.isEmpty ||
        name.length > 50 ||
        uriMatch == null ||
        endpoint == null ||
        endpoint.host.isEmpty ||
        !validPort ||
        username.isEmpty ||
        password.isEmpty) {
      setState(() => _errorMessage = l10n.turnConfigValidation);
      return;
    }

    Navigator.of(context).pop(
      TurnConfig(
        name: name,
        turnUrl: url,
        username: username,
        password: password,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(
        widget.initialConfig == null
            ? l10n.turnConfigAddTitle
            : l10n.turnConfigEditTitle,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: l10n.configName,
                hintText: l10n.configNameHint,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _urlController,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: l10n.turnUrl,
                hintText: l10n.turnUrlHint,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _usernameController,
              decoration: InputDecoration(labelText: l10n.turnUsername),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(labelText: l10n.turnPassword),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _saveConfig, child: Text(l10n.save)),
      ],
    );
  }
}
