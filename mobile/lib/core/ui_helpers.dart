import 'package:flutter/material.dart';

import 'theme.dart';

/// A floating snackbar in the app's style. [error] tints it destructive.
void showSnack(BuildContext context, String message, {bool error = false}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(
            error ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
      backgroundColor:
          error ? AppColors.destructive : const Color(0xFF16A34A),
      duration: Duration(seconds: error ? 4 : 3),
    ),
  );
}
