import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;

  static User? get currentUser => client.auth.currentUser;

  static const String defaultUrl = 'https://bajitocdzllwgpxbyjfm.supabase.co';
  static const String defaultAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJhaml0b2Nkemxsd2dweGJ5amZtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM2NzA4NzgsImV4cCI6MjA5OTI0Njg3OH0.Nu_LSwwlrz2H43Wg9uK4IGvwvI1n3PTIoXP_QrGYzUI';

  static bool get hasSession => client.auth.currentSession != null;

  /// Check if Supabase has credentials saved and initialized
  static Future<bool> isConfigured() async {
    return true; // Always true because we have defaults
  }

  /// Initialize Supabase using stored credentials or custom ones
  static Future<bool> initialize({String? customUrl, String? customKey}) async {
    final prefs = await SharedPreferences.getInstance();
    final url = customUrl ?? prefs.getString('supabase_url') ?? defaultUrl;
    final anonKey = customKey ?? prefs.getString('supabase_anon_key') ?? defaultAnonKey;

    if (url.isEmpty || anonKey.isEmpty) return false;

    // Save if custom configuration is provided
    if (customUrl != null && customKey != null) {
      await prefs.setString('supabase_url', customUrl);
      await prefs.setString('supabase_anon_key', customKey);
    }

    try {
      // Check if already initialized by trying to access client
      final _ = Supabase.instance.client;
      return true;
    } catch (_) {
      try {
        await Supabase.initialize(
          url: url,
          anonKey: anonKey,
          realtimeClientOptions: const RealtimeClientOptions(
            eventsPerSecond: 40,
          ),
        );
        return true;
      } catch (e) {
        debugPrint('[SupabaseService] Init error: $e');
        return false;
      }
    }
  }

  /// Reset Saved Supabase Credentials
  static Future<void> resetCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('supabase_url');
    await prefs.remove('supabase_anon_key');
  }

  // ==========================================
  // Authentication Methods
  // ==========================================

  static Future<void> signInAnonymously(String displayName) async {
    final cleanName = displayName.replaceAll(RegExp(r'\s+'), '').toLowerCase();
    final guestEmail = '$cleanName@gmail.com';
    const guestPassword = 'zxcvbnm';

    try {
      // 1. Try to login first in case the user has signed in before
      final response = await client.auth.signInWithPassword(
        email: guestEmail,
        password: guestPassword,
      );
      
      final userId = response.user?.id;
      if (userId != null) {
        await client.from('profiles').upsert({
          'id': userId,
          'display_name': displayName,
          'is_guest': true,
        });
      }
    } catch (e) {
      debugPrint('[SupabaseService] Login failed, creating new guest account: $e');
      try {
        // 2. Create and sign up new account
        final response = await client.auth.signUp(
          email: guestEmail,
          password: guestPassword,
          data: {
            'display_name': displayName,
            'is_guest': true,
          },
        );

        var userId = response.user?.id;
        
        // If session is null (e.g. requires email confirmation), sign in directly
        if (response.session == null) {
          final signInRes = await client.auth.signInWithPassword(
            email: guestEmail,
            password: guestPassword,
          );
          userId = signInRes.user?.id;
        }

        if (userId != null) {
          await client.from('profiles').upsert({
            'id': userId,
            'display_name': displayName,
            'is_guest': true,
          });
        } else {
          throw Exception("Could not retrieve user ID from response.");
        }
      } catch (fallbackError) {
        debugPrint('[SupabaseService] Guest email signup failed: $fallbackError');
        throw Exception("Guest access failed: $fallbackError");
      }
    }
  }

  static Future<void> signInWithGoogle() async {
    try {
      await client.auth.signInWithOAuth(
        OAuthProvider.google,
        // For Flutter Web, it will redirect automatically
      );
    } catch (e) {
      debugPrint('[SupabaseService] Google sign-in failed: $e');
      rethrow;
    }
  }

  static Future<void> signOut() async {
    await client.auth.signOut();
  }

  static Future<Map<String, dynamic>?> getProfile(String userId) async {
    try {
      final res = await client.from('profiles').select().eq('id', userId).maybeSingle();
      return res;
    } catch (e) {
      debugPrint('[SupabaseService] Fetch profile failed: $e');
      return null;
    }
  }

  // ==========================================
  // Collaborative Room Methods
  // ==========================================

  static Future<Map<String, dynamic>> createRoom(String roomName, int gridSize) async {
    final creatorId = currentUser?.id;
    if (creatorId == null) throw Exception("User not authenticated.");

    final randomSeed = Random().nextInt(999999) + 1;
    final expiresAt = DateTime.now().add(const Duration(minutes: 30)).toUtc().toIso8601String();

    try {
      final room = await client.from('rooms').insert({
        'name': roomName,
        'creator_id': creatorId,
        'grid_size': gridSize,
        'current_seed': randomSeed,
        'expires_at': expiresAt,
        'status': 'waiting',
      }).select().single();
      
      return room;
    } catch (e) {
      debugPrint('[SupabaseService] Create room failed: $e');
      rethrow;
    }
  }

  static Future<void> joinRoom(String roomId) async {
    final opponentId = currentUser?.id;
    if (opponentId == null) throw Exception("User not authenticated.");

    try {
      await client.from('rooms').update({
        'opponent_id': opponentId,
        'status': 'playing',
      }).eq('id', roomId);
    } catch (e) {
      debugPrint('[SupabaseService] Join room failed: $e');
      rethrow;
    }
  }

  static Future<void> updateSolveStatus({
    required String roomId,
    required bool isCreator,
    required bool solved,
    int? timeTaken,
  }) async {
    try {
      final updates = isCreator
          ? {
              'creator_solved': solved,
              'creator_solved_time': timeTaken,
            }
          : {
              'opponent_solved': solved,
              'opponent_solved_time': timeTaken,
            };
      
      await client.from('rooms').update(updates).eq('id', roomId);
    } catch (e) {
      debugPrint('[SupabaseService] Update solve status failed: $e');
    }
  }

  static Future<void> updateWinner(String roomId, String winnerId) async {
    try {
      await client.from('rooms').update({
        'winner_id': winnerId,
      }).eq('id', roomId);
    } catch (e) {
      debugPrint('[SupabaseService] Update winner failed: $e');
    }
  }

  static Future<void> advanceToNextLevel(String roomId, int gridSize) async {
    final nextSeed = Random().nextInt(999999) + 1;
    try {
      await client.from('rooms').update({
        'current_seed': nextSeed,
        'grid_size': gridSize,
        'creator_solved': false,
        'opponent_solved': false,
        'creator_solved_time': null,
        'opponent_solved_time': null,
        'winner_id': null,
        'creator_calling': false,
        'opponent_calling': false,
      }).eq('id', roomId);
    } catch (e) {
      debugPrint('[SupabaseService] Advance room level failed: $e');
    }
  }

  static Future<void> updateReadyForNext(String roomId, bool isCreator, bool ready) async {
    try {
      final updateData = isCreator 
          ? {'creator_calling': ready} 
          : {'opponent_calling': ready};
      await client.from('rooms').update(updateData).eq('id', roomId);
    } catch (e) {
      debugPrint('[SupabaseService] Update ready status failed: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> fetchActiveRooms() async {
    // Run cleanup of old guest accounts asynchronously in the background
    client.rpc('cleanup_old_guests').then((_) {}).catchError((_) {});

    try {
      final now = DateTime.now().toUtc().toIso8601String();
      // Fetch rooms that haven't expired and aren't full (no opponent yet or currentUser is in it)
      final response = await client
          .from('rooms')
          .select('*, creator:profiles!rooms_creator_id_fkey(*), opponent:profiles!rooms_opponent_id_fkey(*)')
          .gt('expires_at', now)
          .or('status.eq.waiting,creator_id.eq.${currentUser?.id},opponent_id.eq.${currentUser?.id}')
          .order('created_at', ascending: false);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('[SupabaseService] Fetch active rooms error: $e');
      return [];
    }
  }

  static Stream<Map<String, dynamic>> streamRoom(String roomId) {
    return client
        .from('rooms')
        .stream(primaryKey: ['id'])
        .eq('id', roomId)
        .map((list) => list.first);
  }

  // ==========================================
  // Chat Messaging Methods
  // ==========================================

  static Future<void> sendChatMessage(String roomId, String text) async {
    final senderId = currentUser?.id;
    if (senderId == null) return;

    try {
      await client.from('messages').insert({
        'room_id': roomId,
        'sender_id': senderId,
        'text': text,
      });
    } catch (e) {
      debugPrint('[SupabaseService] Send message failed: $e');
    }
  }

  static Stream<List<Map<String, dynamic>>> streamMessages(String roomId) {
    return client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('room_id', roomId)
        .order('created_at', ascending: true);
  }
}
