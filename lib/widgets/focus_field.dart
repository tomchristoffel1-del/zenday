import 'package:flutter/material.dart';
import '../theme.dart';

/// Das Tages-Statement: ein einziges, großzügiges Textfeld ohne Rahmen,
/// ohne Label-Lärm – nur ein leiser Platzhalter.
class FocusField extends StatelessWidget {
  final TextEditingController controller;
  final ZenColors colors;
  final ValueChanged<String> onChanged;

  const FocusField({
    super.key,
    required this.controller,
    required this.colors,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      maxLines: null,
      textInputAction: TextInputAction.done,
      style: TextStyle(
        fontSize: 26,
        height: 1.3,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
        color: colors.textPrimary,
      ),
      cursorColor: colors.textSecondary,
      decoration: InputDecoration(
        border: InputBorder.none,
        isCollapsed: true,
        hintText: 'Was ist das Wichtigste heute?',
        hintStyle: TextStyle(
          fontSize: 26,
          height: 1.3,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
          color: colors.textTertiary,
        ),
      ),
    );
  }
}
