import 'dart:async';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/audio_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../game/zip_game.dart';
import '../models/game_state.dart';
import '../models/level_model.dart';
import '../models/level_data.dart';
import '../widgets/control_panel.dart';
import '../widgets/linkedin_header.dart';
import 'victory_screen.dart';
import 'level_selector_screen.dart';
import '../services/supabase_service.dart';
import 'supabase_config_screen.dart';
import 'auth_screen.dart';
import 'multiplayer_lobby_screen.dart';
import 'developer_profile_screen.dart';
import '../services/ad_manager.dart';


class GameScreen extends StatefulWidget {
  final Level level;
  final VoidCallback? onBackToMenu;

  const GameScreen({
    super.key,
    required this.level,
    this.onBackToMenu,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late GameState gameState;
  late ZipGame zipGame;
  
  // Timer state — using ValueNotifier so only the timer Text rebuilds each second
  Timer? _timer;
  final ValueNotifier<Duration> _elapsedNotifier = ValueNotifier(Duration.zero);
  bool _isTimerRunning = false;

  // Hint cooldown state
  int _hintUsageCount = 0;
  int _hintCooldownRemaining = 0;
  Timer? _cooldownTimer;

  // Level progress cache
  Map<int, String> _completedLevels = {};
  
  // Current active level state
  late Level _currentLevel;
  int _streak = 0;

  @override
  void initState() {
    super.initState();
    _currentLevel = widget.level;
    _initGame();
    _loadProgress();
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
        if (id != null) progress[id] = timeStr;
      }
    }
    final streak = prefs.getInt('zip_streak') ?? 0;
    final lastLevelId = prefs.getInt('last_played_level_id');
    if (mounted) {
      setState(() {
        _completedLevels = progress;
        _streak = streak;
        
        // Auto-resume to the last played level if we just launched the default Level 1
        if (lastLevelId != null && lastLevelId != _currentLevel.id && widget.level.id == 1) {
          _currentLevel = LevelData.levels.firstWhere(
            (l) => l.id == lastLevelId,
            orElse: () => LevelData.levels.first,
          );
          _initGame();
        }
      });
    }
  }

  void _openLevelsPage() async {
    AudioManager.playClick();
    _loadProgress();
    final selectedLevel = await Navigator.push<Level>(
      context,
      MaterialPageRoute(
        builder: (context) => LevelSelectorScreen(currentLevelId: _currentLevel.id),
      ),
    );
    if (selectedLevel != null) {
      setState(() {
        _currentLevel = selectedLevel;
        _initGame();
      });
      SharedPreferences.getInstance().then((prefs) {
        prefs.setInt('last_played_level_id', selectedLevel.id);
      });
    }
  }

  void _initGame() {
    final solution = LevelData.getSolutionForLevel(_currentLevel);
    gameState = GameState(level: _currentLevel, solutionPath: solution);
    
    zipGame = ZipGame(
      gameState: gameState,
      onLevelComplete: _handleLevelComplete,
    );

    _elapsedNotifier.value = Duration.zero;
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _isTimerRunning = true;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isTimerRunning) {
        _elapsedNotifier.value += const Duration(seconds: 1);
      }
    });
  }

  void _stopTimer() {
    _isTimerRunning = false;
    _timer?.cancel();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _cooldownTimer?.cancel();
    _elapsedNotifier.dispose();
    gameState.dispose();
    super.dispose();
  }

  Future<void> _saveProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final completed = prefs.getStringList('completed_zips') ?? [];
    
    final levelPrefix = "${_currentLevel.id}:";
    int existingIndex = -1;
    Duration bestDuration = _elapsedNotifier.value;
    
    for (int i = 0; i < completed.length; i++) {
      if (completed[i].startsWith(levelPrefix)) {
        existingIndex = i;
        final timeStr = completed[i].substring(levelPrefix.length);
        final parts = timeStr.split(':');
        if (parts.length == 2) {
          final m = int.tryParse(parts[0]) ?? 0;
          final s = int.tryParse(parts[1]) ?? 0;
          final existingDuration = Duration(minutes: m, seconds: s);
          if (existingDuration < bestDuration) {
            bestDuration = existingDuration;
          }
        }
        break;
      }
    }
    
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final formattedTime = "${bestDuration.inMinutes}:${twoDigits(bestDuration.inSeconds.remainder(60))}";
    final entry = "${_currentLevel.id}:$formattedTime";
    
    if (existingIndex != -1) {
      completed[existingIndex] = entry;
    } else {
      completed.add(entry);
    }
    
    await prefs.setStringList('completed_zips', completed);
  }

  void _handleLevelComplete() {
    AudioManager.playSuccess();
    _stopTimer();
    
    // Increment and save streak
    _streak += 1;
    final nextLevelId = _currentLevel.id + 1;
    SharedPreferences.getInstance().then((prefs) {
      prefs.setInt('zip_streak', _streak);
      if (nextLevelId <= LevelData.levels.length) {
        prefs.setInt('last_played_level_id', nextLevelId);
      } else {
        prefs.setInt('last_played_level_id', _currentLevel.id);
      }
    });

    _saveProgress();
    
    // Smooth transition to Victory Screen
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => VictoryScreen(
            level: _currentLevel,
            completionTime: _elapsedNotifier.value,
            streak: _streak,
            onRestart: () {
              Navigator.pop(context); // Close victory screen
              setState(() {
                _initGame();
              });
            },
            onNextLevel: _currentLevel.id < LevelData.levels.length
                ? () {
                    Navigator.pop(context); // Close victory screen
                    final nextLvl = LevelData.levels.firstWhere((l) => l.id == _currentLevel.id + 1);
                    setState(() {
                      _currentLevel = nextLvl;
                      _initGame();
                    });
                    SharedPreferences.getInstance().then((prefs) {
                      prefs.setInt('last_played_level_id', nextLvl.id);
                    });
                  }
                : null,
            onBackToMenu: () {
              Navigator.pop(context); // Close victory screen
              widget.onBackToMenu?.call();
            },
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    });
  }

  void _resetGame() {
    AudioManager.playClick();
    setState(() {
      gameState.reset();
      _elapsedNotifier.value = Duration.zero;
      _hintUsageCount = 0;
      _hintCooldownRemaining = 0;
      _cooldownTimer?.cancel();
      _startTimer();
    });
  }

  void _openMultiplayerLobby() async {
    final configured = await SupabaseService.isConfigured();
    if (!configured) {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SupabaseConfigScreen(
            onConfigured: () {
              Navigator.pop(context);
              _openMultiplayerLobby();
            },
          ),
        ),
      );
      return;
    }

    await SupabaseService.initialize();

    if (!SupabaseService.hasSession) {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AuthScreen(
            onAuthenticated: () {
              Navigator.pop(context);
              _openMultiplayerLobby();
            },
            onClearConfig: () async {
              await SupabaseService.resetCredentials();
              if (mounted) Navigator.pop(context);
              _openMultiplayerLobby();
            },
          ),
        ),
      );
      return;
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MultiplayerLobbyScreen(
          onSignOut: () async {
            await SupabaseService.signOut();
            if (mounted) Navigator.pop(context);
            _openMultiplayerLobby();
          },
        ),
      ),
    );
  }

  void _showSettings() {
    AudioManager.playClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return FutureBuilder<SharedPreferences>(
              future: SharedPreferences.getInstance(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()));
                }
                final prefs = snapshot.data!;
                final soundEnabled = prefs.getBool('zip_sound_effects') ?? true;
                final hapticsEnabled = prefs.getBool('zip_haptics') ?? true;

                return Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Settings',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.black54),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        title: const Text('Sound Effects', style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: const Text('Play audio cues on steps and wins'),
                        value: soundEnabled,
                        activeColor: const Color(0xFF0A66C2),
                        onChanged: (val) async {
                          await prefs.setBool('zip_sound_effects', val);
                          setSheetState(() {});
                          AudioManager.playClick();
                        },
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        title: const Text('Haptic Feedback', style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: const Text('Vibrate on corridor zips and walls'),
                        value: hapticsEnabled,
                        activeColor: const Color(0xFF0A66C2),
                        onChanged: (val) async {
                          await prefs.setBool('zip_haptics', val);
                          setSheetState(() {});
                          AudioManager.playClick();
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.sports_esports_rounded, color: Color(0xFF0A66C2)),
                        title: const Text('Multiplayer Arena', style: TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: const Text('Play with friends, chat and call in real-time'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () {
                          Navigator.pop(context);
                          _openMultiplayerLobby();
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.person_rounded, color: Color(0xFF0A66C2)),
                        title: const Text('Developer', style: TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: const Text('Meet the founder and creator of Zipper'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const DeveloperProfileScreen(),
                            ),
                          );
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.privacy_tip_rounded, color: Color(0xFF0A66C2)),
                        title: const Text('Privacy Policy', style: TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: const Text('Read our data collection and privacy terms'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () {
                          Navigator.pop(context);
                          _showPrivacyPolicy();
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.description_rounded, color: Color(0xFF0A66C2)),
                        title: const Text('Terms of Service', style: TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: const Text('Read our user agreement and guidelines'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () {
                          Navigator.pop(context);
                          _showTermsOfService();
                        },
                      ),
                      const Divider(height: 1),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.refresh_rounded, color: Colors.red),
                        label: const Text(
                          'Reset Game Progress',
                          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () {
                          AudioManager.playClick();
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Reset Progress?'),
                              content: const Text(
                                'This will delete all completed levels, streak score, and return you to Level 1. This action cannot be undone.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    AudioManager.playClick();
                                    Navigator.pop(context);
                                  },
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () async {
                                    AudioManager.playClick();
                                    await prefs.remove('completed_zips');
                                    await prefs.remove('zip_streak');
                                    await prefs.remove('last_played_level_id');
                                    if (mounted) {
                                      setState(() {
                                        _currentLevel = LevelData.levels.first;
                                        _streak = 0;
                                        _completedLevels = {};
                                        _initGame();
                                      });
                                    }
                                    Navigator.pop(context);
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Game progress has been reset.'),
                                        backgroundColor: Colors.redAccent,
                                      ),
                                    );
                                  },
                                  child: const Text('Reset Everything', style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade50,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.red.shade200, width: 1),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: Text(
                          'Zipper v1.0.0',
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildHelpRow({required IconData icon, required String title, required String description}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF0A66C2).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: const Color(0xFF0A66C2), size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.openSans(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(fontSize: 13, color: Colors.black54, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showHelp() {
    AudioManager.playClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'How To Play',
                    style: GoogleFonts.openSans(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.black54),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildHelpRow(
                icon: Icons.onetwothree_rounded,
                title: 'Connect in Order',
                description: 'Drag lines to connect the checkpoints in numerical order (1 -> 2 -> 3 ...).',
              ),
              const Divider(height: 24),
              _buildHelpRow(
                icon: Icons.grid_on_rounded,
                title: 'Fill the Grid',
                description: 'The completed path must visit EVERY single cell in the grid exactly once.',
              ),
              const Divider(height: 24),
              _buildHelpRow(
                icon: Icons.do_not_disturb_on_total_silence_rounded,
                title: 'Do Not Cross',
                description: 'You cannot cross your own path or cross through the thick black wall lines.',
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  AudioManager.playClick();
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0A66C2),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  'Got it, let\'s play!',
                  style: GoogleFonts.openSans(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 15),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  void _showPrivacyPolicy() {
    AudioManager.playClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Privacy Policy',
                        style: GoogleFonts.openSans(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.black54),
                        onPressed: () {
                          Navigator.pop(context);
                          _showSettings(); // return to settings
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      children: [
                        Text(
                          'Last Updated: July 10, 2026\n\n'
                          'Welcome to Zipper! We are committed to protecting your privacy. This Privacy Policy explains how we collect, use, and share information when you play our game.\n\n'
                          '1. Information We Collect\n'
                          'We do not collect any personal identifier information. If you play in multiplayer mode, we request a temporary Guest Nickname which is stored solely to display on the multiplayer scoreboard and active match list. This information is deleted automatically after the room expires.\n\n'
                          '2. Supabase Integration\n'
                          'Multiplayer services are backed by Supabase. Room and message data are stored temporarily and cleared automatically using database triggers and cleanup procedures.\n\n'
                          '3. Third-Party Services\n'
                          'Our game integrates standard device capabilities for Haptics and Audio. We do not use trackers, analytics tools, or advertising networks that collect your device usage data.\n\n'
                          '4. Changes to This Policy\n'
                          'We may update our Privacy Policy from time to time. We will notify you of any changes by posting the new policy inside the app settings panel.\n\n'
                          'If you have any questions, feel free to contact us at support@zipper.com.',
                          style: GoogleFonts.openSans(fontSize: 14, color: Colors.black87, height: 1.5),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showTermsOfService() {
    AudioManager.playClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Terms of Service',
                        style: GoogleFonts.openSans(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.black54),
                        onPressed: () {
                          Navigator.pop(context);
                          _showSettings(); // return to settings
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      children: [
                        Text(
                          'Last Updated: July 10, 2026\n\n'
                          'By accessing or playing Zipper, you agree to comply with and be bound by these Terms of Service.\n\n'
                          '1. User License\n'
                          'We grant you a personal, non-transferable, non-exclusive license to use the Zipper application on your devices for personal entertainment purposes only.\n\n'
                          '2. Acceptable Conduct\n'
                          'You agree not to modify, reverse engineer, or exploit the game client, database, or connection protocols. You agree not to spam or send abusive/offensive texts in the Multiplayer Match Chat room.\n\n'
                          '3. Account Responsibility\n'
                          'Multiplayer accounts are created as Guest access tokens. You are responsible for maintaining your local config. Clearing app data or resetting progress is permanent and cannot be restored by host services.\n\n'
                          '4. Disclaimer of Warranties\n'
                          'Zipper is provided "as is" without warranty of any kind. We do not guarantee uninterrupted matchmaking operations or persistent leaderboard scores.\n\n'
                          'If you violate these terms, we reserve the right to suspend or block your access to multiplayer lobbies.',
                          style: GoogleFonts.openSans(fontSize: 14, color: Colors.black87, height: 1.5),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _handleHintTapped() {
    AudioManager.playClick();
    if (_hintCooldownRemaining > 0) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'You already used a hint! Wait $_hintCooldownRemaining seconds.',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    debugPrint('[GameScreen] Hint requested for Level ${_currentLevel.id}. Cooldown will be ${_hintUsageCount + 1}s.');
    setState(() {
      _hintUsageCount++;
      _hintCooldownRemaining = _hintUsageCount;
    });

    gameState.applyHint();

    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_hintCooldownRemaining > 0) {
            _hintCooldownRemaining--;
          } else {
            _cooldownTimer?.cancel();
          }
        });
      } else {
        timer.cancel();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10.0),
          child: Column(
            children: [
              // Header panel — only rebuilds when elapsed time changes
              ValueListenableBuilder<Duration>(
                valueListenable: _elapsedNotifier,
                builder: (context, elapsed, _) {
                  return LinkedInHeader(
                    elapsed: elapsed,
                    streak: _streak,
                    levelId: _currentLevel.id,
                    themeColor: _currentLevel.themeColor,
                    onReset: _resetGame,
                    onShowLevels: _openLevelsPage,
                    onHelp: _showHelp,
                    onSettings: _showSettings,
                  );
                },
              ),
              const Divider(height: 1, color: Color(0xFFE0E0E0)),

              // ── Top Banner Ad ──────────────────────────────────────────
              AdManager.buildBannerAd(),
              // ──────────────────────────────────────────────────────────
              
              // Grid gameplay canvas
              Expanded(
                child: Center(
                  child: GameWidget(
                    game: zipGame,
                  ),
                ),
              ),
              
              // ── Bottom Banner Ad (Placed directly above Undo/Hint control buttons) ──
              AdManager.buildBannerAd(),
              // ──────────────────────────────────────────────────────────

              // Bottom UI
              ListenableBuilder(
                listenable: gameState,
                builder: (context, _) {
                  return ControlPanel(
                    onUndo: () => gameState.undo(),
                    onHint: _handleHintTapped,
                    isUndoEnabled: gameState.undoHistory.isNotEmpty,
                    hintCooldownRemaining: _hintCooldownRemaining,
                  );
                },
              ),
              const HowToPlayCard(),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
