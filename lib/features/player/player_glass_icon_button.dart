import 'package:flutter/material.dart';
import 'package:tone_player/app/tone_glass.dart';

class PlayerGlassIconButton extends StatelessWidget {
  const PlayerGlassIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        padding: EdgeInsets.zero,
        minimumSize: const Size(42, 42),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: ToneGlass(
        borderRadius: 99,
        tint: Colors.white.withValues(alpha: 0.14),
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, size: 22, color: Colors.white),
        ),
      ),
    );
  }
}
