import 'package:flutter/material.dart';
import 'package:signature/signature.dart';

class SignatureSection extends StatelessWidget {
  final String? signatureImageUrl;
  final SignatureController signatureController;
  final bool isReadOnly;
  final VoidCallback onClear;

  const SignatureSection({
    super.key,
    this.signatureImageUrl,
    required this.signatureController,
    required this.isReadOnly,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Signature du responsable du magasin', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (signatureImageUrl != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Image.network(
              signatureImageUrl!,
              height: 150,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return const Center(child: CircularProgressIndicator());
              },
            ),
          )
        else if (!isReadOnly)
          Container(
            decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(4)),
            child: Column(
              children: [
                Signature(controller: signatureController, height: 200, backgroundColor: Colors.white),
                Container(
                  decoration: BoxDecoration(color: Colors.grey.shade200),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.clear, color: Colors.red),
                        onPressed: onClear,
                        tooltip: 'Effacer la signature',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}