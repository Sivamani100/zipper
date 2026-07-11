import 'dart:math';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../models/level_model.dart';
import '../services/ad_manager.dart';

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
  String _caption = '';
  bool _showingAd = false; // Prevents double-tapping during ad display

  @override
  void initState() {
    super.initState();

    // Determine star rating based on completion time and pick a randomized caption
    final seconds = widget.completionTime.inSeconds;
    if (seconds <= 12) {
      _starsCount = 3;
      final fastCaptions = [
        'Smarter than\n99% of CEOs',
        'Unstoppable!\nPure genius at work',
        'Mind-blowing speed!\nAre you a machine?',
        'Lightning fast!\nAbsolute masterclass',
        'Record-breaking time!\nLegendary!',
      ];
      _caption = fastCaptions[_rand.nextInt(fastCaptions.length)];
    } else if (seconds <= 25) {
      _starsCount = 2;
      final mediumCaptions = [
        'Solid strategy!\nKeep it up!',
        'Excellent pathfinding!\nWell done!',
        'You\'re in the zone!\nSmooth finish!',
        'Great logic!\nAlmost record speed!',
        'Superb puzzle solving!\nOnto the next!',
      ];
      _caption = mediumCaptions[_rand.nextInt(mediumCaptions.length)];
    } else {
      _starsCount = 1;
      final slowCaptions = [
        'CEO took a\ncoffee break...',
        'Steady wins the race!\nGood focus!',
        'Took your time,\nbut found the way!',
        'Persistence paid off!\nNice work!',
        'Patience of a leader!\nSolved!',
      ];
      _caption = slowCaptions[_rand.nextInt(slowCaptions.length)];
    }

    // Confetti animation loop — no addListener/setState; AnimatedBuilder in build() drives it
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

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
      for (int i = 0; i < 40; i++) {  // Reduced from 70 — keeps it smooth on mid-range devices
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

  void _updateConfetti(Size size) {
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
    // No setState here — AnimatedBuilder drives the repaint efficiently
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

  String _getCaptionText() => _caption;

  /// Shows rewarded ad then calls [action]. If ad not ready, calls [action] directly.
  void _runWithRewardedAd(VoidCallback action) {
    if (_showingAd) return;
    setState(() => _showingAd = true);

    AdManager.showRewardedAd(
      onRewarded: () {
        // User watched the full ad — you can give a bonus here if desired
      },
      onAdDismissed: () {
        if (mounted) {
          setState(() => _showingAd = false);
          action();
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayTime = _formatDuration(widget.completionTime);
    final themeColor = widget.level.themeColor;

    return Scaffold(
      backgroundColor: themeColor,
      body: Stack(
        children: [
          // Confetti background — only this canvas repaints on every frame, not the whole tree
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _confettiController,
              builder: (context, _) {
                final size = MediaQuery.of(context).size;
                _updateConfetti(size);
                return CustomPaint(
                  painter: ConfettiPainter(particles: _particles),
                );
              },
            ),
          ),
          
          // Pinned Top Bar
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
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
            ),
          ),

          // Centered content + buttons flow
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(top: 64.0), // Space for top bar
              child: Center(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
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
                                    size: index == 1 ? 56 : 42,
                                  ),
                                );
                              },
                            );
                          }),
                        ),
                        
                        const SizedBox(height: 6),
                        
                        // Completion Time Title
                        Text(
                          displayTime,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 48,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Zip Level #${widget.level.id} | Today\'s avg: 00:25',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        
                        const SizedBox(height: 8),
                        
                        // Streak Counter Badge (No shadow effect)
                        if (widget.streak > 0) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade800.withOpacity(0.85),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.local_fire_department, color: Colors.yellowAccent, size: 18),
                                const SizedBox(width: 4),
                                Text(
                                  '${widget.streak} Level Streak!',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        
                        // Smarter Card (Lottie Animation + Caption)
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final screenHeight = MediaQuery.of(context).size.height;
                            final lottieHeight = (screenHeight * 0.28).clamp(160.0, 240.0);

                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Always show the Lottie trophy celebration animation
                                SizedBox(
                                  height: lottieHeight,
                                  width: lottieHeight,
                                  child: Lottie.network(
                                    'https://lottie.host/23879694-4c92-49d5-abfd-8686fcdbbf1f/5dPwTjdbe9.json',
                                    height: lottieHeight,
                                    width: lottieHeight,
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, error, stackTrace) {
                                      // Fallback icon if no internet connection
                                      return const Center(
                                        child: Icon(
                                          Icons.emoji_events_rounded,
                                          size: 100,
                                          color: Colors.amber,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                                  child: Text(
                                    _getCaptionText(),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      height: 1.2,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }
                        ),

                        // Controlled spacing between caption text and buttons
                        const SizedBox(height: 28),

                        // Action Buttons Control panel
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Share Button (Top, normal filled white button)
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
                                foregroundColor: themeColor,
                                backgroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
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
                            const SizedBox(height: 12),
                            
                            // Next Level / Play Again — shows rewarded ad first, then proceeds
                            ElevatedButton(
                              onPressed: _showingAd
                                  ? null // Disabled while ad is showing
                                  : () => _runWithRewardedAd(
                                        widget.onNextLevel ?? widget.onRestart,
                                      ),
                              style: ElevatedButton.styleFrom(
                                foregroundColor: Colors.white,
                                backgroundColor: _showingAd
                                    ? Colors.grey.shade600
                                    : Colors.black,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                elevation: 0,
                              ),
                              child: _showingAd
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      widget.onNextLevel != null
                                          ? 'Next Level'
                                          : 'Play Again',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
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
