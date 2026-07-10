import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/supabase_service.dart';

class AuthScreen extends StatefulWidget {
  final VoidCallback onAuthenticated;
  final VoidCallback onClearConfig;

  const AuthScreen({
    super.key,
    required this.onAuthenticated,
    required this.onClearConfig,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _usernameController = TextEditingController();
  bool _isLoadingGuest = false;
  bool _isLoadingGoogle = false;
  String? _error;

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  void _loginAsGuest() async {
    final nick = _usernameController.text.trim();
    if (nick.isEmpty) {
      setState(() {
        _error = "Please enter a nickname to proceed!";
      });
      return;
    }

    setState(() {
      _isLoadingGuest = true;
      _error = null;
    });

    try {
      await SupabaseService.signInAnonymously(nick);
      if (mounted) {
        widget.onAuthenticated();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingGuest = false;
          _error = "Guest access failed: $e";
        });
      }
    }
  }

  void _loginWithGoogle() async {
    setState(() {
      _isLoadingGoogle = true;
      _error = null;
    });

    try {
      await SupabaseService.signInWithGoogle();
      // On web/mobile Oauth redirect is handled asynchronously, so we wait or pop
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingGoogle = false;
          _error = "Google login failed: $e";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = const Color(0xFF0A66C2);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F2EF),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Dynamic Logo
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [themeColor, themeColor.withValues(alpha: 0.8)],
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: themeColor.withValues(alpha: 0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.grid_view_rounded,
                  color: Colors.white,
                  size: 40,
                ),
              ),
              const SizedBox(height: 24),
              
              Text(
                'Zipper Multiplayer',
                style: GoogleFonts.outfit(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              
              Text(
                'Connect and compete with friends in real-time.',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 36),

              Container(
                padding: const EdgeInsets.all(24.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'GUEST NICKNAME (REQUIRED)',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _usernameController,
                      style: const TextStyle(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Enter your nickname...',
                        filled: true,
                        fillColor: const Color(0xFFF9F9FB),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    ElevatedButton.icon(
                      onPressed: _isLoadingGuest || _isLoadingGoogle ? null : _loginAsGuest,
                      icon: _isLoadingGuest
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.person_outline_rounded, color: Colors.white, size: 20),
                      label: Text(
                        'Play as Guest',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: themeColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0.5,
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(child: Divider(color: Colors.grey.shade300)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'OR',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                          ),
                        ),
                        Expanded(child: Divider(color: Colors.grey.shade300)),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Google OAuth Button
                    OutlinedButton.icon(
                      onPressed: _isLoadingGuest || _isLoadingGoogle ? null : _loginWithGoogle,
                      icon: _isLoadingGoogle
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black54,
                              ),
                            )
                          : const Icon(Icons.login_rounded, size: 20),
                      label: Text(
                        'Sign in with Google',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black87,
                        side: BorderSide(color: Colors.grey.shade300),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),

                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: const TextStyle(color: Colors.red, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 36),
              
              // Clear Config trigger
              TextButton.icon(
                onPressed: widget.onClearConfig,
                icon: const Icon(Icons.settings_outlined, size: 16, color: Colors.black54),
                label: Text(
                  'Disconnect Supabase Project',
                  style: GoogleFonts.outfit(
                    color: Colors.black54,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
