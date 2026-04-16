import 'package:flutter/material.dart';
import '../../theme.dart';

class GroupExpensePage extends StatelessWidget {
  const GroupExpensePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HelloColors.surfaceDeep,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('The Ledger', style: HelloText.title),
              const SizedBox(height: 80),
              // Simulated 3D Volumetric Budget Placeholder
              Center(
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [HelloColors.accent, HelloColors.surfaceDeep],
                      radius: 0.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: HelloColors.accent.withValues(alpha: 0.1),
                        blurRadius: 60,
                        spreadRadius: 20,
                      )
                    ],
                  ),
                  child: Center(
                    child: Text('\$4,200', style: HelloText.display),
                  ),
                ),
              ),
              const Spacer(),
              Text('YOU OWE \$120', style: HelloText.label.copyWith(color: HelloColors.error)),
            ],
          ),
        ),
      ),
    );
  }
}
