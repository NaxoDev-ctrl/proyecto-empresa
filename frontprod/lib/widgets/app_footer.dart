import 'package:flutter/material.dart';

// Widget reutilizable para el footer (pie de página)
class AppFooter extends StatelessWidget {
  const AppFooter({super.key});

  @override
  Widget build(BuildContext context) {
      return Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: Colors.grey.shade600,
                ),
                SizedBox(width: 8),
                Text(
                  'Versión 3.0.0',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              '© 2025 Chocolatería Entrelagos',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }
}