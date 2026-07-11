import 'dart:async';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../game/zip_game.dart';
import '../models/game_state.dart';
import '../models/level_data.dart';
import '../services/supabase_service.dart';
import '../utils/audio_manager.dart';
import '../widgets/control_panel.dart';
import '../services/ad_manager.dart';

class MultiplayerRoomScreen extends StatefulWidget {
  final String roomId;

  const MultiplayerRoomScreen({super.key, required this.roomId});

  @override
  State<MultiplayerRoomScreen> createState() => _MultiplayerRoomScreenState();
}



class _MultiplayerRoomScreenState extends State<MultiplayerRoomScreen> {
  final _messageController = TextEditingController();
  final _chatScrollController = ScrollController();
  
  Map<String, dynamic>? _roomData;
  StreamSubscription? _roomSub;
  var _messages = <Map<String, dynamic>>[];
  StreamSubscription? _msgSub;
  bool _showingAd = false; // State field to track rewarded ad display



  // Local game board elements
  GameState? _gameState;
  ZipGame? _zipGame;
  int? _lastSeed;
  int? _lastGridSize;
  
  // Timers
  Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;
  Duration _elapsed = Duration.zero;
  bool _localSolved = false;
  int? _localSolveTime;
  
  // Banners
  bool _hideOpponentDoneBanner = false;
  double _nextGridSize = 5.0;

  // Hint/Undo variables
  int _hintUsageCount = 0;
  int _hintCooldownRemaining = 0;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    _subscribeRoom();
    _subscribeMessages();
    _startTimer();
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _roomSub?.cancel();
    _msgSub?.cancel();
    _timer?.cancel();
    _messageController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _stopwatch.start();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _elapsed = _stopwatch.elapsed;
        });
      }
    });
  }

  void _subscribeRoom() {
    _roomSub = SupabaseService.streamRoom(widget.roomId).listen((data) {
      if (!mounted) return;

      final oldSeed = _lastSeed;
      final oldGridSize = _lastGridSize;
      
      final newSeed = data['current_seed'] as int;
      final newGridSize = data['grid_size'] as int;

      final isCreator = data['creator_id'] == SupabaseService.currentUser?.id;

      setState(() {
        _roomData = data;
        _lastSeed = newSeed;
        _lastGridSize = newGridSize;
      });

      // If seed or grid size changed, reset/load a new puzzle!
      if (oldSeed != newSeed || oldGridSize != newGridSize) {
        _initGame(newSeed, newGridSize);
      }

      // Check if winner has been set
      final winnerId = data['winner_id'];
      final creatorSolved = data['creator_solved'] as bool? ?? false;
      final opponentSolved = data['opponent_solved'] as bool? ?? false;

      // Handle race condition for first solver
      if (winnerId == null) {
        if (creatorSolved && !opponentSolved) {
          SupabaseService.updateWinner(widget.roomId, data['creator_id'] as String);
        } else if (opponentSolved && !creatorSolved) {
          if (data['opponent_id'] != null) {
            SupabaseService.updateWinner(widget.roomId, data['opponent_id'] as String);
          }
        }
      }

      // Auto-advance level if BOTH players are ready
      final creatorReady = data['creator_calling'] as bool? ?? false;
      final opponentReady = data['opponent_calling'] as bool? ?? false;
      if (creatorReady && opponentReady) {
        if (isCreator) {
          debugPrint('[MultiplayerRoom] Both players are ready. Creator advancing room level...');
          SupabaseService.advanceToNextLevel(widget.roomId, _nextGridSize.toInt());
        }
      }
    });
  }

  void _subscribeMessages() {
    _msgSub = SupabaseService.streamMessages(widget.roomId).listen((msgs) {
      if (!mounted) return;
      setState(() {
        _messages = msgs;
      });
      // Scroll chat to bottom
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_chatScrollController.hasClients) {
          _chatScrollController.animateTo(
            _chatScrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      });
    });
  }

  void _initGame(int seed, int gridSize) {
    debugPrint('[MultiplayerRoom] Initializing puzzle with seed $seed, size $gridSize');
    final customLevel = LevelData.generateCustomLevel(seed: seed, gridSize: gridSize);
    final solution = LevelData.getSolutionForLevel(customLevel);

    setState(() {
      _gameState = GameState(
        level: customLevel,
        solutionPath: solution,
      );
      _zipGame = ZipGame(
        gameState: _gameState!,
        onLevelComplete: _onGameStateChanged,
      );
      _stopwatch.reset();
      _stopwatch.start();
      _localSolved = false;
      _localSolveTime = null;
      _hideOpponentDoneBanner = false;

      _cooldownTimer?.cancel();
      _hintUsageCount = 0;
      _hintCooldownRemaining = 0;
    });

    _gameState!.addListener(_onGameStateChanged);
  }

  void _onGameStateChanged() {
    if (_gameState?.isSolved == true && !_localSolved) {
      _localSolved = true;
      _stopwatch.stop();
      _localSolveTime = _stopwatch.elapsed.inSeconds;
      
      final isCreator = _roomData?['creator_id'] == SupabaseService.currentUser?.id;
      
      // Update solving status in Supabase
      SupabaseService.updateSolveStatus(
        roomId: widget.roomId,
        isCreator: isCreator,
        solved: true,
        timeTaken: _localSolveTime,
      );

      // Play success chime locally
      AudioManager.playSuccess();
    }
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

    if (_gameState == null) return;

    debugPrint('[MultiplayerRoom] Hint requested. Cooldown will be ${_hintUsageCount + 1}s.');
    setState(() {
      _hintUsageCount++;
      _hintCooldownRemaining = _hintUsageCount;
    });

    _gameState!.applyHint();

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

  // ==========================================
  // Chat Messaging
  // ==========================================

  void _sendChat() async {
    AudioManager.playClick();
    final txt = _messageController.text.trim();
    if (txt.isEmpty) return;
    _messageController.clear();
    await SupabaseService.sendChatMessage(widget.roomId, txt);
  }

  // ==========================================
  // Level Progression Actions
  // ==========================================

  void _requestNextLevel() async {
    AudioManager.playClick();
    if (_roomData == null || _showingAd) return;
    
    setState(() => _showingAd = true);
    
    // Show a rewarded ad before proceeding to the next round with friends
    AdManager.showRewardedAd(
      onRewarded: () {
        // Watched successfully
      },
      onAdDismissed: () async {
        if (mounted) {
          setState(() => _showingAd = false);
          final isCreator = _roomData!['creator_id'] == SupabaseService.currentUser?.id;
          debugPrint('[MultiplayerRoom] Client requested next level. Marking ready...');
          await SupabaseService.updateReadyForNext(widget.roomId, isCreator, true);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_roomData == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isCreator = _roomData!['creator_id'] == SupabaseService.currentUser?.id;
    final opponentId = _roomData!['opponent_id'];
    
    // Opponent Details
    final opponentStatus = opponentId == null ? 'Waiting...' : 'Connected';

    // Solve Details
    final mySolved = isCreator ? _roomData!['creator_solved'] : _roomData!['opponent_solved'];
    final opSolved = isCreator ? _roomData!['opponent_solved'] : _roomData!['creator_solved'];
    
    final mySolveTime = isCreator ? _roomData!['creator_solved_time'] : _roomData!['opponent_solved_time'];
    final opSolveTime = isCreator ? _roomData!['opponent_solved_time'] : _roomData!['creator_solved_time'];

    final winnerId = _roomData!['winner_id'];
    final isWinner = winnerId == SupabaseService.currentUser?.id;

    final myReady = isCreator 
        ? (_roomData!['creator_calling'] as bool? ?? false) 
        : (_roomData!['opponent_calling'] as bool? ?? false);
    final opReady = isCreator 
        ? (_roomData!['opponent_calling'] as bool? ?? false) 
        : (_roomData!['creator_calling'] as bool? ?? false);

    final themeColor = const Color(0xFF0A66C2);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F2EF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: Text(
          _roomData!['name'] as String? ?? 'Arena',
          style: GoogleFonts.openSans(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: const [],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10.0),
          child: Column(
            children: [
              // Main Arena (Lobby / Play Boards)
              Expanded(
                child: opponentId == null
                    ? _buildWaitingLobby(themeColor)
                    : _buildMatchArena(
                        themeColor,
                        mySolved,
                        opSolved,
                        mySolveTime,
                        opSolveTime,
                        winnerId,
                        isWinner,
                        myReady,
                        opReady,
                      ),
              ),

              // Persistent Chat Drawer
              if (opponentId != null) _buildPersistentChatDrawer(themeColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWaitingLobby(Color themeColor) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: Card(
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 24),
              Text(
                'Waiting for Opponent...',
                style: GoogleFonts.openSans(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Share the Room ID below with a friend to start the match:',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  widget.roomId,
                  style: GoogleFonts.openSans(fontWeight: FontWeight.bold, fontSize: 15, color: themeColor),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

  Widget _buildMatchArena(
    Color themeColor,
    dynamic mySolved,
    dynamic opSolved,
    dynamic mySolveTime,
    dynamic opSolveTime,
    dynamic winnerId,
    bool isWinner,
    bool myReady,
    bool opReady,
  ) {
    // Determine banner notifications
    final opponentCompleted = opSolved == true;
    final displayDoneBanner = opponentCompleted && !mySolved && !_hideOpponentDoneBanner;

    return Column(
      children: [
        // Scoreboard Bar
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // My Status
              Column(
                children: [
                  const Text('YOU', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black54)),
                  const SizedBox(height: 4),
                  mySolved == true
                      ? Text('SOLVED! (${mySolveTime}s)', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13))
                      : Text('Solving... (${_elapsed.inSeconds}s)', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
              
              // Grid size badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6)),
                child: Text('${_roomData!['grid_size']}x${_roomData!['grid_size']}', style: GoogleFonts.openSans(fontWeight: FontWeight.bold, color: themeColor)),
              ),

              // Opponent Status
              Column(
                children: [
                  const Text('OPPONENT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black54)),
                  const SizedBox(height: 4),
                  opSolved == true
                      ? Text('SOLVED! (${opSolveTime}s)', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13))
                      : const Text('Solving...', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
            ],
          ),
        ),

        // Opponent Done Banner
        if (displayDoneBanner)
          Container(
            color: Colors.red.shade50,
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Text(
                  'Your opponent has finished the puzzle!',
                  style: GoogleFonts.openSans(color: Colors.red.shade900, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    myReady
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Waiting for Opponent...',
                                style: GoogleFonts.openSans(color: Colors.red.shade900, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ],
                          )
                        : ElevatedButton(
                            onPressed: _requestNextLevel,
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                            child: Text(
                              opReady ? 'Next Puzzle (Opponent is waiting! ⏳)' : 'Next Puzzle',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                    const SizedBox(width: 12),
                    OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _hideOpponentDoneBanner = true;
                        });
                      },
                      style: OutlinedButton.styleFrom(side: BorderSide(color: Colors.red.shade900)),
                      child: Text('Keep Solving', style: TextStyle(color: Colors.red.shade900)),
                    ),
                  ],
                ),
              ],
            ),
          ),

        // Game Solved Board Overlay (Winner screen)
        if (winnerId != null)
          Container(
            color: isWinner ? Colors.green.shade50 : Colors.blue.shade50,
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  isWinner ? '🎉 Victory! You won this round!' : 'Winner is Opponent!',
                  style: GoogleFonts.openSans(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Next Grid Size:', style: GoogleFonts.openSans(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    DropdownButton<double>(
                      value: _nextGridSize,
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _nextGridSize = val;
                          });
                        }
                      },
                      items: const [
                        DropdownMenuItem(value: 4.0, child: Text('4x4')),
                        DropdownMenuItem(value: 5.0, child: Text('5x5')),
                        DropdownMenuItem(value: 6.0, child: Text('6x6')),
                        DropdownMenuItem(value: 7.0, child: Text('7x7')),
                        DropdownMenuItem(value: 8.0, child: Text('8x8')),
                      ],
                    ),
                    const SizedBox(width: 16),
                    myReady
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: themeColor),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Waiting for Opponent...',
                                style: GoogleFonts.openSans(fontSize: 13, fontWeight: FontWeight.bold, color: themeColor),
                              ),
                            ],
                          )
                        : ElevatedButton(
                            onPressed: _requestNextLevel,
                            style: ElevatedButton.styleFrom(backgroundColor: themeColor),
                            child: Text(
                              opReady ? 'Next Match Puzzle (Agree! 🤝)' : 'Next Match Puzzle',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                  ],
                ),
              ],
            ),
          ),

        // Interactive Game Board
        Expanded(
          child: _zipGame != null && _gameState != null
              ? Center(
                  child: GameWidget(game: _zipGame!),
                )
              : const Center(child: CircularProgressIndicator()),
        ),

        // ── Banner Ad (Placed directly above Undo/Hint control buttons) ──
        AdManager.buildBannerAd(),
        // ──────────────────────────────────────────────────────────

        // Controls (Undo & Hint)
        if (_gameState != null)
          ListenableBuilder(
            listenable: _gameState!,
            builder: (context, _) {
              return ControlPanel(
                onUndo: () => _gameState!.undo(),
                onHint: _handleHintTapped,
                isUndoEnabled: _gameState!.undoHistory.isNotEmpty,
                hintCooldownRemaining: _hintCooldownRemaining,
              );
            },
          ),
      ],
    );
  }

  Widget _buildPersistentChatDrawer(Color themeColor) {
    return Container(
      height: 200,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.black12, width: 1.5)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: Colors.grey.shade50,
            child: Row(
              children: [
                const Icon(Icons.chat_bubble_outline_rounded, size: 16, color: Colors.black54),
                const SizedBox(width: 6),
                Text(
                  'Match Chat',
                  style: GoogleFonts.openSans(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black54),
                ),
              ],
            ),
          ),
          
          // Messages Feed
          Expanded(
            child: ListView.builder(
              controller: _chatScrollController,
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isMe = msg['sender_id'] == SupabaseService.currentUser?.id;

                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isMe ? themeColor : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          msg['text'] as String? ?? '',
                          style: TextStyle(color: isMe ? Colors.white : Colors.black87, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          
          // Message Input
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    style: const TextStyle(fontSize: 13),
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 6),
                    ),
                    onSubmitted: (_) => _sendChat(),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send_rounded, color: themeColor),
                  onPressed: _sendChat,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
