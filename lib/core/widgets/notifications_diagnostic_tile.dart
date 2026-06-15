import 'package:flutter/material.dart';

import '../config/env.dart';
import '../services/push_service.dart';

/// A small card that lets a user check whether push notifications are working
/// and (re)register their device token. Useful for debugging why a token may
/// not appear in Supabase.
class NotificationsDiagnosticTile extends StatefulWidget {
  const NotificationsDiagnosticTile({super.key});

  @override
  State<NotificationsDiagnosticTile> createState() =>
      _NotificationsDiagnosticTileState();
}

class _NotificationsDiagnosticTileState
    extends State<NotificationsDiagnosticTile> {
  bool _busy = false;
  String? _status;

  Future<void> _run() async {
    setState(() => _busy = true);
    final result = await PushService.debugStatus();
    if (mounted) {
      setState(() {
        _busy = false;
        _status = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = Env.pushEnabled && PushService.firebaseReady;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.notifications_active_outlined,
                    size: 20, color: scheme.primary),
                const SizedBox(width: 8),
                Text('Push notifications',
                    style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                Icon(
                  enabled ? Icons.check_circle : Icons.cancel,
                  size: 18,
                  color: enabled ? Colors.green : scheme.error,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              enabled
                  ? 'Enabled. Tap below to (re)register this device.'
                  : 'Disabled. Push is off or Firebase is not configured for this build.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (_status != null) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_status!,
                    style: Theme.of(context).textTheme.bodySmall),
              ),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: (!enabled || _busy) ? null : _run,
                icon: _busy
                    ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.sync, size: 18),
                label: Text(_busy ? 'Checking…' : 'Register / test device'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
