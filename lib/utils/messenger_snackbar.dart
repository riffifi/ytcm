import 'package:flutter/material.dart';
import '../theme.dart';

void showMessengerSnackBar(BuildContext context, String message) {
  if (message.trim().isEmpty) return;
  final c = context.mc;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        message,
        style: TextStyle(color: c.primary, fontSize: 14),
      ),
      backgroundColor: c.surfaceHigh,
      behavior: SnackBarBehavior.floating,
    ),
  );
}
