import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'premium_manager.dart';

class SlidePanel extends StatefulWidget {
  final bool panelOpen;
  final double panelWidth, screenHeight;
  final VoidCallback togglePanel, toggleTheme;
  final List<String> history;
  final User? user;
  final PremiumManager premiumManager;
  final Future<void> Function() showRewarded;

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
  double _dragOffset = 0.0;

  void showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> handleGoogleSignIn() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        showMessage("Sign in canceled");
        return;
      }
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      showMessage(userCredential.additionalUserInfo?.isNewUser ?? false
          ? "Account created!"
          : "Signed in successfully");
    } catch (e) {
      showMessage("Sign in failed");
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> handleSignOut() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      await FirebaseAuth.instance.signOut();
      await GoogleSignIn().signOut();
      showMessage("Signed out successfully");
    } catch (_) {
      showMessage("Sign out failed");
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    _dragOffset += details.primaryDelta ?? 0;
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    if (_dragOffset.abs() > 50) widget.togglePanel();
    _dragOffset = 0.0;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (widget.panelOpen)
          GestureDetector(
            onTap: widget.togglePanel,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: 1.0,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: Container(color: Colors.black.withOpacity(0.2)),
              ),
            ),
          ),
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
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
              ),
            ),
          ),
        ),
        AnimatedPositioned(
          duration: const Duration(milliseconds: 200),
          right: widget.panelOpen ? 0 : -widget.panelWidth,
          top: widget.screenHeight * 0.125,
          height: widget.screenHeight * 0.75,
          width: widget.panelWidth,
          child: GestureDetector(
            onVerticalDragUpdate: _onVerticalDragUpdate,
            onVerticalDragEnd: _onVerticalDragEnd,
            child: ClipRRect(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(24)),
              child: Container(
                color: Colors.white,
                child: Column(
                  children: [
                    ListTile(title: const Text("Toggle Theme"), onTap: widget.toggleTheme),
                    const Divider(),
                    if (widget.user == null)
                      ListTile(title: const Text("Sign in with Google"), onTap: handleGoogleSignIn)
                    else ...[
                      ListTile(title: Text("Signed in as ${widget.user!.email}")),
                      ListTile(title: const Text("Sign Out"), onTap: handleSignOut),
                      if (!widget.premiumManager.isPremium)
                        ListTile(
                          title: const Text("Unlock Premium (1hr)"),
                          subtitle: const Text("Watch ad to unlock"),
                          onTap: widget.showRewarded,
                        ),
                    ],
                    const Divider(),
                    if (widget.user != null)
                      Expanded(
                        child: ListView.builder(
                          itemCount: widget.history.length,
                          itemBuilder: (context, index) => ListTile(title: Text(widget.history[index])),
                        ),
                      ),
                    if (_isProcessing)
                      Container(
                        color: Colors.black.withOpacity(0.25),
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
