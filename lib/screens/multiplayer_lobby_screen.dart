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
                style: GoogleFonts.openSans(fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ROOM NAME',
                    style: GoogleFonts.openSans(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
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
                        style: GoogleFonts.openSans(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
                      ),
                      Text(
                        '${gridSize.toInt()} x ${gridSize.toInt()}',
                        style: GoogleFonts.openSans(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF0A66C2)),
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
          style: GoogleFonts.openSans(fontWeight: FontWeight.bold, color: Colors.black87),
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
          : Padding(
              padding: const EdgeInsets.symmetric(vertical: 10.0),
              child: RefreshIndicator(
                onRefresh: _refreshRooms,
                child: Column(
                  children: [
                    // User stats header card
                    Container(
                      width: double.infinity,
                      color: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: themeColor.withValues(alpha: 0.1),
                            child: Text(
                              (SupabaseService.currentUser?.userMetadata?['display_name'] as String? ?? 'A')
                                  .substring(0, 1)
                                  .toUpperCase(),
                              style: TextStyle(fontWeight: FontWeight.bold, color: themeColor, fontSize: 18),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  SupabaseService.currentUser?.userMetadata?['display_name'] as String? ?? 'Anonymous Player',
                                  style: GoogleFonts.openSans(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  SupabaseService.currentUser?.email ?? 'Logged in as Guest',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: Color(0xFFE9ECEF)),
                    const SizedBox(height: 12),
                    
                    // Join private room panel
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Container(
                        padding: const EdgeInsets.all(16.0),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'JOIN PRIVATE ROOM',
                              style: GoogleFonts.openSans(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _privateRoomIdController,
                                    style: const TextStyle(fontSize: 13),
                                    decoration: InputDecoration(
                                      hintText: 'Paste Room ID to join...',
                                      filled: true,
                                      fillColor: const Color(0xFFF8F9FA),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                ElevatedButton(
                                  onPressed: () {
                                    final text = _privateRoomIdController.text.trim();
                                    if (text.isNotEmpty) {
                                      _privateRoomIdController.clear();
                                      _joinRoom(text);
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: themeColor,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  child: const Text('Join ID', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Quick Action button to create a room
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: ElevatedButton.icon(
                        onPressed: _showCreateRoomDialog,
                        icon: const Icon(Icons.add_box_rounded, color: Colors.white),
                        label: const Text('Create New Match Room', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: themeColor,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Active Rooms Header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: Row(
                        children: [
                          Text(
                            'Active Match Lobby',
                            style: GoogleFonts.openSans(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: themeColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                            child: Text(
                              '${_rooms.length} Active',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: themeColor),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    
                    // Match Rooms List
                    Expanded(
                      child: _rooms.isEmpty
                          ? ListView(
                              children: [
                                SizedBox(height: 40),
                                Center(
                                  child: Text(
                                    'No active match rooms found.\nCreate one above to challenge a friend!',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.grey.shade500, fontSize: 13, height: 1.4),
                                  ),
                                ),
                              ],
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              itemCount: _rooms.length,
                              itemBuilder: (context, index) {
                                final room = _rooms[index];
                                final creator = room['creator'] as Map<String, dynamic>?;
                                final opponent = room['opponent'] as Map<String, dynamic>?;
                                final isMyRoom = room['creator_id'] == SupabaseService.currentUser?.id ||
                                    room['opponent_id'] == SupabaseService.currentUser?.id;

                                return Card(
                                  color: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(color: Colors.grey.shade200),
                                  ),
                                  margin: const EdgeInsets.only(bottom: 10),
                                  child: Padding(
                                    padding: const EdgeInsets.all(14.0),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                room['name'] as String? ?? 'Match Arena',
                                                style: GoogleFonts.openSans(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87),
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  Text(
                                                    'Host: ${creator?['username'] ?? 'Player'}',
                                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    width: 4,
                                                    height: 4,
                                                    decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.grey.shade400),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    'Grid: ${room['grid_size']}x${room['grid_size']}',
                                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (isMyRoom)
                                          ElevatedButton(
                                            onPressed: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) => MultiplayerRoomScreen(roomId: room['id'] as String),
                                                ),
                                              ).then((_) => _refreshRooms());
                                            },
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
            ),
    );
  }
}
