import 'package:flutter/material.dart';

class PortalPageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  PortalPageRoute({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: const Duration(milliseconds: 600),
          reverseTransitionDuration: const Duration(milliseconds: 500),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // Forward animation: The Plan World scales UP from 0.8 and Fades IN.
            final scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
              CurvedAnimation(
                parent: animation,
                // Spring-like curve for organic, cinematic feel
                curve: Curves.easeOutExpo, 
              ),
            );

            final fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
              CurvedAnimation(
                parent: animation,
                curve: Curves.easeOut,
              ),
            );

            // Secondary animation handles the push-back of the current active page
            // when ANOTHER page is pushed on top of it.
            final secondaryScaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
              CurvedAnimation(
                parent: secondaryAnimation,
                curve: Curves.easeOutExpo,
              ),
            );

            return FadeTransition(
              opacity: fadeAnimation,
              child: ScaleTransition(
                scale: scaleAnimation,
                child: ScaleTransition(
                  scale: secondaryScaleAnimation,
                  child: child,
                ),
              ),
            );
          },
        );
}
