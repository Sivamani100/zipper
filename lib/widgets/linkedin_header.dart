import 'package:flutter/material.dart';

class LinkedInHeader extends StatelessWidget {
  final Duration elapsed;
  final int streak;
  final int levelId;
  final Color themeColor;
  final VoidCallback onReset;
  final VoidCallback onShowLevels;
  final VoidCallback onHelp;
  final VoidCallback onSettings;

  const LinkedInHeader({
    super.key,
    required this.elapsed,
    required this.streak,
    required this.levelId,
    required this.themeColor,
    required this.onReset,
    required this.onShowLevels,
    required this.onHelp,
    required this.onSettings,
  });

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return "$minutes:${twoDigits(seconds)}";
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1: Levels Icon, Level Title, Icons
          SizedBox(
            height: 48,
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: const Icon(Icons.grid_view, color: Colors.black87),
                    tooltip: 'Levels',
                    onPressed: onShowLevels,
                  ),
                ),
                Align(
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Level ',
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '$levelId',
                        style: TextStyle(
                          color: themeColor,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.help_outline, color: Colors.black87),
                        onPressed: onHelp,
                      ),
                      IconButton(
                        icon: const Icon(Icons.settings_outlined, color: Colors.black87),
                        onPressed: onSettings,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Row 2: Timer and Reset
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.access_time, size: 18, color: Colors.black87),
                  const SizedBox(width: 6),
                  Text(
                    _formatDuration(elapsed),
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (streak > 0) ...[
                    const SizedBox(width: 16),
                    const Icon(Icons.local_fire_department, size: 20, color: Colors.orange),
                    const SizedBox(width: 4),
                    Text(
                      '$streak Streak',
                      style: const TextStyle(
                        color: Colors.orange,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),
              OutlinedButton(
                onPressed: onReset,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.black87,
                  side: const BorderSide(color: Colors.black54, width: 1.2),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text(
                  'Reset',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
