import 'package:flutter/material.dart';

class AppSnackBar {
  static void show(BuildContext context, String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: InkWell(
          onTap: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
          child: Row(
            children: [
              Expanded(child: Text(message)),
              const Icon(Icons.close, size: 16, color: Colors.white70),
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
