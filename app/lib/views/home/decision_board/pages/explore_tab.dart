import 'package:flutter/material.dart';
import '../../../../theme.dart';
import '../cards/_card_shell.dart';

class ExploreTab extends StatelessWidget {
  const ExploreTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HelloColors.inkPrimary,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            floating: true,
            title: const Text('EXPLORE', style: TextStyle(fontFamily: 'Inter', fontSize: 13, letterSpacing: 2.0, color: Colors.white54)),
            centerTitle: true,
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 16.0,
                crossAxisSpacing: 16.0,
                childAspectRatio: 0.75,
              ),
              delegate: SliverChildBuilderDelegate(
                (BuildContext context, int index) {
                  return CardShell(
                    id: 'explore_item_$index',
                    padding: EdgeInsets.zero,
                    backgroundImage: const DecorationImage(
                      image: AssetImage('assets/decide/bali_beach.jpg'),
                      fit: BoxFit.cover,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Colors.black.withAlpha(180), Colors.transparent],
                        ),
                      ),
                      padding: const EdgeInsets.all(12.0),
                      alignment: Alignment.bottomLeft,
                      child: Text(
                        'Destination ${index + 1}',
                        style: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w400, color: Colors.white),
                      ),
                    ),
                  );
                },
                childCount: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
