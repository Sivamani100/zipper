import 'package:flutter/material.dart';

class ControlPanel extends StatelessWidget {
  final VoidCallback? onUndo;
  final VoidCallback? onHint;
  final bool isUndoEnabled;
  final int hintCooldownRemaining;

  const ControlPanel({
    super.key,
    required this.onUndo,
    required this.onHint,
    required this.isUndoEnabled,
    this.hintCooldownRemaining = 0,
  });

  @override
  Widget build(BuildContext context) {
    final bool isOnCooldown = hintCooldownRemaining > 0;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: isUndoEnabled ? onUndo : null,
              style: ElevatedButton.styleFrom(
                foregroundColor: isUndoEnabled ? Colors.black87 : Colors.black38,
                backgroundColor: isUndoEnabled ? Colors.white : Colors.black12,
                disabledForegroundColor: Colors.black26,
                disabledBackgroundColor: Colors.black12,
                elevation: 0,
                side: BorderSide(
                  color: isUndoEnabled ? Colors.black54 : Colors.transparent,
                  width: 1.2,
                ),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: const Text(
                'Undo',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton(
              onPressed: onHint,
              style: OutlinedButton.styleFrom(
                foregroundColor: isOnCooldown ? Colors.black38 : Colors.black87,
                backgroundColor: isOnCooldown ? Colors.black12 : Colors.transparent,
                side: BorderSide(
                  color: isOnCooldown ? Colors.transparent : Colors.black54,
                  width: 1.2,
                ),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: Text(
                isOnCooldown ? 'Hint (${hintCooldownRemaining}s)' : 'Hint',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HowToPlayCard extends StatefulWidget {
  const HowToPlayCard({super.key});

  @override
  State<HowToPlayCard> createState() => _HowToPlayCardState();
}

class _HowToPlayCardState extends State<HowToPlayCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFF8F9FA),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFFE9ECEF), width: 1.0),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        children: [
          ListTile(
            title: const Text(
              'How to play',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.black87,
              ),
            ),
            trailing: Icon(
              _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              color: Colors.black54,
            ),
            onTap: () {
              setState(() {
                _expanded = !_expanded;
              });
            },
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  // Rule 1: Connect dots in order
                  Expanded(
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildNumberedCircle('1'),
                            const SizedBox(width: 4),
                            _buildConnectorLine(),
                            const SizedBox(width: 4),
                            _buildNumberedCircle('2'),
                            const SizedBox(width: 4),
                            _buildConnectorLine(),
                            const SizedBox(width: 4),
                            _buildNumberedCircle('3'),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Connect the\ndots in order',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Rule 2: Fill every cell
                  Expanded(
                    child: Column(
                      children: [
                        Container(
                          width: 60,
                          height: 40,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.black26),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: GridView.builder(
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              childAspectRatio: 1.5,
                            ),
                            itemCount: 6,
                            itemBuilder: (context, index) {
                              final isVisited = index == 0 || index == 1 || index == 2 || index == 3 || index == 4 || index == 5;
                              return Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.black12, width: 0.5),
                                  color: isVisited ? const Color(0xFFE6F4EA) : null,
                                ),
                                child: isVisited && index == 0
                                    ? const Center(
                                        child: Icon(Icons.check, size: 8, color: Colors.green))
                                    : null,
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Fill every cell',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNumberedCircle(String text) {
    return Container(
      width: 20,
      height: 20,
      decoration: const BoxDecoration(
        color: Colors.black,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildConnectorLine() {
    return Container(
      width: 12,
      height: 3,
      decoration: BoxDecoration(
        color: const Color(0xFF008751), // Green connector line
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
