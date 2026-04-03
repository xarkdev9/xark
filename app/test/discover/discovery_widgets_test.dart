// hello Discovery Widgets — Flutter Widget Tests
// Tests: DiscoveryCarousel, ExploreTab, DiscoveryItemCard, CategoryChips,
//        DiscoverySuggestionCard, ErrorCard, FeedbackSheet

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:e2ee_chat_sdk/src/discovery/models/discovery_item.dart';
import 'package:e2ee_chat_sdk/src/discovery/models/carousel_card.dart';
import 'package:e2ee_chat_sdk/src/discovery/models/error_report.dart';
import 'package:hello_app/views/discover/discovery_carousel.dart';
import 'package:hello_app/views/discover/explore_tab.dart';
import 'package:hello_app/views/discover/discovery_item_card.dart';
import 'package:hello_app/views/discover/category_chips.dart';
import 'package:hello_app/views/discover/discovery_suggestion_card.dart';
import 'package:hello_app/views/discover/error_card.dart';
import 'package:hello_app/views/discover/feedback_sheet.dart';

// ── Test Helpers ──

Widget buildTestWidget(Widget child) {
  return MaterialApp(
    home: Scaffold(body: child),
  );
}

/// Wraps a widget in a constrained box suitable for card-style widgets
/// that expect to be placed inside a grid or list with limited dimensions.
Widget buildConstrainedCard(Widget child, {double width = 200, double height = 300}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: width,
          height: height,
          child: child,
        ),
      ),
    ),
  );
}

final DateTime _now = DateTime(2026, 4, 2, 10, 0);

final List<DiscoveryItem> testItems = [
  DiscoveryItem(
    id: 'test-1',
    title: 'Roscioli Salumeria',
    subtitle: 'Roman trattoria',
    category: DiscoveryCategory.restaurants,
    price: 45.0,
    currency: 'EUR',
    location: 'Rome, Italy',
    tasteScore: 0.92,
    tasteReason: 'Authentic Roman cuisine',
    source: 'catalog',
    fetchedAt: _now,
  ),
  DiscoveryItem(
    id: 'test-2',
    title: 'Hotel des Grands Boulevards',
    subtitle: 'Rooftop terrace in the 2nd',
    category: DiscoveryCategory.hotels,
    price: 220.0,
    currency: 'EUR',
    location: 'Paris, France',
    tasteScore: 0.87,
    source: 'catalog',
    fetchedAt: _now,
  ),
  DiscoveryItem(
    id: 'test-3',
    title: 'Sunrise Brooklyn Bridge Walk',
    subtitle: 'Golden hour over Manhattan',
    category: DiscoveryCategory.activities,
    price: 0.0,
    currency: 'USD',
    location: 'New York, USA',
    tasteScore: 0.94,
    tasteReason: 'Iconic NYC moment',
    source: 'editorial',
    fetchedAt: _now,
  ),
  DiscoveryItem(
    id: 'test-4',
    title: 'Barcelona Gothic Quarter Day',
    subtitle: 'Medieval lanes to beachfront sunset',
    category: DiscoveryCategory.dayPlans,
    price: 60.0,
    currency: 'EUR',
    location: 'Barcelona, Spain',
    tasteScore: 0.5,
    source: 'catalog',
    fetchedAt: _now,
  ),
  DiscoveryItem(
    id: 'test-5',
    title: 'Truffle Hunting in Tuscany',
    subtitle: 'Dogs, dirt, and diamonds',
    category: DiscoveryCategory.experiences,
    price: 150.0,
    currency: 'EUR',
    location: 'Tuscany, Italy',
    tasteScore: 0.3,
    tasteReason: 'Once-in-a-lifetime',
    source: 'gemini',
    fetchedAt: _now,
  ),
];

final List<CarouselCard> testCarouselCards = [
  CarouselCard(
    id: 'carousel-1',
    title: 'Trending Now',
    subtitle: 'Most loved across all categories',
    heroColor: '#FF6B35',
    category: DiscoveryCategory.activities,
    items: [testItems[0], testItems[2]],
    curationType: 'trending',
  ),
  CarouselCard(
    id: 'carousel-2',
    title: 'Day Plans',
    subtitle: 'Full days, zero planning stress',
    heroColor: '#4ECDC4',
    category: DiscoveryCategory.dayPlans,
    items: [testItems[3]],
    curationType: 'editorial',
  ),
];

final ErrorReport testErrorReport = ErrorReport(
  id: 'err-001',
  errorType: 'search_timeout',
  errorMessage: 'Discovery search timed out after 10s',
  occurredAt: _now,
);

// ═══════════════════════════════════════════
// DISCOVERY CAROUSEL
// ═══════════════════════════════════════════

void main() {
  group('DiscoveryCarousel', () {
    testWidgets('renders cards when provided', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        DiscoveryCarousel(cards: testCarouselCards),
      ));

      // Should find the card titles rendered in CarouselCardTile
      expect(find.text('Trending Now'), findsOneWidget);
      expect(find.text('Day Plans'), findsOneWidget);
    });

    testWidgets('returns SizedBox.shrink when empty', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        const DiscoveryCarousel(cards: []),
      ));

      // SizedBox.shrink has zero dimensions
      final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox).first);
      expect(sizedBox.width, 0.0);
      expect(sizedBox.height, 0.0);
    });

    testWidgets('card tap fires onItemTap callback', (tester) async {
      DiscoveryItem? tappedItem;

      await tester.pumpWidget(buildTestWidget(
        DiscoveryCarousel(
          cards: testCarouselCards,
          onItemTap: (item) => tappedItem = item,
        ),
      ));

      // Tap the first carousel card — CarouselCardTile taps fire onItemTap
      // with the first item in the card's items list
      await tester.tap(find.text('Trending Now'));
      await tester.pumpAndSettle();

      expect(tappedItem, isNotNull);
      expect(tappedItem!.id, testItems[0].id);
    });
  });

  // ═══════════════════════════════════════════
  // EXPLORE TAB
  // ═══════════════════════════════════════════

  group('ExploreTab', () {
    testWidgets('renders search bar', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        ExploreTab(items: testItems),
      ));

      // ExploreSearchBar has a TextField with this hint
      expect(find.text('Search places, activities...'), findsOneWidget);
    });

    testWidgets('renders category chips', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        ExploreTab(items: testItems),
      ));

      // CategoryChips renders "All" plus each DiscoveryCategory display name
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Restaurants'), findsOneWidget);
      expect(find.text('Hotels'), findsOneWidget);
      expect(find.text('Activities'), findsOneWidget);
    });

    testWidgets('renders item cards', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        ExploreTab(items: testItems),
      ));

      // DiscoveryItemCard renders the title of each item
      // Grid shows 2 columns, so scrolling may be needed for all,
      // but at least the first items should be visible
      expect(find.text('Roscioli Salumeria'), findsOneWidget);
    });

    testWidgets('loading state shows placeholders', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        const ExploreTab(items: [], isLoading: true),
      ));
      await tester.pump();

      // When loading, the shimmer grid shows 6 placeholder cards
      // Search bar should still be visible
      expect(find.text('Search places, activities...'), findsOneWidget);
      // No item cards should be present
      expect(find.text('Roscioli Salumeria'), findsNothing);
    });

    testWidgets('pull to refresh fires onRefresh', (tester) async {
      bool refreshFired = false;

      await tester.pumpWidget(buildTestWidget(
        ExploreTab(
          items: testItems,
          onRefresh: () => refreshFired = true,
        ),
      ));

      // The RefreshIndicator wraps the grid -- pull down to trigger
      await tester.fling(find.byType(GridView), const Offset(0, 300), 1000);
      await tester.pumpAndSettle();

      expect(refreshFired, isTrue);
    });
  });

  // ═══════════════════════════════════════════
  // DISCOVERY ITEM CARD
  // ═══════════════════════════════════════════

  group('DiscoveryItemCard', () {
    testWidgets('renders title and subtitle', (tester) async {
      await tester.pumpWidget(buildConstrainedCard(
        DiscoveryItemCard(item: testItems[0]),
      ));

      expect(find.text('Roscioli Salumeria'), findsOneWidget);
      expect(find.text('Roman trattoria'), findsOneWidget);
    });

    testWidgets('renders price when available', (tester) async {
      await tester.pumpWidget(buildConstrainedCard(
        DiscoveryItemCard(item: testItems[0]),
      ));

      // item has price 45 EUR, formatted as euro symbol + 45
      expect(find.textContaining('\u20ac45'), findsOneWidget);
    });

    testWidgets('shows taste score indicator dot', (tester) async {
      await tester.pumpWidget(buildConstrainedCard(
        DiscoveryItemCard(item: testItems[0]),
      ));

      // The taste dot is a Container with width:8 height:8 and BoxShape.circle
      // We look for it by finding decorated boxes with circle shape
      final dotFinder = find.byWidgetPredicate((widget) {
        if (widget is Container) {
          final deco = widget.decoration;
          if (deco is BoxDecoration && deco.shape == BoxShape.circle) {
            // Check the explicit width/height constraints
            final constraints = widget.constraints;
            if (constraints != null &&
                constraints.maxWidth == 8.0 &&
                constraints.maxHeight == 8.0) {
              return true;
            }
          }
        }
        return false;
      });
      expect(dotFinder, findsOneWidget);
    });

    testWidgets('tap fires onTap callback', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(buildConstrainedCard(
        DiscoveryItemCard(
          item: testItems[0],
          onTap: () => tapped = true,
        ),
      ));

      await tester.tap(find.byType(GestureDetector).first);
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('shows source badge', (tester) async {
      // testItems[0] has source 'catalog', which maps to 'curated'
      await tester.pumpWidget(buildConstrainedCard(
        DiscoveryItemCard(item: testItems[0]),
      ));

      expect(find.text('curated'), findsOneWidget);
    });

    testWidgets('shows taste reason when available', (tester) async {
      await tester.pumpWidget(buildConstrainedCard(
        DiscoveryItemCard(item: testItems[0]),
      ));

      expect(find.text('Authentic Roman cuisine'), findsOneWidget);
    });
  });

  // ═══════════════════════════════════════════
  // CATEGORY CHIPS
  // ═══════════════════════════════════════════

  group('CategoryChips', () {
    testWidgets('renders all category labels plus "All"', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        const CategoryChips(),
      ));

      // "All" and the first several categories are visible
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Restaurants'), findsOneWidget);
      expect(find.text('Hotels'), findsOneWidget);
      expect(find.text('Activities'), findsOneWidget);
      expect(find.text('Destinations'), findsOneWidget);
      expect(find.text('Day Plans'), findsOneWidget);

      // "Experiences" may be off-screen in the horizontal ListView.
      // Scroll right to reveal it.
      await tester.scrollUntilVisible(
        find.text('Experiences'),
        50.0,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Experiences'), findsOneWidget);
    });

    testWidgets('tap fires onSelected with correct category', (tester) async {
      DiscoveryCategory? selectedCategory;

      await tester.pumpWidget(buildTestWidget(
        CategoryChips(
          onSelected: (cat) => selectedCategory = cat,
        ),
      ));

      await tester.tap(find.text('Hotels'));
      await tester.pump();

      expect(selectedCategory, DiscoveryCategory.hotels);
    });

    testWidgets('"All" chip fires onSelected with null', (tester) async {
      DiscoveryCategory? selectedCategory = DiscoveryCategory.hotels;
      bool wasCalled = false;

      await tester.pumpWidget(buildTestWidget(
        CategoryChips(
          selected: DiscoveryCategory.hotels,
          onSelected: (cat) {
            selectedCategory = cat;
            wasCalled = true;
          },
        ),
      ));

      await tester.tap(find.text('All'));
      await tester.pump();

      expect(wasCalled, isTrue);
      expect(selectedCategory, isNull);
    });
  });

  // ═══════════════════════════════════════════
  // DISCOVERY SUGGESTION CARD
  // ═══════════════════════════════════════════

  group('DiscoverySuggestionCard', () {
    testWidgets('renders "@hello suggests" label', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        DiscoverySuggestionCard(suggestions: testItems.take(2).toList()),
      ));

      expect(find.text('@hello suggests'), findsOneWidget);
    });

    testWidgets('renders suggestion items', (tester) async {
      final suggestions = testItems.take(3).toList();
      await tester.pumpWidget(buildTestWidget(
        DiscoverySuggestionCard(suggestions: suggestions),
      ));

      // Each suggestion row shows the item title
      expect(find.text('Roscioli Salumeria'), findsOneWidget);
      expect(find.text('Hotel des Grands Boulevards'), findsOneWidget);
      expect(find.text('Sunrise Brooklyn Bridge Walk'), findsOneWidget);
    });

    testWidgets('"Add to board" tap fires onAdd', (tester) async {
      DiscoveryItem? addedItem;

      await tester.pumpWidget(buildTestWidget(
        DiscoverySuggestionCard(
          suggestions: [testItems[0]],
          onAdd: (item) => addedItem = item,
        ),
      ));

      // The "Add" button text in _SuggestionRow
      await tester.tap(find.text('Add'));
      await tester.pump();

      expect(addedItem, isNotNull);
      expect(addedItem!.id, 'test-1');
    });

    testWidgets('"Not now" tap fires onDismiss', (tester) async {
      bool dismissed = false;

      await tester.pumpWidget(buildTestWidget(
        DiscoverySuggestionCard(
          suggestions: [testItems[0]],
          onDismiss: () => dismissed = true,
        ),
      ));

      await tester.tap(find.text('Not now'));
      await tester.pump();

      expect(dismissed, isTrue);
    });

    testWidgets('returns SizedBox.shrink when suggestions empty', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        const DiscoverySuggestionCard(suggestions: []),
      ));

      final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox).first);
      expect(sizedBox.width, 0.0);
      expect(sizedBox.height, 0.0);
    });

    testWidgets('limits to 3 suggestions even if more provided', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        DiscoverySuggestionCard(suggestions: testItems),
      ));

      // 5 items provided but only 3 should render
      expect(find.text('Roscioli Salumeria'), findsOneWidget);
      expect(find.text('Hotel des Grands Boulevards'), findsOneWidget);
      expect(find.text('Sunrise Brooklyn Bridge Walk'), findsOneWidget);
      expect(find.text('Barcelona Gothic Quarter Day'), findsNothing);
      expect(find.text('Truffle Hunting in Tuscany'), findsNothing);
    });
  });

  // ═══════════════════════════════════════════
  // ERROR CARD
  // ═══════════════════════════════════════════

  group('ErrorCard', () {
    // ErrorCard has an auto-dismiss Future.delayed timer in initState.
    // We use a short autoDismissAfter and pump past it to flush the timer.

    testWidgets('renders error message', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        const ErrorCard(
          message: 'Something went wrong',
          autoDismissAfter: Duration(milliseconds: 50),
        ),
      ));

      expect(find.text('Something went wrong'), findsOneWidget);

      // Flush the auto-dismiss timer
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 500));
    });

    testWidgets('renders error type when provided', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        const ErrorCard(
          message: 'Search failed',
          errorType: 'search_timeout',
          autoDismissAfter: Duration(milliseconds: 50),
        ),
      ));

      expect(find.text('search_timeout'), findsOneWidget);
      expect(find.text('Search failed'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 500));
    });

    testWidgets('"Report this" tap fires onReport', (tester) async {
      bool reported = false;

      await tester.pumpWidget(buildTestWidget(
        ErrorCard(
          message: 'Something broke',
          onReport: () => reported = true,
          autoDismissAfter: const Duration(milliseconds: 50),
        ),
      ));

      await tester.tap(find.text('Report this'));
      await tester.pump();

      expect(reported, isTrue);

      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 500));
    });

    testWidgets('"Retry" button fires onRetry when provided', (tester) async {
      bool retried = false;

      await tester.pumpWidget(buildTestWidget(
        ErrorCard(
          message: 'Network error',
          onRetry: () => retried = true,
          autoDismissAfter: const Duration(milliseconds: 50),
        ),
      ));

      await tester.tap(find.text('Retry'));
      await tester.pump();

      expect(retried, isTrue);

      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 500));
    });

    testWidgets('does not show Retry when onRetry is null', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        const ErrorCard(
          message: 'Some error',
          autoDismissAfter: Duration(milliseconds: 50),
        ),
      ));

      expect(find.text('Retry'), findsNothing);

      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 500));
    });

    testWidgets('does not show Report this when onReport is null', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        const ErrorCard(
          message: 'Some error',
          autoDismissAfter: Duration(milliseconds: 50),
        ),
      ));

      expect(find.text('Report this'), findsNothing);

      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 500));
    });
  });

  // ═══════════════════════════════════════════
  // FEEDBACK SHEET
  // ═══════════════════════════════════════════

  group('FeedbackSheet', () {
    testWidgets('renders error context when provided', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        FeedbackSheet(errorReport: testErrorReport),
      ));

      // The error context is displayed in _contextRow widgets
      expect(find.text('Type'), findsOneWidget);
      expect(find.text('search_timeout'), findsOneWidget);
      expect(find.text('Message'), findsOneWidget);
      expect(find.text('Discovery search timed out after 10s'), findsOneWidget);
    });

    testWidgets('text field accepts input', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        FeedbackSheet(errorReport: testErrorReport),
      ));

      // Find the TextField with the hint text
      final textField = find.byType(TextField);
      expect(textField, findsOneWidget);

      await tester.enterText(textField, 'I was searching for restaurants');
      await tester.pump();

      expect(find.text('I was searching for restaurants'), findsOneWidget);
    });

    testWidgets('"Send Report" fires onSubmit with description', (tester) async {
      String? submittedDescription;

      // FeedbackSheet._submit calls Navigator.pop() after submission,
      // which requires a route context. Wrap with a pushed route.
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => Scaffold(
                      body: FeedbackSheet(
                        errorReport: testErrorReport,
                        onSubmit: (desc) => submittedDescription = desc,
                      ),
                    ),
                  ),
                );
              },
              child: const Text('Open Sheet'),
            ),
          ),
        ),
      ));

      // Push the route with FeedbackSheet
      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      // Enter text and tap Send Report
      await tester.enterText(find.byType(TextField), 'Search was stuck');
      await tester.pump();

      await tester.tap(find.text('Send Report'));
      await tester.pump();

      expect(submittedDescription, 'Search was stuck');

      // Advance time past the 2-second auto-close Future.delayed
      // to prevent pending timer warnings
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('renders "Report an issue" title', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        const FeedbackSheet(),
      ));

      expect(find.text('Report an issue'), findsOneWidget);
    });

    testWidgets('renders "What happened?" label', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        const FeedbackSheet(),
      ));

      expect(find.text('What happened?'), findsOneWidget);
    });

    testWidgets('does not submit when description is empty', (tester) async {
      String? submittedDescription;

      await tester.pumpWidget(buildTestWidget(
        FeedbackSheet(
          onSubmit: (desc) => submittedDescription = desc,
        ),
      ));

      // Tap Send Report without entering text
      await tester.tap(find.text('Send Report'));
      await tester.pump();

      // The _submit method returns early if description is empty
      expect(submittedDescription, isNull);
    });
  });
}
