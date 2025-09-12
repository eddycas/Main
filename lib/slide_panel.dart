import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_manager.dart';
import 'premium_manager.dart';

class SlidePanel extends StatefulWidget {
  final bool panelOpen;
  final double panelWidth;
  final double screenHeight;
  final VoidCallback togglePanel;
  final List<String> history;
  final User? user;
  final PremiumManager premiumManager;
  final Future<void> Function() showRewarded;
  final VoidCallback toggleTheme;

  const SlidePanel({
    super.key,
    required this.panelOpen,
    required this.panelWidth,
    required this.screenHeight,
    required this.togglePanel,
    required this.history,
    required this.user,
    required this.premiumManager,
    required this.showRewarded,
    required this.toggleTheme,
  });

  @override
  State<SlidePanel> createState() => _SlidePanelState();
}

class _SlidePanelState extends State<SlidePanel> {
  bool _isProcessing = false;

  // ------------------ Helpers ------------------
  void showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String getFriendlyError(Object e) {
    if (e is FirebaseAuthException) {
      return e.message ?? "Authentication error";
    }
    return "Something went wrong";
  }

  Future<void> handleSignIn() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      await AuthManager.instance.signInWithGoogle();
      showMessage("Signed in successfully");
    } catch (e) {
      showMessage("Sign in failed: ${getFriendlyError(e)}");
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> handleSignUp() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      final credential =
          await AuthManager.instance.signInWithGoogleAndReturnCredential();

      if (credential?.additionalUserInfo?.isNewUser ?? false) {
        showMessage("Account created successfully");
      } else {
        showMessage("Account already exists, signed in");
      }
    } catch (e) {
      showMessage("Sign up failed: ${getFriendlyError(e)}");
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> handleSignOut() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      await AuthManager.instance.signOut();
      showMessage("Signed out successfully");
    } catch (e) {
      showMessage("Sign out failed: ${getFriendlyError(e)}");
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> handleShowRewarded() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      await widget.showRewarded();
      showMessage("Premium unlocked!");
    } catch (e) {
      showMessage("Failed to unlock premium: ${getFriendlyError(e)}");
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Dimmed background when panel is open
        if (widget.panelOpen)
          GestureDetector(
            onTap: widget.togglePanel,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: widget.panelOpen ? 1.0 : 0.0,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: Container(color: Colors.black.withOpacity(0.2)),
              ),
            ),
          ),

        // Panel handle (always visible)
        Positioned(
          right: 0,
          top: widget.screenHeight * 0.5 - 30,
          child: GestureDetector(
            onTap: widget.togglePanel,
            child: Container(
              width: 20,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius:
                    const BorderRadius.horizontal(left: Radius.circular(12)),
              ),
            ),
          ),
        ),

        // Sliding panel
        AnimatedPositioned(
          duration: const Duration(milliseconds: 200),
          right: widget.panelOpen ? 0 : -widget.panelWidth,
          top: widget.screenHeight * 0.125,
          height: widget.screenHeight * 0.75,
          width: widget.panelWidth,
          child: ClipRRect(
            borderRadius:
                const BorderRadius.horizontal(left: Radius.circular(24)),
            child: Container(
              color: Colors.white,
              child: Column(
                children: [
                  // Theme toggle
                  ListTile(
                    title: const Text("Toggle Theme"),
                    onTap: widget.toggleTheme,
                  ),
                  const Divider(),

                  // Auth buttons
                  if (widget.user == null) ...[
                    ListTile(
                      title: const Text("Sign In"),
                      enabled: !_isProcessing,
                      onTap: handleSignIn,
                    ),
                    ListTile(
                      title: const Text("Sign Up"),
                      enabled: !_isProcessing,
                      onTap: handleSignUp,
                    ),
                  ] else ...[
                    ListTile(
                      title: Text("Signed in as ${widget.user!.email}"),
                    ),
                    ListTile(
                      title: const Text("Sign Out"),
                      enabled: !_isProcessing,
                      onTap: handleSignOut,
                    ),
                    if (!widget.premiumManager.isPremium)
                      ListTile(
                        title: const Text("Unlock Premium (1hr)"),
                        subtitle: const Text("Watch ad to unlock"),
                        enabled: !_isProcessing,
                        onTap: handleShowRewarded,
                      ),
                  ],
                  const Divider(),

                  // History list (only if signed in)
                  if (widget.user != null)
                    Expanded(
                      child: ListView.builder(
                        itemCount: widget.history.length,
                        itemBuilder: (context, index) {
                          return ListTile(title: Text(widget.history[index]));
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
