import 'package:flutter/material.dart';
import '../../theme.dart';

class PlanDetailPage extends StatelessWidget {
  const PlanDetailPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HelloColors.voidBg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            backgroundColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [const Color(0xFF000000), HelloColors.surfaceDeep],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Center(
                  // Droplet mask analog
                  child: Icon(Icons.hotel, size: 80, color: HelloColors.inkTertiary),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('The Dolder Grand', style: HelloText.display),
                  const SizedBox(height: 16),
                  Text('ZURICH • \$450/NIGHT', style: HelloText.label),
                  const SizedBox(height: 48),
                  Text('A luxury urban resort with stunning views of the Alps.', style: HelloText.body),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
