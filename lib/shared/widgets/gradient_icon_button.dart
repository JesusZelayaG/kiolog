import 'package:flutter/material.dart';

const _navGradient = LinearGradient(
  colors: [Color(0xFF0A8F53), Color(0xFF4CBF4A), Color(0xFF9ACD32)],
  stops: [0.0, 0.5, 1.0],
);

class GradientIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const GradientIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: _navGradient,
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}
