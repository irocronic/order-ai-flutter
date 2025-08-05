// lib/widgets/admin/admin_confirmation_dialog.dart
import 'package:flutter/material.dart';

class AdminConfirmationDialog extends StatelessWidget {
  final String title;
  final String content;
  final String confirmButtonText;
  final bool isDestructive;

  const AdminConfirmationDialog({
    Key? key,
    required this.title,
    required this.content,
    this.confirmButtonText = "Evet",
    this.isDestructive = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white.withOpacity(0.95),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      content: Text(content),
      actions: <Widget>[
        TextButton(
          child: const Text('İptal'),
          onPressed: () {
            Navigator.of(context).pop(false);
          },
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: isDestructive ? Colors.redAccent : Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
          ),
          child: Text(confirmButtonText),
          onPressed: () {
            Navigator.of(context).pop(true);
          },
        ),
      ],
    );
  }
}