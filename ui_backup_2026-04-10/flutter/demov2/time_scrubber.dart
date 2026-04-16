import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';

class DecisionEvent {
  final String title;
  final String imageUrl;
  final String year;
  final String month;

  DecisionEvent(this.title, this.imageUrl, this.year, this.month);
}

final List<DecisionEvent> _mockEvents = [
  DecisionEvent("Graduation Dinner", "https://picsum.photos/seed/grad20/800/800", "2020", "May"),
  DecisionEvent("Backpacking Alps", "https://picsum.photos/seed/alps20/800/800", "2020", "Jul"),
  DecisionEvent("Coachella Crew", "https://picsum.photos/seed/coach21/800/800", "2021", "Apr"),
  DecisionEvent("Iceland Ring Road", "https://picsum.photos/seed/ice21/800/800", "2021", "Oct"),
  DecisionEvent("NYC Marathon", "https://picsum.photos/seed/nyc21/800/800", "2021", "Nov"),
  DecisionEvent("Joshua Tree NYE", "https://picsum.photos/seed/jtree21/800/800", "2021", "Dec"),
  DecisionEvent("Tokyo Golden Week", "https://picsum.photos/seed/tokyo22/800/800", "2022", "May"),
  DecisionEvent("Ibiza Closing Party", "https://picsum.photos/seed/ibiza22/800/800", "2022", "Sep"),
  DecisionEvent("Dad's 60th Safari", "https://picsum.photos/seed/safari22/800/800", "2022", "Nov"),
  DecisionEvent("Tulum Retreat", "https://picsum.photos/seed/tulum23/800/800", "2023", "Apr"),
  DecisionEvent("Surfing Santa Cruz", "https://picsum.photos/seed/surf23/800/800", "2023", "Aug"),
  DecisionEvent("Japantown Hotpot", "https://picsum.photos/seed/japan24/800/800", "2024", "Feb"),
  DecisionEvent("Lake Como Villa", "https://picsum.photos/seed/como24/800/800", "2024", "Jun"),
  DecisionEvent("Brooklyn Rooftop", "https://picsum.photos/seed/bk24/800/800", "2024", "Sep"),
  DecisionEvent("Tahoe Cabin Trip", "https://picsum.photos/seed/tahoe24/800/800", "2024", "Dec"),
];

class TimeScrubberOverlay extends StatefulWidget {
  const TimeScrubberOverlay({super.key});

  @override
  State<TimeScrubberOverlay> createState() => _TimeScrubberOverlayState();
}

class _TimeScrubberOverlayState extends State<TimeScrubberOverlay> {
  late PageController _verticalPageController;
  final List<String> _uniqueYears = ['2020', '2021', '2022', '2023', '2024']; // From oldest to newest
  late Map<String, List<DecisionEvent>> _groupedEvents;

  double _scrubValue = 1.0; // Start at bottom/newest (2024)

  @override
  void initState() {
    super.initState();
    
    // Group events by year for the 2D taxonomy
    _groupedEvents = {};
    for (var year in _uniqueYears) {
      _groupedEvents[year] = _mockEvents.where((e) => e.year == year).toList();
    }
    
    _verticalPageController = PageController(initialPage: _uniqueYears.length - 1);
    
    _verticalPageController.addListener(() {
      if (!_verticalPageController.position.isScrollingNotifier.value) return;
      final maxScroll = _verticalPageController.position.maxScrollExtent;
      if (maxScroll > 0) {
        setState(() {
          _scrubValue = _verticalPageController.offset / maxScroll;
        });
      }
    });
  }

  @override
  void dispose() {
    _verticalPageController.dispose();
    super.dispose();
  }
  
  String get _currentActiveYear {
    int index = (_scrubValue * (_uniqueYears.length - 1)).clamp(0, _uniqueYears.length - 1).round();
    return _uniqueYears[index];
  }

  void _onScrub(double verticalPosition, double containerHeight) {
    double newValue = (verticalPosition / containerHeight).clamp(0.0, 1.0);
    setState(() {
      _scrubValue = newValue;
    });
    
    // Snappy page jumping corresponding to the scrubber position
    int targetPage = (_scrubValue * (_uniqueYears.length - 1)).round();
    _verticalPageController.jumpToPage(targetPage);
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HelloColors.voidBg.withOpacity(0.92),
      body: SafeArea(
        child: Stack(
          children: [
            // Background Fade Layer (Mocking chat)
            Positioned.fill(
              child: Opacity(
                opacity: 0.05,
                child: ListView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 30,
                  itemBuilder: (c, i) => Container(
                    height: 50,
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: HelloColors.voidBg,
                      borderRadius: BorderRadius.circular(16)
                    ),
                  ),
                ),
              ),
            ),
            
            // Close Button
            Positioned(
              top: 16,
              left: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: HelloColors.inkSecondary),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),

            // Fluid 2D Navigation View (Vertical Years)
            Positioned.fill(
              left: 0,
              right: 60, // Leave some right padding for scrubber
              child: PageView.builder(
                controller: _verticalPageController,
                scrollDirection: Axis.vertical,
                physics: const BouncingScrollPhysics(),
                itemCount: _uniqueYears.length,
                itemBuilder: (context, verticalIndex) {
                  String year = _uniqueYears[verticalIndex];
                  List<DecisionEvent> yearEvents = _groupedEvents[year] ?? [];
                  
                  return _YearShelf(year: year, events: yearEvents);
                },
              ),
            ),

            // Vertical Z-Axis Scrubber (Years)
            Positioned(
              right: 16,
              top: 80,
              bottom: 80,
              width: 50,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return GestureDetector(
                    onVerticalDragUpdate: (details) => _onScrub(details.localPosition.dy, constraints.maxHeight),
                    onVerticalDragDown: (details) => _onScrub(details.localPosition.dy, constraints.maxHeight),
                    child: Container(
                      color: Colors.transparent, // Expand hit box
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                           // Rail
                           Container(
                             width: 2,
                             decoration: BoxDecoration(
                               color: HelloColors.inkTertiary.withOpacity(0.2),
                               borderRadius: BorderRadius.circular(2),
                             ),
                           ),
                           // Labels
                           Column(
                             mainAxisAlignment: MainAxisAlignment.spaceBetween,
                             children: _uniqueYears.map((year) {
                               final isSelected = year == _currentActiveYear;
                               return AnimatedDefaultTextStyle(
                                 duration: const Duration(milliseconds: 200),
                                 style: HelloTypography.hint.copyWith(
                                   color: isSelected ? HelloColors.accent : HelloColors.inkTertiary.withOpacity(0.5),
                                   fontWeight: isSelected ? FontWeight.w800 : FontWeight.w300,
                                   fontSize: isSelected ? 14 : 11,
                                 ),
                                 child: Text(year),
                               );
                             }).toList(),
                           ),
                           // Moving Fire Thumb
                           Positioned(
                             top: _scrubValue * (constraints.maxHeight - 32),
                             child: Container(
                               width: 16,
                               height: 32,
                               decoration: BoxDecoration(
                                 color: HelloColors.accent,
                                 borderRadius: BorderRadius.circular(8),
                                 boxShadow: [
                                   BoxShadow(color: HelloColors.accent.withOpacity(0.6), blurRadius: 12, spreadRadius: 2)
                                 ]
                               ),
                             ),
                           )
                        ],
                      ),
                    ),
                  );
                }
              ),
            )
          ],
        ),
      ),
    );
  }
}

class _YearShelf extends StatefulWidget {
  final String year;
  final List<DecisionEvent> events;

  const _YearShelf({required this.year, required this.events});

  @override
  State<_YearShelf> createState() => _YearShelfState();
}

class _YearShelfState extends State<_YearShelf> {
  late PageController _horizontalController;

  @override
  void initState() {
    super.initState();
    // 0.85 fraction creates the cinematic "peeking" effect for adjacent cards
    _horizontalController = PageController(viewportFraction: 0.85); 
  }

  @override
  void dispose() {
    _horizontalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.events.isEmpty) {
      return Center(child: Text("No plans mapped in ${widget.year}"));
    }
  
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Huge Minimalist Year Watermark (Apple Scale)
        Align(
          alignment: Alignment.center,
          child: IgnorePointer(
            child: Text(
              widget.year,
              style: TextStyle(
                fontFamily: HelloTypography.primaryFont,
                fontSize: 180,
                fontWeight: FontWeight.w900,
                color: HelloColors.inkTertiary.withOpacity(0.04),
                letterSpacing: -12,
                height: 1.0,
              ),
            ),
          ),
        ),
        
        // Fluid Floating Netflix Cards
        Positioned.fill(
          child: PageView.builder(
            controller: _horizontalController,
            clipBehavior: Clip.none, // STOP Clipping Shadows!
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: widget.events.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0), // Micro padding, ViewportFraction handles the rest
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 3 / 4.4, // Guaranteed gorgeous cinematic ratio on any phone
                    child: _buildMilestoneCard(widget.events[index], context),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMilestoneCard(DecisionEvent event, BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: HelloColors.chrome,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
           BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 40, offset: const Offset(0, 20)),
        ],
        border: Border.all(color: HelloColors.inkTertiary.withOpacity(0.1), width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32), // Completely kills edge bleeding glitches
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch, // Force internal content to fill width
          children: [
            // Image takes all remaining height dynamically, preventing overflow
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: HelloColors.recessed,
                  image: DecorationImage(image: NetworkImage(event.imageUrl), fit: BoxFit.cover),
                ),
              ),
            ),
            
            // Text block sizes itself intrinsically to exact font contours
            Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min, // Hug content tightly
              children: [
                Row(
                  children: [
                    Text("SETTLED  •  ${event.month} ${event.year}", style: HelloTypography.label.copyWith(color: HelloColors.accent, letterSpacing: 1.5)),
                    const Spacer(),
                    const Icon(Icons.task_alt, color: Color(0xFF68DD8C), size: 16),
                  ],
                ),
                const SizedBox(height: 8),
                Text(event.title, style: HelloTypography.spaceTitle.copyWith(fontSize: 22, fontWeight: FontWeight.w600)),
                const SizedBox(height: 16), // Explicit spacing instead of SpaceBetween
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: HelloColors.voidBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: HelloColors.accent.withOpacity(0.3)),
                  ),
                  child: Center(
                    child: Text("Fork & Resurrect Plan", style: HelloTypography.body.copyWith(color: HelloColors.accent, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
          ],
        ),
      ),
    );
  }
}
