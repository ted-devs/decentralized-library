import 'package:flutter/material.dart';

class AppSnackBar {
  static void show(BuildContext context, String message) {
    final messenger = ScaffoldMessenger.of(context);
    final theme = Theme.of(context);
    
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: theme.colorScheme.inverseSurface,
        content: InkWell(
          onTap: () => messenger.hideCurrentSnackBar(),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(color: theme.colorScheme.onInverseSurface),
                ),
              ),
              Icon(
                Icons.close,
                size: 16,
                color: theme.colorScheme.onInverseSurface.withAlpha(180),
              ),
            ],
          ),
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
