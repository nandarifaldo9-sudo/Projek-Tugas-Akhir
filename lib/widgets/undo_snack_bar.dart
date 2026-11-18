import 'package:flutter/material.dart';

void showUndoSnackBar(
  ScaffoldMessengerState messenger, {
  required String message,
  required Future<String?> Function() onUndo,
}) {
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      duration: const Duration(seconds: 6),
      action: SnackBarAction(
        label: 'URUNGKAN',
        onPressed: () async {
          final error = await onUndo();
          messenger.showSnackBar(
            SnackBar(content: Text(error ?? 'Perubahan berhasil dipulihkan.')),
          );
        },
      ),
    ),
  );
}
