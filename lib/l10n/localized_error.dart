import 'app_localizations.dart';
import '../services/signaling_service.dart';

String localizedError(AppLocalizations l10n, Object error) {
  final detail = error is SignalingException ? error.message : '$error';
  if (detail.contains('Microphone not found or access denied')) {
    return l10n.microphoneUnavailable;
  }
  if (detail.startsWith('Connection failed:')) {
    return l10n.connectionFailed;
  }
  if (detail.startsWith('Could not start the room server:')) {
    return l10n.hostingFailed(
      detail.substring('Could not start the room server:'.length).trim(),
    );
  }
  if (detail.startsWith('Could not access the microphone:')) {
    return l10n.microphoneFailed(
      detail.substring('Could not access the microphone:'.length).trim(),
    );
  }
  if (detail.startsWith('No local IPv4 address is available.')) {
    return l10n.noLocalAddress;
  }
  return l10n.requestFailed(detail);
}
