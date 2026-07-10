import 'dart:async';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
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
  
  // Timer state
  Timer? _timer;
  Duration _elapsed = Duration.zero;
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
    }
  }

  void _initGame() {
    debugPrint('[GameScreen] Initializing game for Level ${_currentLevel.id} (Difficulty: ${_currentLevel.difficulty}, Grid: ${_currentLevel.gridSize}x${_currentLevel.gridSize})');
    
    SharedPreferences.getInstance().then((prefs) {
      prefs.setInt('last_played_level_id', _currentLevel.id);
    });

    final solution = LevelData.getSolutionForLevel(_currentLevel);
    gameState = GameState(level: _currentLevel, solutionPath: solution);
    
    zipGame = ZipGame(
      gameState: gameState,
      onLevelComplete: _handleLevelComplete,
    );

    _elapsed = Duration.zero;
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _isTimerRunning = true;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _isTimerRunning) {
        setState(() {
          _elapsed += const Duration(seconds: 1);
        });
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
    gameState.dispose();
    super.dispose();
  }

  Future<void> _saveProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final completed = prefs.getStringList('completed_zips') ?? [];
    
    final levelPrefix = "${_currentLevel.id}:";
    int existingIndex = -1;
    Duration bestDuration = _elapsed;
    
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
    debugPrint('[GameScreen] Level ${_currentLevel.id} completed in ${_elapsed.inSeconds} seconds!');
    _stopTimer();
    
    // Increment and save streak
    _streak += 1;
    SharedPreferences.getInstance().then((prefs) {
      prefs.setInt('zip_streak', _streak);
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
            completionTime: _elapsed,
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
    debugPrint('[GameScreen] Resetting level ${_currentLevel.id}...');
    setState(() {
      gameState.reset();
      _elapsed = Duration.zero;
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
                          'LinkedIn Zip Game v1.1.0',
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

  void _showHelp() {
    AudioManager.playClick();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rules'),
        content: const Text(
          '1. Connect the checkpoints in numerical order (1 -> 2 -> 3 ...).\n\n'
          '2. The completed path must visit EVERY cell in the grid exactly once.\n\n'
          '3. You cannot cross your own path or go through thick black wall lines.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              AudioManager.playClick();
              Navigator.pop(context);
            },
            child: const Text('Got it'),
          ),
        ],
      ),
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
        child: Column(
          children: [
            // Header panel
            LinkedInHeader(
              elapsed: _elapsed,
              streak: _streak,
              levelId: _currentLevel.id,
              themeColor: _currentLevel.themeColor,
              onReset: _resetGame,
              onShowLevels: _openLevelsPage,
              onHelp: _showHelp,
              onSettings: _showSettings,
            ),
            const Divider(height: 1, color: Color(0xFFE0E0E0)),
            
            // Grid gameplay canvas
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: GameWidget(
                    game: zipGame,
                  ),
                ),
              ),
            ),
            
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
    );
  }
}
