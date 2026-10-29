import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';
import '../l10n/localized_error.dart';
import '../models/turn_config.dart';
import '../widgets/turn_config_dialog.dart';
import 'settings_screen.dart';
import 'room_screen.dart';
import '../services/signaling_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _hostIpController = TextEditingController();
  final _hostIpFocusNode = FocusNode();
  final _portController = TextEditingController(text: '8080');
  static const _legacySavedIpsPreferenceKey = 'saved_ips';
  static const _maxSavedIps = 5;
  String get _savedIpsPreferenceKey => 'saved_ips_${Platform.operatingSystem}';
  String get _legacySavedIpsCleanupKey =>
      'saved_ips_legacy_cleanup_done_${Platform.operatingSystem}';
  bool _isStartingRoom = false;
  bool _isLoadingUsername = true;
  bool _showAllTurnConfigs = false;
  String? _displayName;
  List<String> _savedIps = const [];
  List<TurnConfig> _turnConfigs = const [];
  int? _selectedTurnConfigIndex;

  @override
  void initState() {
    super.initState();
    _loadDisplayName();
  }

  @override
  void dispose() {
    _hostIpController.dispose();
    _hostIpFocusNode.dispose();
    _portController.dispose();
    super.dispose();
  }

  Future<void> _loadDisplayName() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await _loadSavedIps(preferences);
      await _loadTurnConfigs(preferences);
      final savedName = preferences.getString('display_name')?.trim();
      if (savedName != null && savedName.isNotEmpty) {
        if (mounted) {
          setState(() {
            _displayName = savedName;
            _isLoadingUsername = false;
          });
        }
        return;
      }

      if (!mounted) return;
      final displayName = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _UsernameDialog(preferences: preferences),
      );
      if (mounted && displayName != null) {
        setState(() {
          _displayName = displayName;
          _isLoadingUsername = false;
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoadingUsername = false);
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.couldNotLoadName('$error'))));
    }
  }

  Future<void> _loadSavedIps(SharedPreferences preferences) async {
    try {
      if (!(preferences.getBool(_legacySavedIpsCleanupKey) ?? false)) {
        await preferences.remove(_legacySavedIpsPreferenceKey);
        final cleanupRecorded = await preferences.setBool(
          _legacySavedIpsCleanupKey,
          true,
        );
        if (!cleanupRecorded) {
          throw StateError('Legacy saved IP cleanup could not be recorded.');
        }
      }
      final savedIps = preferences.getStringList(_savedIpsPreferenceKey) ?? [];
      final validIps = savedIps
          .map((ip) => ip.trim())
          .where(_isValidIpv4)
          .toSet()
          .take(_maxSavedIps)
          .toList();
      if (!mounted) return;
      setState(() => _savedIps = validIps);
    } catch (error) {
      if (mounted) _showError(error);
    }
  }

  Future<void> _rememberIp(String address) async {
    final normalizedAddress = address.trim();
    if (!_isValidIpv4(normalizedAddress)) return;

    try {
      final preferences = await SharedPreferences.getInstance();
      final updatedIps = <String>[
        normalizedAddress,
        ..._savedIps.where((ip) => ip != normalizedAddress),
      ].take(_maxSavedIps).toList();
      final saved = await preferences.setStringList(
        _savedIpsPreferenceKey,
        updatedIps,
      );
      if (!saved) throw StateError('The IP address could not be saved.');
      if (mounted) setState(() => _savedIps = updatedIps);
    } catch (error) {
      if (mounted) _showError(error);
    }
  }

  Future<void> _loadTurnConfigs(SharedPreferences preferences) async {
    final encodedConfigs = preferences.getString('turn_configs');
    var configs = <TurnConfig>[];
    if (encodedConfigs != null) {
      try {
        final decoded = jsonDecode(encodedConfigs);
        if (decoded is! List ||
            decoded.any((item) => item is! Map<String, dynamic>)) {
          throw const FormatException('Expected a JSON array of TURN configs.');
        }
        configs = decoded
            .cast<Map<String, dynamic>>()
            .map(TurnConfig.fromJson)
            .toList();
      } catch (error) {
        if (mounted) {
          final l10n = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.couldNotLoadTurnConfigs('$error'))),
          );
        }
      }
    }

    final savedIndex = preferences.getInt('selected_turn_config_index');
    if (!mounted) return;
    setState(() {
      _turnConfigs = configs;
      _selectedTurnConfigIndex =
          savedIndex != null && savedIndex >= 0 && savedIndex < configs.length
          ? savedIndex
          : null;
    });
  }

  Future<void> _editDisplayName() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final preferences = await SharedPreferences.getInstance();
      if (!mounted) return;
      final name = await showDialog<String>(
        context: context,
        builder: (_) => _UsernameDialog(
          preferences: preferences,
          initialName: _displayName,
        ),
      );
      if (!mounted || name == null) return;
      setState(() => _displayName = name);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.couldNotSaveName('$error'))),
        );
      }
    }
  }

  Future<void> _addTurnConfig() async {
    final config = await showDialog<TurnConfig>(
      context: context,
      builder: (_) => const TurnConfigDialog(),
    );
    if (!mounted || config == null) return;

    await _saveTurnConfigs([
      ..._turnConfigs,
      config,
    ], _selectedTurnConfigIndex ?? _turnConfigs.length);
  }

  Future<void> _editTurnConfig(int index) async {
    final config = await showDialog<TurnConfig>(
      context: context,
      builder: (_) => TurnConfigDialog(initialConfig: _turnConfigs[index]),
    );
    if (!mounted || config == null) return;

    final configs = [..._turnConfigs];
    configs[index] = config;
    await _saveTurnConfigs(configs, _selectedTurnConfigIndex);
  }

  Future<void> _deleteSelectedTurnConfig() async {
    final l10n = AppLocalizations.of(context)!;
    final selectedIndex = _selectedTurnConfigIndex;
    if (selectedIndex == null || selectedIndex >= _turnConfigs.length) return;
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteTurnConfigTitle),
        content: Text(
          l10n.deleteTurnConfigConfirm(_turnConfigs[selectedIndex].name),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (!mounted || shouldDelete != true) return;

    final configs = [..._turnConfigs]..removeAt(selectedIndex);
    final updatedSelectedIndex = configs.isEmpty
        ? null
        : selectedIndex < configs.length
        ? selectedIndex
        : configs.length - 1;
    await _saveTurnConfigs(configs, updatedSelectedIndex);
  }

  Future<void> _saveTurnConfigs(
    List<TurnConfig> configs,
    int? selectedIndex,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final preferences = await SharedPreferences.getInstance();
      final saved = await preferences.setString(
        'turn_configs',
        jsonEncode(configs.map((item) => item.toJson()).toList()),
      );
      if (!saved) {
        throw StateError('The TURN configuration could not be saved.');
      }
      final selectionSaved = selectedIndex == null
          ? await preferences.remove('selected_turn_config_index')
          : await preferences.setInt(
              'selected_turn_config_index',
              selectedIndex,
            );
      if (!selectionSaved) {
        throw StateError('The selected configuration could not be saved.');
      }
      if (mounted) {
        setState(() {
          _turnConfigs = configs;
          _selectedTurnConfigIndex = selectedIndex;
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.couldNotSaveTurnConfig('$error'))),
        );
      }
    }
  }

  Future<void> _selectTurnConfig(int index) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final preferences = await SharedPreferences.getInstance();
      final saved = await preferences.setInt(
        'selected_turn_config_index',
        index,
      );
      if (!saved) {
        throw StateError('The selected configuration could not be saved.');
      }
      if (mounted) setState(() => _selectedTurnConfigIndex = index);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.couldNotSelectTurnConfig('$error'))),
        );
      }
    }
  }

  int? _readPort() {
    final l10n = AppLocalizations.of(context)!;
    final port = int.tryParse(_portController.text.trim());
    if (port == null || port < 1 || port > 65535) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.enterValidPort)));
      return null;
    }
    return port;
  }

  bool _isValidIpv4(String address) {
    final parts = address.split('.');
    return parts.length == 4 &&
        parts.every((part) {
          if (part.isEmpty || part.length > 3) return false;
          final octet = int.tryParse(part);
          return octet != null && octet <= 255;
        });
  }

  TurnConfig? get _selectedTurnConfig {
    final index = _selectedTurnConfigIndex;
    if (index == null || index < 0 || index >= _turnConfigs.length) {
      return null;
    }
    return _turnConfigs[index];
  }

  Future<void> _hostRoom() async {
    if (_isStartingRoom || _displayName == null) return;
    final port = _readPort();
    if (port == null) return;
    setState(() => _isStartingRoom = true);
    try {
      await context.read<SignalingService>().startHosting(
        port,
        displayName: _displayName!,
        turnServer: _selectedTurnConfig,
      );
    } catch (error) {
      if (!mounted) return;
      _showError(error);
      return;
    } finally {
      if (mounted) setState(() => _isStartingRoom = false);
    }
    if (!mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RoomScreen(isHost: true, port: port),
      ),
    );
  }

  Future<void> _joinRoom() async {
    final l10n = AppLocalizations.of(context)!;
    if (_isStartingRoom || _displayName == null) return;
    final hostIp = _hostIpController.text.trim();
    if (!_isValidIpv4(hostIp)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.enterValidIpv4)));
      return;
    }

    final port = _readPort();
    if (port == null) return;
    setState(() => _isStartingRoom = true);
    final signaling = context.read<SignalingService>();
    try {
      await signaling.joinRoom(
        hostIp: hostIp,
        port: port,
        displayName: _displayName!,
        turnServer: _selectedTurnConfig,
      );
    } catch (error) {
      if (!mounted) return;
      _showError(error);
      return;
    } finally {
      if (mounted) setState(() => _isStartingRoom = false);
    }
    if (!mounted) return;

    FocusManager.instance.primaryFocus?.unfocus();
    final approved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _JoinApprovalDialog(signaling: signaling),
    );
    if (!mounted) return;
    FocusManager.instance.primaryFocus?.unfocus();
    if (approved != true) {
      final wasRejected = signaling.joinRejected;
      final microphoneUnavailable =
          signaling.errorMessage?.contains(
            'Microphone not found or access denied',
          ) ??
          false;
      try {
        await signaling.leaveRoom();
      } catch (error) {
        if (mounted) _showError(error);
      }
      if (mounted && wasRejected) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.joinRejected),
            duration: Duration(seconds: 3),
          ),
        );
      } else if (mounted && microphoneUnavailable) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.microphoneUnavailable)));
      }
      return;
    }

    await _rememberIp(hostIp);
    if (!mounted) return;
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RoomScreen(isHost: false, hostIp: hostIp, port: port),
      ),
    );
  }

  void _showError(Object error) {
    final message = localizedError(AppLocalizations.of(context)!, error);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 72,
        leading: Padding(
          padding: const EdgeInsetsDirectional.only(start: 16, top: 8),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: _isLoadingUsername ? null : _editDisplayName,
            child: CircleAvatar(
              backgroundColor: colorScheme.primaryContainer,
              foregroundColor: colorScheme.onPrimaryContainer,
              child: const Icon(Icons.person),
            ),
          ),
        ),
        title: Text(l10n.appTitle),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: l10n.settings,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
            ),
            icon: const Icon(Icons.settings_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.graphic_eq_rounded,
                    size: 64,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _displayName == null
                        ? l10n.homeTagline
                        : l10n.welcomeUser(_displayName!),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.homeDescription,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge
                        ?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 32),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            l10n.roomSettings,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 16),
                          RawAutocomplete<String>(
                            textEditingController: _hostIpController,
                            focusNode: _hostIpFocusNode,
                            optionsBuilder: (textEditingValue) {
                              final query = textEditingValue.text.trim();
                              if (query.isEmpty) return _savedIps;
                              return _savedIps.where(
                                (ip) => ip.toLowerCase().contains(
                                  query.toLowerCase(),
                                ),
                              );
                            },
                            onSelected: (ip) {
                              _hostIpController
                                ..text = ip
                                ..selection = TextSelection.collapsed(
                                  offset: ip.length,
                                );
                              FocusScope.of(context).unfocus();
                            },
                            fieldViewBuilder:
                                (
                                  context,
                                  textEditingController,
                                  focusNode,
                                  onFieldSubmitted,
                                ) => TextField(
                                  controller: textEditingController,
                                  focusNode: focusNode,
                                  keyboardType: TextInputType.number,
                                  textInputAction: TextInputAction.next,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(r'[0-9.]'),
                                    ),
                                  ],
                                  decoration: InputDecoration(
                                    labelText: l10n.hostIp,
                                    hintText: l10n.hostIpHint,
                                    prefixIcon: const Icon(
                                      Icons.computer_rounded,
                                    ),
                                  ),
                                  onSubmitted: (_) => onFieldSubmitted(),
                                ),
                            optionsViewBuilder: (context, onSelected, options) {
                              final ips = options.toList();
                              return Align(
                                alignment: AlignmentDirectional.topStart,
                                child: Material(
                                  elevation: 4,
                                  borderRadius: BorderRadius.circular(12),
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxHeight: 220,
                                    ),
                                    child: ListView.builder(
                                      padding: EdgeInsets.zero,
                                      shrinkWrap: true,
                                      itemCount: ips.length,
                                      itemBuilder: (context, index) {
                                        final ip = ips[index];
                                        return ListTile(
                                          dense: true,
                                          leading: const Icon(
                                            Icons.computer_rounded,
                                          ),
                                          title: Text(ip),
                                          onTap: () => onSelected(ip),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _portController,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.done,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(5),
                            ],
                            decoration: InputDecoration(
                              labelText: l10n.port,
                              prefixIcon: Icon(Icons.settings_ethernet_rounded),
                            ),
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
                            l10n.turnConfigs,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _addTurnConfig,
                                  icon: const Icon(Icons.add_rounded),
                                  label: Text(l10n.addTurnConfig),
                                ),
                              ),
                              if (_selectedTurnConfigIndex != null)
                                IconButton(
                                  tooltip: l10n.deleteSelectedTurnConfig,
                                  onPressed: _deleteSelectedTurnConfig,
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                  ),
                                  color: colorScheme.error,
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (_turnConfigs.isEmpty)
                            Text(
                              l10n.noTurnConfigs,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          for (final index in List<int>.generate(
                            _showAllTurnConfigs
                                ? _turnConfigs.length
                                : _turnConfigs.length.clamp(0, 2).toInt(),
                            (index) => index,
                          ))
                            Card(
                              margin: const EdgeInsets.only(top: 8),
                              color: _selectedTurnConfigIndex == index
                                  ? colorScheme.secondaryContainer
                                  : null,
                              child: ListTile(
                                onTap: () => _selectTurnConfig(index),
                                leading: Icon(
                                  _selectedTurnConfigIndex == index
                                      ? Icons.radio_button_checked
                                      : Icons.radio_button_unchecked,
                                  color: _selectedTurnConfigIndex == index
                                      ? colorScheme.primary
                                      : colorScheme.onSurfaceVariant,
                                ),
                                title: Text(_turnConfigs[index].name),
                                subtitle: Text(_turnConfigs[index].turnUrl),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip:
                                          'Edit ${_turnConfigs[index].name}',
                                      onPressed: () => _editTurnConfig(index),
                                      icon: const Icon(Icons.edit_outlined),
                                    ),
                                    const Icon(Icons.dns_outlined),
                                  ],
                                ),
                              ),
                            ),
                          if (_turnConfigs.length > 2)
                            TextButton(
                              onPressed: () => setState(
                                () =>
                                    _showAllTurnConfigs = !_showAllTurnConfigs,
                              ),
                              child: Text(
                                _showAllTurnConfigs
                                    ? l10n.showLess
                                    : l10n.showMore,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed:
                        _isStartingRoom ||
                            _isLoadingUsername ||
                            _displayName == null
                        ? null
                        : _hostRoom,
                    icon: _isLoadingUsername
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : _isStartingRoom
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add_rounded),
                    label: Text(
                      _isLoadingUsername
                          ? l10n.loading
                          : _isStartingRoom
                          ? l10n.starting
                          : l10n.hostRoom,
                    ),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed:
                        _isStartingRoom ||
                            _isLoadingUsername ||
                            _displayName == null
                        ? null
                        : _joinRoom,
                    icon: const Icon(Icons.login_rounded),
                    label: Text(l10n.joinRoom),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UsernameDialog extends StatefulWidget {
  const _UsernameDialog({required this.preferences, this.initialName});

  final SharedPreferences preferences;
  final String? initialName;

  @override
  State<_UsernameDialog> createState() => _UsernameDialogState();
}

class _JoinApprovalDialog extends StatefulWidget {
  const _JoinApprovalDialog({required this.signaling});

  final SignalingService signaling;

  @override
  State<_JoinApprovalDialog> createState() => _JoinApprovalDialogState();
}

class _JoinApprovalDialogState extends State<_JoinApprovalDialog> {
  bool _isDismissing = false;

  @override
  void initState() {
    super.initState();
    widget.signaling.addListener(_handleSignalingUpdate);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _handleSignalingUpdate();
    });
  }

  @override
  void dispose() {
    widget.signaling.removeListener(_handleSignalingUpdate);
    super.dispose();
  }

  void _handleSignalingUpdate() {
    if (!mounted || _isDismissing) return;
    if (widget.signaling.joinApproved) {
      _dismiss(true);
    } else if (widget.signaling.joinRejected ||
        widget.signaling.roomClosed ||
        widget.signaling.errorMessage != null) {
      _dismiss(false);
    }
  }

  void _dismiss(bool approved) {
    if (!mounted || _isDismissing) return;
    _isDismissing = true;
    FocusManager.instance.primaryFocus?.unfocus();
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop(approved);
  }

  Future<void> _cancelRequest() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await widget.signaling.cancelJoinRequest();
      if (mounted) _dismiss(false);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.cancelRequestError('$error'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 20),
          Text(l10n.waitingApproval),
        ],
      ),
      actions: [
        TextButton(onPressed: _cancelRequest, child: Text(l10n.cancelRequest)),
      ],
    );
  }
}

class _UsernameDialogState extends State<_UsernameDialog> {
  final _controller = TextEditingController();
  String? _errorMessage;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _controller.text = widget.initialName ?? '';
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    final l10n = AppLocalizations.of(context)!;
    final name = _controller.text.trim();
    if (name.isEmpty || name.length > 40) {
      setState(() => _errorMessage = l10n.nameLengthError);
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    try {
      final saved = await widget.preferences.setString('display_name', name);
      if (!saved) {
        throw StateError('The name could not be saved.');
      }
      if (!mounted) return;
      Navigator.of(context).pop(name);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _errorMessage = l10n.nameSaveError('$error');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: Text(l10n.profileNamePrompt),
        content: TextField(
          controller: _controller,
          autofocus: true,
          maxLength: 40,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _saveName(),
          decoration: InputDecoration(
            labelText: l10n.displayName,
            errorText: _errorMessage,
          ),
        ),
        actions: [
          FilledButton(
            onPressed: _isSaving ? null : _saveName,
            child: _isSaving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.save),
          ),
        ],
      ),
    );
  }
}
