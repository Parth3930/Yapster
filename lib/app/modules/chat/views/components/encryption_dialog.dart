import 'package:flutter/material.dart';

/// A beautiful dialog that explains the encryption features
/// Extracted from ChatDetailView to improve modularity
class EncryptionDialog extends StatelessWidget {
  const EncryptionDialog({super.key});

  /// Show the encryption dialog
  static void show(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const EncryptionDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey.shade900,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: Colors.blue.withOpacity(0.3), width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Lock icon at the top
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_outline,
                color: Colors.blue,
                size: 40,
              ),
            ),
            const SizedBox(height: 16),

            // Title
            const Text(
              'End-to-End Encryption',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // Divider
            Container(
              height: 1,
              width: 60,
              color: Colors.blue.withOpacity(0.3),
            ),
            const SizedBox(height: 16),

            // Content
            const Text(
              'Your messages are securely encrypted and can only be read by you and the recipient.',
              style: TextStyle(color: Colors.white, height: 1.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // Security features list
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  _EncryptionFeatureItem(
                    icon: Icons.enhanced_encryption,
                    text: 'Messages encrypted on your device',
                  ),
                  SizedBox(height: 8),
                  _EncryptionFeatureItem(
                    icon: Icons.visibility_off,
                    text: 'Not even Yapster can read your messages',
                  ),
                  SizedBox(height: 8),
                  _EncryptionFeatureItem(
                    icon: Icons.security,
                    text: 'Unique keys for each conversation',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Close button
            TextButton(
              style: TextButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Got it',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Helper widget for encryption feature items
class _EncryptionFeatureItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _EncryptionFeatureItem({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.blue, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ),
      ],
    );
  }
}
