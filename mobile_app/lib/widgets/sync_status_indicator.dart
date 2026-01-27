import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../presentation/providers/data_service_provider.dart';

class SyncStatusIndicator extends ConsumerStatefulWidget {
  const SyncStatusIndicator({super.key});

  @override
  ConsumerState<SyncStatusIndicator> createState() => _SyncStatusIndicatorState();
}

class _SyncStatusIndicatorState extends ConsumerState<SyncStatusIndicator> {
  bool _isOnline = true;
  int _pendingSync = 0;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _checkPendingSync();
    
    // Vérifier toutes les 30 secondes
    Timer.periodic(const Duration(seconds: 30), (_) {
      _checkConnectivity();
      _checkPendingSync();
    });
  }

  void _checkConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    setState(() {
      _isOnline = result != ConnectivityResult.none;
    });
  }

  void _checkPendingSync() async {
    try {
      final unsynced = await ref.read(dataServiceProvider).getUnsyncedDeliveries();
      setState(() {
        _pendingSync = unsynced.length;
      });
    } catch (e) {
      // Erreur silencieuse
    }
  }

  void _syncNow() async {
    if (_isOnline && _pendingSync > 0) {
      setState(() => _isSyncing = true);
      await ref.read(dataServiceProvider).syncOfflineDeliveries();
      _checkPendingSync();
      setState(() => _isSyncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    IconData statusIcon;
    String statusText;

    if (_isSyncing) {
      statusColor = Colors.orange;
      statusIcon = Icons.sync;
      statusText = "Synchronisation...";
    } else if (!_isOnline) {
      statusColor = Colors.red;
      statusIcon = Icons.sync_problem;
      statusText = "Hors ligne";
    } else if (_pendingSync > 0) {
      statusColor = Colors.amber;
      statusIcon = Icons.sync_problem;
      statusText = "$_pendingSync en attente";
    } else {
      statusColor = Colors.green;
      statusIcon = Icons.sync;
      statusText = "Synchronisé";
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isSyncing)
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              ),
            )
          else
            Icon(statusIcon, size: 16, color: statusColor),
          const SizedBox(width: 8),
          Text(
            statusText,
            style: TextStyle(
              color: statusColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (_pendingSync > 0 && !_isSyncing && _isOnline) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _syncNow,
              child: Icon(
                Icons.refresh,
                size: 16,
                color: statusColor,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
