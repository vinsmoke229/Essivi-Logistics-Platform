import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SessionTimeoutWrapper extends ConsumerStatefulWidget {
  final Widget child;
  final Duration timeoutDuration;
  final VoidCallback onTimeout;

  const SessionTimeoutWrapper({
    super.key,
    required this.child,
    this.timeoutDuration = const Duration(minutes: 5),
    required this.onTimeout,
  });

  @override
  ConsumerState<SessionTimeoutWrapper> createState() => _SessionTimeoutWrapperState();
}

class _SessionTimeoutWrapperState extends ConsumerState<SessionTimeoutWrapper> {
  Timer? _timeoutTimer;
  Timer? _warningTimer;

  @override
  void initState() {
    super.initState();
    _resetTimer();
  }

  void _resetTimer() {
    _timeoutTimer?.cancel();
    _warningTimer?.cancel();

    // Avertissement 1 minute avant timeout
    _warningTimer = Timer(const Duration(minutes: 4), () {
      _showWarningDialog();
    });

    // Timeout principal
    _timeoutTimer = Timer(widget.timeoutDuration, () {
      widget.onTimeout();
    });
  }

  void _showWarningDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.timer_outlined, color: Colors.orange),
            SizedBox(width: 8),
            Text("Session expirée"),
          ],
        ),
        content: const Text(
          "Votre session va expirer dans 1 minute.\nVeuillez sauvegarder votre travail.",
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _resetTimer();
            },
            child: const Text("Prolonger"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _resetTimer,
      onPanStart: (_) => _resetTimer(),
      child: widget.child,
    );
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _warningTimer?.cancel();
    super.dispose();
  }
}
