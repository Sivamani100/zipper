import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/level_data.dart';
import '../utils/audio_manager.dart';

// Helper to darken a color for the 3D bezel shadow
Color _darkenColor(Color color, [double amount = 0.15]) {
  final hsl = HSLColor.fromColor(color);
  final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
  return hslDark.toColor();
}

class ChapterData {
  final int chapterNumber;
  final String title;
  final String difficulty;
  final int startLevel;
  final int endLevel;
  final Color themeColor;
  
  const ChapterData({
    required this.chapterNumber,
    required this.title,
    required this.difficulty,
    required this.startLevel,
    required this.endLevel,
    required this.themeColor,
  });
}

class MapItem {
  final int? levelId;
  final ChapterData? chapter;
  
  MapItem({this.levelId, this.chapter});
}

class LevelSelectorScreen extends StatefulWidget {
  final int currentLevelId;
  
  const LevelSelectorScreen({super.key, required this.currentLevelId});

  @override
  State<LevelSelectorScreen> createState() => _LevelSelectorScreenState();
}

class _LevelSelectorScreenState extends State<LevelSelectorScreen> {
  Map<int, String> _completedLevels = {}; // levelId -> bestTime
  bool _isMapView = true;
  late ScrollController _scrollController;
  final List<MapItem> _mapItems = [];

  final List<ChapterData> chapters = const [
    ChapterData(
      chapterNumber: 1,
      title: 'The Ascent',
      difficulty: 'Hard (6x6 Grid)',
      startLevel: 1,
      endLevel: 80,
      themeColor: Color(0xFFE52521), // Red
    ),
    ChapterData(
      chapterNumber: 2,
      title: 'The Core',
      difficulty: 'Harder (7x7 Grid)',
      startLevel: 81,
      endLevel: 200,
      themeColor: Color(0xFFF39200), // Orange
    ),
    ChapterData(
      chapterNumber: 3,
      title: 'The Peak',
      difficulty: 'Hardest (8x8 Grid)',
      startLevel: 201,
      endLevel: 320,
      themeColor: Color(0xFF43B02A), // Green
    ),
    ChapterData(
      chapterNumber: 4,
      title: 'The Summit (Grandmaster)',
      difficulty: 'Grandmaster (9x9 Grid)',
      startLevel: 321,
      endLevel: 400,
      themeColor: Color(0xFF7F44AB), // Purple
    ),
  ];

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _buildMapItems();
    _loadProgress();
    
    // Auto-scroll to center on the current active level
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToActiveLevel();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _buildMapItems() {
    _mapItems.clear();
    for (var chapter in chapters) {
      _mapItems.add(MapItem(chapter: chapter));
      for (int id = chapter.startLevel; id <= chapter.endLevel; id++) {
        _mapItems.add(MapItem(levelId: id));
      }
    }
  }

  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final completed = prefs.getStringList('completed_zips') ?? [];
    
    final Map<int, String> progress = {};
    for (var item in completed) {
      final firstColon = item.indexOf(':');
      if (firstColon != -1) {
        final idStr = item.substring(0, firstColon);
        final timeStr = item.substring(firstColon + 1);
        final id = int.tryParse(idStr);
        if (id != null) {
          progress[id] = timeStr;
        }
      }
    }
    
    if (mounted) {
      setState(() {
        _completedLevels = progress;
      });
    }
  }

  void _scrollToActiveLevel() {
    if (!_scrollController.hasClients || !_isMapView) return;

    double targetOffset = 0.0;
    bool found = false;
    
    for (var item in _mapItems) {
      if (item.levelId == widget.currentLevelId) {
        found = true;
        break;
      }
      if (item.chapter != null) {
        targetOffset += 160.0; // Chapter Header row height
      } else {
        targetOffset += 120.0; // Level Node row height
      }
    }

    if (found) {
      final screenHeight = MediaQuery.of(context).size.height;
      final centeredOffset = targetOffset + 60.0 - screenHeight / 2;
      
      final maxScroll = _scrollController.position.maxScrollExtent;
      final finalOffset = centeredOffset.clamp(0.0, maxScroll);
      
      _scrollController.jumpTo(finalOffset);
    }
  }

  int _calculateStars(String? timeStr) {
    if (timeStr == null) return 0;
    final parts = timeStr.split(':');
    if (parts.length != 2) return 1;
    final mins = int.tryParse(parts[0]) ?? 0;
    final secs = int.tryParse(parts[1]) ?? 0;
    final totalSeconds = mins * 60 + secs;
    if (totalSeconds <= 12) return 3;
    if (totalSeconds <= 25) return 2;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0.5,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF0A66C2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'Z',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Zipper Levels',
              style: GoogleFonts.openSans(
                color: Colors.black87,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar with stats summary & sliding toggle
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14.0),
              child: Column(
                children: [
                  _buildSlidingToggle(),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE0E0E0)),
            
            // Main content
            Expanded(
              child: _isMapView ? _buildMapView() : _buildGridView(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlidingToggle() {
    return Container(
      width: 260,
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F2EF),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            alignment: _isMapView ? Alignment.centerLeft : Alignment.centerRight,
            child: Container(
              width: 130,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
                border: Border.all(color: Colors.black.withValues(alpha: 0.04), width: 1.5),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    AudioManager.playClick();
                    setState(() {
                      _isMapView = true;
                    });
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _scrollToActiveLevel();
                    });
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.map_outlined,
                          size: 16,
                          color: _isMapView ? const Color(0xFF0A66C2) : Colors.black54,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Map Path',
                          style: GoogleFonts.openSans(
                            color: _isMapView ? const Color(0xFF0A66C2) : Colors.black54,
                            fontWeight: _isMapView ? FontWeight.bold : FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    AudioManager.playClick();
                    setState(() {
                      _isMapView = false;
                    });
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.grid_view_rounded,
                          size: 16,
                          color: !_isMapView ? const Color(0xFF0A66C2) : Colors.black54,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Grid View',
                          style: GoogleFonts.openSans(
                            color: !_isMapView ? const Color(0xFF0A66C2) : Colors.black54,
                            fontWeight: !_isMapView ? FontWeight.bold : FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMapView() {
    int furthestCompleted = 0;
    for (var id in _completedLevels.keys) {
      if (id > furthestCompleted) furthestCompleted = id;
    }
    final int unlockedLevelLimit = max(furthestCompleted + 1, widget.currentLevelId);

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(bottom: 60.0),
      itemCount: _mapItems.length,
      itemBuilder: (context, index) {
        final item = _mapItems[index];

        if (item.chapter != null) {
          final chapter = item.chapter!;
          return _buildChapterHeaderRow(chapter);
        } else {
          final levelId = item.levelId!;
          final isCompleted = _completedLevels.containsKey(levelId);
          final isCurrent = levelId == widget.currentLevelId;
          final isUnlocked = levelId <= unlockedLevelLimit || levelId == 1;
          final bestTime = _completedLevels[levelId];
          final stars = _calculateStars(bestTime);

          final chapter = chapters.firstWhere(
            (c) => levelId >= c.startLevel && levelId <= c.endLevel,
          );

          final double angle = levelId * 0.7;
          final double horizontalOffset = sin(angle) * 75;

          double prevOffset = 0.0;
          double connectionHeight = 120.0;
          
          if (levelId > 1) {
            final prevLevelId = levelId - 1;
            prevOffset = sin(prevLevelId * 0.7) * 75;
            
            final isStartOfChapter = chapters.any((c) => c.startLevel == levelId);
            if (isStartOfChapter) {
              connectionHeight = 280.0;
            }
          }

          return Container(
            height: 120.0,
            alignment: Alignment.center,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                if (levelId > 1)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: PathConnectionPainter(
                        prevOffset: prevOffset,
                        currOffset: horizontalOffset,
                        height: connectionHeight,
                        isUnlocked: isUnlocked,
                        color: chapter.themeColor,
                      ),
                    ),
                  ),

                BackgroundIllustration(
                  levelId: levelId,
                  isLeft: horizontalOffset > 0,
                  color: chapter.themeColor,
                ),

                Transform.translate(
                  offset: Offset(horizontalOffset, 0),
                  child: Center(
                    child: LevelNode(
                      levelId: levelId,
                      isUnlocked: isUnlocked,
                      isCompleted: isCompleted,
                      isCurrent: isCurrent,
                      themeColor: chapter.themeColor,
                      starsCount: stars,
                      onTap: () {
                        AudioManager.playClick();
                        final level = LevelData.levels[levelId - 1];
                        Navigator.pop(context, level);
                      },
                    ),
                  ),
                ),
              ],
            ),
          );
        }
      },
    );
  }

  Widget _buildChapterHeaderRow(ChapterData chapter) {
    return Container(
      height: 160.0,
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 15.0),
      alignment: Alignment.center,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              chapter.themeColor,
              _darkenColor(chapter.themeColor, 0.12),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: chapter.themeColor.withValues(alpha: 0.35),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.business_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CHAPTER ${chapter.chapterNumber}',
                    style: GoogleFonts.openSans(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    chapter.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.openSans(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    chapter.difficulty,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildChapterProgressBadge(chapter),
                const SizedBox(height: 6),
                const Text(
                  'COMPLETED',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChapterProgressBadge(ChapterData chapter) {
    int completedCount = 0;
    for (int id = chapter.startLevel; id <= chapter.endLevel; id++) {
      if (_completedLevels.containsKey(id)) {
        completedCount++;
      }
    }
    final totalLevels = chapter.endLevel - chapter.startLevel + 1;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$completedCount/$totalLevels',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildGridView() {
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: chapters.length,
      itemBuilder: (context, index) {
        final chapter = chapters[index];
        final chapterLevels = List.generate(
          chapter.endLevel - chapter.startLevel + 1,
          (i) => chapter.startLevel + i,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 16.0, bottom: 16.0),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [chapter.themeColor, _darkenColor(chapter.themeColor, 0.1)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: chapter.themeColor.withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Chapter ${chapter.chapterNumber}: ${chapter.title}',
                          style: GoogleFonts.openSans(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          chapter.difficulty,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildChapterProgressBadge(chapter),
                ],
              ),
            ),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 16,
                mainAxisSpacing: 28,
                childAspectRatio: 0.82,
              ),
              itemCount: chapterLevels.length,
              itemBuilder: (context, i) {
                final levelId = chapterLevels[i];
                final isCompleted = _completedLevels.containsKey(levelId);
                
                int furthestCompleted = 0;
                for (var id in _completedLevels.keys) {
                  if (id > furthestCompleted) furthestCompleted = id;
                }
                final isUnlocked = levelId <= max(furthestCompleted + 1, widget.currentLevelId) || levelId == 1;
                final isCurrent = levelId == widget.currentLevelId;
                final bestTime = _completedLevels[levelId];
                final stars = _calculateStars(bestTime);

                return LevelNode(
                  levelId: levelId,
                  isUnlocked: isUnlocked,
                  isCompleted: isCompleted,
                  isCurrent: isCurrent,
                  themeColor: chapter.themeColor,
                  starsCount: stars,
                  onTap: () {
                    AudioManager.playClick();
                    final level = LevelData.levels[levelId - 1];
                    Navigator.pop(context, level);
                  },
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class PulsingActiveRing extends StatefulWidget {
  final Color color;
  final double size;

  const PulsingActiveRing({super.key, required this.color, required this.size});

  @override
  State<PulsingActiveRing> createState() => _PulsingActiveRingState();
}

class _PulsingActiveRingState extends State<PulsingActiveRing> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.5).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );

    _opacityAnimation = Tween<double>(begin: 0.6, end: 0.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: widget.color, width: 3),
              ),
            ),
          ),
        );
      },
    );
  }
}

class LevelNode extends StatelessWidget {
  final int levelId;
  final bool isUnlocked;
  final bool isCompleted;
  final bool isCurrent;
  final Color themeColor;
  final int starsCount;
  final VoidCallback onTap;

  const LevelNode({
    super.key,
    required this.levelId,
    required this.isUnlocked,
    required this.isCompleted,
    required this.isCurrent,
    required this.themeColor,
    required this.starsCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const double nodeSize = 64.0;
    
    Color surfaceColor;
    Color shadowColor;
    Color contentColor;
    Widget content;

    if (!isUnlocked) {
      surfaceColor = Colors.grey.shade300;
      shadowColor = Colors.grey.shade400;
      contentColor = Colors.grey.shade500;
      content = Icon(Icons.lock_outline_rounded, color: contentColor, size: 24);
    } else if (isCompleted) {
      surfaceColor = themeColor;
      shadowColor = _darkenColor(themeColor, 0.16);
      contentColor = Colors.white;
      content = const Icon(Icons.check_rounded, color: Colors.white, size: 28);
    } else if (isCurrent) {
      surfaceColor = Colors.white;
      shadowColor = themeColor.withValues(alpha: 0.4);
      contentColor = themeColor;
      content = Icon(Icons.play_arrow_rounded, color: themeColor, size: 32);
    } else {
      surfaceColor = Colors.white;
      shadowColor = Colors.grey.shade300;
      contentColor = themeColor;
      content = Text(
        '$levelId',
        style: GoogleFonts.openSans(
          color: contentColor,
          fontSize: 20,
          fontWeight: FontWeight.w900,
        ),
      );
    }

    return GestureDetector(
      onTap: isUnlocked ? onTap : null,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          if (isCurrent)
            PulsingActiveRing(color: themeColor, size: nodeSize),
          Container(
            width: nodeSize,
            height: nodeSize,
            margin: const EdgeInsets.only(top: 6),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black12,
            ),
          ),
          Container(
            width: nodeSize,
            height: nodeSize,
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: shadowColor,
            ),
          ),
          Container(
            width: nodeSize,
            height: nodeSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: surfaceColor,
              border: Border.all(
                color: isCurrent ? themeColor : Colors.black.withValues(alpha: 0.12),
                width: isCurrent ? 3.0 : 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: content,
          ),
          if (isCompleted && starsCount > 0)
            Positioned(
              bottom: -20,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (index) {
                  final hasStar = index < starsCount;
                  return Icon(
                    Icons.star_rounded,
                    color: hasStar ? Colors.amber : Colors.grey.shade300,
                    size: 14,
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }
}

class BackgroundIllustration extends StatelessWidget {
  final int levelId;
  final bool isLeft;
  final Color color;

  const BackgroundIllustration({
    super.key,
    required this.levelId,
    required this.isLeft,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    IconData icon;
    String label;
    if (levelId <= 10) {
      final icons = [Icons.coffee_outlined, Icons.edit_note_outlined, Icons.badge_outlined, Icons.lightbulb_outline];
      icon = icons[levelId % icons.length];
      label = ['Coffee Break', 'Notes', 'ID Badge', 'Idea'][levelId % 4];
    } else if (levelId <= 30) {
      final icons = [Icons.laptop_chromebook, Icons.keyboard_alt_outlined, Icons.question_answer_outlined, Icons.attach_file_sharp];
      icon = icons[levelId % icons.length];
      label = ['Workstation', 'Keyboard', 'Meeting Sync', 'File Clip'][levelId % 4];
    } else if (levelId <= 80) {
      final icons = [Icons.business_center_outlined, Icons.calendar_month_outlined, Icons.campaign_outlined, Icons.trending_up];
      icon = icons[levelId % icons.length];
      label = ['Briefcase', 'Schedule', 'Broadcasting', 'Growth'][levelId % 4];
    } else if (levelId <= 150) {
      final icons = [Icons.co_present_outlined, Icons.pie_chart_outline, Icons.domain, Icons.public];
      icon = icons[levelId % icons.length];
      label = ['Pitch Deck', 'Analytics', 'Headquarters', 'Global'][levelId % 4];
    } else {
      final icons = [Icons.weekend_outlined, Icons.emoji_events_outlined, Icons.monetization_on_outlined, Icons.workspace_premium_outlined];
      icon = icons[levelId % icons.length];
      label = ['CEO Executive', 'Trophy', 'Revenue', 'Premium Badge'][levelId % 4];
    }

    return Transform.translate(
      offset: Offset(isLeft ? -85 : 85, 0),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
                border: Border.all(color: color.withValues(alpha: 0.15), width: 1.5),
              ),
              child: Icon(icon, color: color.withValues(alpha: 0.5), size: 20),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.bold,
                color: color.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PathConnectionPainter extends CustomPainter {
  final double prevOffset;
  final double currOffset;
  final double height;
  final bool isUnlocked;
  final Color color;

  PathConnectionPainter({
    required this.prevOffset,
    required this.currOffset,
    required this.height,
    required this.isUnlocked,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isUnlocked ? color.withValues(alpha: 0.8) : Colors.grey.shade300
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final startX = size.width / 2 + prevOffset;
    final startY = -height + 60.0;
    final endX = size.width / 2 + currOffset;
    final endY = 60.0;

    path.moveTo(startX, startY);
    path.cubicTo(
      startX,
      (startY + endY) / 2,
      endX,
      (startY + endY) / 2,
      endX,
      endY,
    );

    if (!isUnlocked) {
      final dashPath = Path();
      double distance = 0.0;
      final pathMetrics = path.computeMetrics();
      for (final metric in pathMetrics) {
        while (distance < metric.length) {
          dashPath.addPath(
            metric.extractPath(distance, distance + 4),
            Offset.zero,
          );
          distance += 10;
        }
      }
      canvas.drawPath(dashPath, paint..strokeWidth = 5);
    } else {
      final shadowPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.04)
        ..strokeWidth = 8
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      canvas.save();
      canvas.translate(0, 4);
      canvas.drawPath(path, shadowPaint);
      canvas.restore();

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
