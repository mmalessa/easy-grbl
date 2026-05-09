import 'package:flutter/material.dart';

class PanelSectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget? trailing;

  const PanelSectionHeader({
    super.key,
    required this.title,
    required this.icon,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      color: Colors.grey[200],
      child: Row(children: [
        Icon(icon, size: 13, color: Colors.grey[700]),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ),
        if (trailing != null) trailing!,
      ]),
    );
  }
}
