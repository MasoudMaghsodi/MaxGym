import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

class CustomTextField extends StatelessWidget {
  final String label;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final bool obscureText;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;
  final String? Function(String?)? validator;

  const CustomTextField({
    super.key,
    required this.label,
    this.controller,
    this.keyboardType,
    this.obscureText = false,
    this.onTap,
    this.onChanged,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      onTap: onTap,
      onChanged: onChanged,
      validator: validator,
      decoration: InputDecoration(
        labelText: l10n != null ? l10n.translate(label) : label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Theme.of(context).inputDecorationTheme.fillColor,
      ),
    );
  }
}
