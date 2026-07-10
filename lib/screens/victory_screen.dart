import 'dart:math';
import 'package:flutter/material.dart';
import '../models/level_model.dart';

class VictoryScreen extends StatefulWidget {
  final Level level;
  final Duration completionTime;
  final int streak;
  final VoidCallback onRestart;
  final VoidCallback? onNextLevel;
  final VoidCallback onBackToMenu;

  const VictoryScreen({
    super.key,
    required this.level,
    required this.completionTime,
    required this.streak,
    required this.onRestart,
    required this.onNextLevel,
    required this.onBackToMenu,
  });

  @override
  State<VictoryScreen> createState() => _VictoryScreenState();
}

class _VictoryScreenState extends State<VictoryScreen> with TickerProviderStateMixin {
  late AnimationController _confettiController;
  late AnimationController _starsController;
  final List<ConfettiParticle> _particles = [];
  final Random _rand = Random();

  int _starsCount = 1;

  @override
  void initState() {
    super.initState();

    // Determine star rating based on completion time
    final seconds = widget.completionTime.inSeconds;
    if (seconds <= 12) {
      _starsCount = 3;
    } else if (seconds <= 25) {
      _starsCount = 2;
    } else {
      _starsCount = 1;
    }

    // Confetti animation loop
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..addListener(() {
        _updateConfetti();
      })..repeat();

    // Stars entrance animation
    _starsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // Delay start of stars animation for better transition
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _starsController.forward();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Initialize confetti particles once screen dimensions are available
    if (_particles.isEmpty) {
      final size = MediaQuery.of(context).size;
      for (int i = 0; i < 70; i++) {
        _particles.add(_generateParticle(size.width, size.height, isInitial: true));
      }
    }
  }

  ConfettiParticle _generateParticle(double screenWidth, double screenHeight, {bool isInitial = false}) {
    final colors = [
      Colors.redAccent,
      Colors.blueAccent,
      Colors.greenAccent,
      Colors.yellowAccent,
      Colors.orangeAccent,
      Colors.pinkAccent,
      Colors.purpleAccent,
    ];

    return ConfettiParticle(
      x: _rand.nextDouble() * screenWidth,
      y: isInitial ? (_rand.nextDouble() * -screenHeight) : -20,
      speed: 2.0 + _rand.nextDouble() * 4.0,
      angle: (_rand.nextDouble() * 0.5 - 0.25) + pi / 2, // falling down with minor sway
      rotationSpeed: _rand.nextDouble() * 0.2 - 0.1,
      rotation: _rand.nextDouble() * pi,
      color: colors[_rand.nextInt(colors.length)],
      width: 6.0 + _rand.nextDouble() * 8.0,
      height: 4.0 + _rand.nextDouble() * 6.0,
    );
  }

  void _updateConfetti() {
    if (!mounted) return;
    final size = MediaQuery.of(context).size;
    for (var p in _particles) {
      p.y += p.speed * sin(p.angle);
      p.x += p.speed * cos(p.angle);
      p.rotation += p.rotationSpeed;

      // Wrap or regenerate when out of screen bounds
      if (p.y > size.height || p.x < -20 || p.x > size.width + 20) {
        final newParticle = _generateParticle(size.width, size.height, isInitial: false);
        p.x = newParticle.x;
        p.y = newParticle.y;
        p.speed = newParticle.speed;
        p.angle = newParticle.angle;
        p.rotation = newParticle.rotation;
        p.rotationSpeed = newParticle.rotationSpeed;
        p.color = newParticle.color;
        p.width = newParticle.width;
        p.height = newParticle.height;
      }
    }
    setState(() {});
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _starsController.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return "$minutes:${twoDigits(seconds)}";
  }

  String _getCaptionText() {
    if (_starsCount == 3) {
      return 'Smarter than\n99% of CEOs';
    } else if (_starsCount == 2) {
      return 'Solid\nStrategy!';
    } else {
      return 'CEO took a\ncoffee break...';
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayTime = _formatDuration(widget.completionTime);
    final themeColor = widget.level.themeColor;

    return Scaffold(
      backgroundColor: themeColor,
      body: Stack(
        children: [
          // Confetti background CustomPaint
          Positioned.fill(
            child: CustomPaint(
              painter: ConfettiPainter(particles: _particles),
            ),
          ),
          
          SafeArea(
            child: Column(
              children: [
                // Top Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white, size: 28),
                        onPressed: widget.onBackToMenu,
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'zipper.com',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 48), // Spacer to balance cross icon
                    ],
                  ),
                ),
                
                const Spacer(flex: 1),
                
                // Stars Rating Animation
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (index) {
                    final isGolden = index < _starsCount;
                    final delayFraction = index * 0.25;

                    return AnimatedBuilder(
                      animation: _starsController,
                      builder: (context, child) {
                        final double t = (_starsController.value - delayFraction).clamp(0.0, 1.0);
                        final double scale = Curves.elasticOut.transform(t);

                        return Transform.scale(
                          scale: scale,
                          child: Icon(
                            isGolden ? Icons.star_rounded : Icons.star_outline_rounded,
                            color: isGolden ? Colors.amberAccent : Colors.white24,
                            size: index == 1 ? 72 : 54, // Middle star is larger
                          ),
                        );
                      },
                    );
                  }),
                ),
                
                const SizedBox(height: 16),
                
                // Completion Time Title
                Text(
                  displayTime,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 64,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Zip Level #${widget.level.id} | Today\'s avg: 00:25',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // Streak Counter Badge
                if (widget.streak > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade800.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.local_fire_department, color: Colors.yellowAccent, size: 20),
                        const SizedBox(width: 6),
                        Text(
                          '${widget.streak} Level Streak!',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                const Spacer(flex: 1),
                
                // Smarter Card
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 32.0),
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Square Cartoon Character Custom Paint
                      SizedBox(
                        height: 120,
                        width: 140,
                        child: CustomPaint(
                          painter: SquareCartoonPainter(starsCount: _starsCount),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _getCaptionText(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const Spacer(flex: 2),
                
                // Control panel
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Next Level / Play Again Button
                      ElevatedButton(
                        onPressed: widget.onNextLevel ?? widget.onRestart,
                        style: ElevatedButton.styleFrom(
                          foregroundColor: themeColor,
                          backgroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          widget.onNextLevel != null ? 'Next Level' : 'Play Again',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // Share Button
                      ElevatedButton(
                        onPressed: () {
                          // Share action (mocked)
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Stats copied to clipboard! Share with your network.'),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.white.withOpacity(0.25),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                            side: const BorderSide(color: Colors.white, width: 1.5),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Share',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ConfettiParticle {
  double x;
  double y;
  double speed;
  double angle;
  double rotation;
  double rotationSpeed;
  Color color;
  double width;
  double height;

  ConfettiParticle({
    required this.x,
    required this.y,
    required this.speed,
    required this.angle,
    required this.rotation,
    required this.rotationSpeed,
    required this.color,
    required this.width,
    required this.height,
  });
}

class ConfettiPainter extends CustomPainter {
  final List<ConfettiParticle> particles;

  ConfettiPainter({required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    for (var p in particles) {
      final paint = Paint()
        ..color = p.color
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(p.x, p.y);
      canvas.rotate(p.rotation);
      
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: p.width, height: p.height),
        paint,
      );
      
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class SquareCartoonPainter extends CustomPainter {
  final int starsCount;

  SquareCartoonPainter({required this.starsCount});

  @override
  void paint(Canvas canvas, Size size) {
    final double centerX = size.width / 2;
    final double centerY = size.height / 2;
    final Offset center = Offset(centerX, centerY - 5);

    // Paints
    final bodyPaint = Paint()
      ..color = const Color(0xFF0A66C2) // LinkedIn Blue for body
      ..style = PaintingStyle.fill;

    final blackStroke = Paint()
      ..color = Colors.black
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final blackFill = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    final brownFill = Paint()
      ..color = const Color(0xFF8D6E63)
      ..style = PaintingStyle.fill;

    final yellowFill = Paint()
      ..color = const Color(0xFFFFD54F)
      ..style = PaintingStyle.fill;

    final blueFill = Paint()
      ..color = const Color(0xFF29B6F6)
      ..style = PaintingStyle.fill;

    // 1. Draw Legs
    // Left Leg
    canvas.drawLine(Offset(centerX - 15, centerY + 30), Offset(centerX - 15, centerY + 45), blackStroke);
    canvas.drawCircle(Offset(centerX - 15, centerY + 45), 4, blackFill);
    // Right Leg
    canvas.drawLine(Offset(centerX + 15, centerY + 30), Offset(centerX + 15, centerY + 45), blackStroke);
    canvas.drawCircle(Offset(centerX + 15, centerY + 45), 4, blackFill);

    // 2. Draw Square Body (RRect)
    final Rect squareRect = Rect.fromCenter(center: center, width: 64, height: 64);
    canvas.drawRRect(RRect.fromRectAndRadius(squareRect, const Radius.circular(12)), bodyPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(squareRect, const Radius.circular(12)), blackStroke);

    // 3. Draw Arms and accessories based on performance
    if (starsCount == 3) {
      // Arms raised in victory
      canvas.drawLine(Offset(centerX - 32, centerY), Offset(centerX - 48, centerY - 24), blackStroke);
      canvas.drawCircle(Offset(centerX - 48, centerY - 24), 3, blackFill);
      canvas.drawLine(Offset(centerX + 32, centerY), Offset(centerX + 48, centerY - 24), blackStroke);
      canvas.drawCircle(Offset(centerX + 48, centerY - 24), 3, blackFill);

      // Gold crown on top of the head
      final crownPath = Path()
        ..moveTo(centerX - 15, centerY - 37)
        ..lineTo(centerX - 20, centerY - 47)
        ..lineTo(centerX - 8, centerY - 42)
        ..lineTo(centerX, centerY - 50)
        ..lineTo(centerX + 8, centerY - 42)
        ..lineTo(centerX + 20, centerY - 47)
        ..lineTo(centerX + 15, centerY - 37)
        ..close();
      canvas.drawPath(crownPath, yellowFill);
      canvas.drawPath(crownPath, blackStroke..strokeWidth = 2.0);
    } else if (starsCount == 2) {
      // Left arm waving, right arm holding a briefcase
      canvas.drawLine(Offset(centerX - 32, centerY + 5), Offset(centerX - 48, centerY - 10), blackStroke);
      canvas.drawCircle(Offset(centerX - 48, centerY - 10), 3, blackFill);

      canvas.drawLine(Offset(centerX + 32, centerY + 5), Offset(centerX + 42, centerY + 18), blackStroke);

      // Briefcase
      final briefcase = Rect.fromLTWH(centerX + 35, centerY + 10, 20, 16);
      canvas.drawRRect(RRect.fromRectAndRadius(briefcase, const Radius.circular(2)), brownFill);
      canvas.drawRRect(RRect.fromRectAndRadius(briefcase, const Radius.circular(2)), blackStroke..strokeWidth = 1.5);
      final handle = Path()
        ..moveTo(centerX + 40, centerY + 10)
        ..lineTo(centerX + 40, centerY + 7)
        ..lineTo(centerX + 50, centerY + 7)
        ..lineTo(centerX + 50, centerY + 10);
      canvas.drawPath(handle, blackStroke..strokeWidth = 1.5);
    } else {
      // Arms drooping downwards (sad/tired)
      canvas.drawLine(Offset(centerX - 32, centerY + 10), Offset(centerX - 44, centerY + 28), blackStroke);
      canvas.drawCircle(Offset(centerX - 44, centerY + 28), 3, blackFill);
      canvas.drawLine(Offset(centerX + 32, centerY + 10), Offset(centerX + 44, centerY + 28), blackStroke);
      canvas.drawCircle(Offset(centerX + 44, centerY + 28), 3, blackFill);

      // Sweat droplet on forehead
      final sweat = Path()
        ..moveTo(centerX + 22, centerY - 20)
        ..quadraticBezierTo(centerX + 26, centerY - 14, centerX + 22, centerY - 10)
        ..quadraticBezierTo(centerX + 18, centerY - 14, centerX + 22, centerY - 20);
      canvas.drawPath(sweat, blueFill);
      canvas.drawPath(sweat, blackStroke..strokeWidth = 1.0);
    }

    // 4. Face (Glasses and Eyes)
    final double leftEyeX = centerX - 12;
    final double rightEyeX = centerX + 12;
    final double eyeY = centerY - 5;
    final double radius = 11.0;

    if (starsCount == 1) {
      // Tilted glasses for tired state
      canvas.save();
      canvas.translate(centerX, eyeY);
      canvas.rotate(0.08); // Slight tilt

      final offsetLeft = Offset(-12, 0);
      final offsetRight = Offset(12, 0);

      // Draw glasses frames
      canvas.drawCircle(offsetLeft, radius, blackStroke);
      canvas.drawCircle(offsetRight, radius, blackStroke);
      // Bridge
      canvas.drawLine(Offset(-12 + radius, 0), Offset(12 - radius, 0), blackStroke);

      // Droopy tired eyes
      canvas.drawArc(
        Rect.fromCenter(center: offsetLeft, width: 8, height: 6),
        0,
        pi,
        false,
        blackStroke..strokeWidth = 2.0,
      );
      canvas.drawArc(
        Rect.fromCenter(center: offsetRight, width: 8, height: 6),
        0,
        pi,
        false,
        blackStroke..strokeWidth = 2.0,
      );

      canvas.restore();
    } else {
      // Happy glasses (Straight)
      canvas.drawCircle(Offset(leftEyeX, eyeY), radius, blackStroke);
      canvas.drawCircle(Offset(rightEyeX, eyeY), radius, blackStroke);
      canvas.drawLine(Offset(leftEyeX + radius, eyeY), Offset(rightEyeX - radius, eyeY), blackStroke);

      // Happy curved eyes (^ ^)
      canvas.drawArc(
        Rect.fromCenter(center: Offset(leftEyeX, eyeY + 1), width: 9, height: 7),
        pi,
        pi,
        false,
        blackStroke..strokeWidth = 2.0,
      );
      canvas.drawArc(
        Rect.fromCenter(center: Offset(rightEyeX, eyeY + 1), width: 9, height: 7),
        pi,
        pi,
        false,
        blackStroke..strokeWidth = 2.0,
      );
    }

    // 5. Mouth
    final Offset mouthCenter = Offset(centerX, centerY + 12);
    if (starsCount == 3) {
      // Big open laughing mouth
      final mouthRect = Rect.fromCenter(center: mouthCenter, width: 14, height: 12);
      canvas.drawArc(mouthRect, 0, pi, true, Paint()..color = const Color(0xFFE57373));
      canvas.drawArc(mouthRect, 0, pi, true, blackStroke..strokeWidth = 1.5);
      canvas.drawLine(Offset(centerX - 7, mouthCenter.dy), Offset(centerX + 7, mouthCenter.dy), blackStroke);
    } else if (starsCount == 2) {
      // Friendly smile
      canvas.drawArc(
        Rect.fromCenter(center: mouthCenter - const Offset(0, 3), width: 10, height: 8),
        0,
        pi,
        false,
        blackStroke..strokeWidth = 2.0,
      );
    } else {
      // Wavy/sad mouth
      final wavyMouth = Path()
        ..moveTo(centerX - 6, mouthCenter.dy - 1)
        ..quadraticBezierTo(centerX - 3, mouthCenter.dy + 2, centerX, mouthCenter.dy - 1)
        ..quadraticBezierTo(centerX + 3, mouthCenter.dy - 4, centerX + 6, mouthCenter.dy - 1);
      canvas.drawPath(wavyMouth, blackStroke..strokeWidth = 2.0);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
