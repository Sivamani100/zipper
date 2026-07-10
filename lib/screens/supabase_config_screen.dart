import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/supabase_service.dart';

class SupabaseConfigScreen extends StatefulWidget {
  final VoidCallback onConfigured;

  const SupabaseConfigScreen({super.key, required this.onConfigured});

  @override
  State<SupabaseConfigScreen> createState() => _SupabaseConfigScreenState();
}

class _SupabaseConfigScreenState extends State<SupabaseConfigScreen> {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();
  final _keyController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _urlController.dispose();
    _keyController.dispose();
    super.dispose();
  }

  void _saveAndConnect() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final url = _urlController.text.trim();
    final key = _keyController.text.trim();

    final success = await SupabaseService.initialize(customUrl: url, customKey: key);

    if (mounted) {
      setState(() {
        _isLoading = false;
      });

      if (success) {
        widget.onConfigured();
      } else {
        setState(() {
          _errorMessage = "Failed to connect. Please check your URL and Anon Key and try again.";
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
              // Logo/Icon
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: themeColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: themeColor.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.bolt_rounded,
                  color: Colors.white,
                  size: 40,
                ),
              ),
              const SizedBox(height: 24),
              
              Text(
                'Connect Supabase',
                style: GoogleFonts.outfit(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              
              Text(
                'Enter your project API keys to enable rooms, real-time chat, and multiplayer gameplay.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 32),

              Form(
                key: _formKey,
                child: Container(
                  padding: const EdgeInsets.all(24.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'PROJECT URL',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _urlController,
                        style: const TextStyle(fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'https://xxxxxx.supabase.co',
                          filled: true,
                          fillColor: const Color(0xFFF9F9FB),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.grey.shade200),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your project URL';
                          }
                          if (!value.startsWith('http')) {
                            return 'URL must start with http/https';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      Text(
                        'ANON API KEY',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _keyController,
                        obscureText: true,
                        style: const TextStyle(fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...',
                          filled: true,
                          fillColor: const Color(0xFFF9F9FB),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.grey.shade200),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your Anon API key';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.red, fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      ElevatedButton(
                        onPressed: _isLoading ? null : _saveAndConnect,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: themeColor,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0.5,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                'Save and Connect',
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.info_outline_rounded, size: 16, color: Colors.black45),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'API keys are stored securely in local device storage and sent only to Supabase.',
                      style: GoogleFonts.outfit(fontSize: 12, color: Colors.black45),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
