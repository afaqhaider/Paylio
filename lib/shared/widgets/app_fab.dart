import 'package:flutter/material.dart';

class AppFab extends StatelessWidget {
  final VoidCallback onPressed;
  final String? label;
  final IconData icon;

  const AppFab({
    super.key,
    required this.onPressed,
    this.label,
    this.icon = Icons.add_rounded,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    if (label != null) {
      return FloatingActionButton.extended(
        onPressed: onPressed,
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: Icon(icon, size: 28),
        label: Text(
          label!,
          style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.5),
        ),
      );
    }

    return FloatingActionButton(
      onPressed: onPressed,
      backgroundColor: theme.colorScheme.primary,
      foregroundColor: Colors.white,
      elevation: 4,
      shape: const CircleBorder(),
      child: Icon(icon, size: 32),
    );
  }
}
