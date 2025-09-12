import 'dart:ui';
import 'package:flutter/material.dart';
import 'premium_manager.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SlidePanel extends StatelessWidget {
  final bool panelOpen;
  final double panelWidth;
  final double screenHeight;
  final VoidCallback togglePanel;
  final List<String> history;
  final User? user;
  final PremiumManager premiumManager;
  final Future<void> Function() signIn;
  final Future<void> Function() signOut;
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
    required this.signIn,
    required this.signOut,
    required this.showRewarded,
    required this.toggleTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (panelOpen)
          GestureDetector(
            onTap: togglePanel,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: panelOpen ? 1.0 : 0.0,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: Container(color: Colors.black.withOpacity(0.2)),
              ),
            ),
          ),
        AnimatedPositioned(
          duration: const Duration(milliseconds: 200),
          right: panelOpen ? 0 : -panelWidth,
          top: screenHeight * 0.125,
          height: screenHeight * 0.75,
          width: panelWidth,
          child: ClipRRect(
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(24)),
            child: Container(
              color: Colors.white,
              child: Column(
                children: [
                  ListTile(
                    title: const Text("Toggle Theme"),
                    onTap: toggleTheme,
                  ),
                  if (user == null) ...[
                    ListTile(
                      title: const Text("Sign In"),
                      onTap: signIn,
                    ),
                    ListTile(
                      title: const Text("Sign Up"),
                      onTap: signIn, // same Google Sign-In for auto-register
                    ),
                  ] else ...[
                    ListTile(
                      title: Text("Signed in as ${user!.email}"),
                    ),
                    ListTile(
                      title: const Text("Sign Out"),
                      onTap: signOut,
                    ),
                    if (!premiumManager.isPremium)
                      ListTile(
                        title: const Text("Unlock Premium (1hr)"),
                        subtitle: const Text("Watch ad to unlock"),
                        onTap: showRewarded,
                      ),
                  ],
                  Expanded(
                    child: ListView(
                      children: history.map((h) => ListTile(title: Text(h))).toList(),
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
