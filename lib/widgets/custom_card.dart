import 'package:flutter/material.dart';

class CustomCard extends StatelessWidget {
  final Widget child;
  final String? title;

  const CustomCard({super.key, required this.child, this.title});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null)
              Text(
                title!,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            if (title != null) const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}
