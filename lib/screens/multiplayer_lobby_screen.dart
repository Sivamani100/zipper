import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/supabase_service.dart';
import 'multiplayer_room_screen.dart';

class MultiplayerLobbyScreen extends StatefulWidget {
  final VoidCallback onSignOut;

  const MultiplayerLobbyScreen({super.key, required this.onSignOut});

  @override
  State<MultiplayerLobbyScreen> createState() => _MultiplayerLobbyScreenState();
}

class _MultiplayerLobbyScreenState extends State<MultiplayerLobbyScreen> {
  List<Map<String, dynamic>> _rooms = [];
  bool _isLoading = false;
  String? _errorMessage;
  final _privateRoomIdController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _refreshRooms();
  }

  @override
  void dispose() {
    _privateRoomIdController.dispose();
    super.dispose();
  }

  Future<void> _refreshRooms() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final rooms = await SupabaseService.fetchActiveRooms();
      if (mounted) {
        setState(() {
          _rooms = rooms;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Failed to load rooms: $e";
        });
      }
    }
  }

  void _showCreateRoomDialog() {
    final roomNameController = TextEditingController(
      text: "${SupabaseService.currentUser?.email?.split('@').first ?? 'Player'}'s Room",
    );
    double gridSize = 5.0;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                'Create Multiplayer Room',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ROOM NAME',
                    style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: roomNameController,
                    decoration: InputDecoration(
                      hintText: 'Enter room name...',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'GRID SIZE',
                        style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
                      ),
                      Text(
                        '${gridSize.toInt()} x ${gridSize.toInt()}',
                        style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF0A66C2)),
                      ),
                    ],
                  ),
                  Slider(
                    value: gridSize,
                    min: 4,
                    max: 8,
                    divisions: 4,
                    activeColor: const Color(0xFF0A66C2),
                    onChanged: (val) {
                      setDialogState(() {
                        gridSize = val;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final name = roomNameController.text.trim();
                    if (name.isEmpty) return;

                    Navigator.pop(context); // Close dialog
                    _createNewRoom(name, gridSize.toInt());
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0A66C2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Create Room', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _createNewRoom(String name, int gridSize) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final room = await SupabaseService.createRoom(name, gridSize);
      _isLoading = false;
      
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MultiplayerRoomScreen(roomId: room['id'] as String),
          ),
        ).then((_) => _refreshRooms());
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to create room: $e'), backgroundColor: Colors.redAccent),
          );
        });
      }
    }
  }

  void _joinRoom(String roomId) async {
    setState(() {
      _isLoading = true;
    });

    try {
      await SupabaseService.joinRoom(roomId);
      _isLoading = false;

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MultiplayerRoomScreen(roomId: roomId),
          ),
        ).then((_) => _refreshRooms());
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to join room: $e'), backgroundColor: Colors.redAccent),
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = const Color(0xFF0A66C2);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F2EF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: Text(
          'Battle Arena',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.black87),
            tooltip: 'Refresh',
            onPressed: _refreshRooms,
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            tooltip: 'Sign Out',
            onPressed: widget.onSignOut,
          ),
        ],
      ),
      body: _isLoading && _rooms.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refreshRooms,
              child: Column(
                children: [
                  // User stats header card
                  Container(
                    width: double.infinity,
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: themeColor.withValues(alpha: 0.1),
                          radius: 20,
                          child: Icon(Icons.sports_esports_rounded, color: themeColor),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                SupabaseService.currentUser?.userMetadata?['display_name'] ?? 'Anonymous Player',
                                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              Text(
                                SupabaseService.currentUser?.email ?? 'Logged in as Guest',
                                style: const TextStyle(fontSize: 12, color: Colors.black54),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _showCreateRoomDialog,
                          icon: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                          label: Text(
                            'New Room',
                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: themeColor,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            elevation: 0,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Colors.black12),

                  // Join Private Room Panel
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _privateRoomIdController,
                            style: const TextStyle(fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Paste Room ID to join...',
                              prefixIcon: const Icon(Icons.vpn_key_outlined, size: 18),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: Colors.grey.shade200),
                              ),
                              fillColor: const Color(0xFFF9F9FB),
                              filled: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () {
                            final rid = _privateRoomIdController.text.trim();
                            if (rid.isNotEmpty) {
                              _privateRoomIdController.clear();
                              _joinRoom(rid);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey.shade800,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          child: Text(
                            'Join ID',
                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Colors.black12),

                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                    ),

                  Expanded(
                    child: _rooms.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                              const Center(
                                child: Icon(Icons.meeting_room_outlined, size: 64, color: Colors.black26),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No active match rooms found.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.outfit(color: Colors.black45, fontSize: 16),
                              ),
                              Text(
                                'Tap "New Room" above to create one!',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.outfit(color: Colors.black38, fontSize: 13),
                              ),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16.0),
                            itemCount: _rooms.length,
                            itemBuilder: (context, index) {
                              final room = _rooms[index];
                              final creator = room['creator'] as Map<String, dynamic>?;
                              final opponent = room['opponent'] as Map<String, dynamic>?;
                              final creatorName = creator?['display_name'] ?? 'Creator';
                              final isCreator = room['creator_id'] == SupabaseService.currentUser?.id;
                              final isOpponent = room['opponent_id'] == SupabaseService.currentUser?.id;
                              final status = room['status'] as String;

                              return Card(
                                elevation: 0,
                                color: Colors.white,
                                margin: const EdgeInsets.only(bottom: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(color: Colors.grey.shade200),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              room['name'] as String? ?? 'Match Room',
                                              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
                                            ),
                                            const SizedBox(height: 6),
                                            Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: themeColor.withValues(alpha: 0.1),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    '${room['grid_size']}x${room['grid_size']}',
                                                    style: TextStyle(
                                                      color: themeColor,
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                Text(
                                                  'By: $creatorName',
                                                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      if (isCreator || isOpponent)
                                        ElevatedButton(
                                          onPressed: () => _joinRoom(room['id'] as String),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.green,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          ),
                                          child: const Text('Re-enter', style: TextStyle(color: Colors.white)),
                                        )
                                      else if (opponent != null)
                                        ElevatedButton(
                                          onPressed: null,
                                          style: ElevatedButton.styleFrom(
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          ),
                                          child: const Text('In Progress'),
                                        )
                                      else
                                        ElevatedButton(
                                          onPressed: () => _joinRoom(room['id'] as String),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: themeColor,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          ),
                                          child: const Text('Join Room', style: TextStyle(color: Colors.white)),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
