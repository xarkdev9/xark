// ignore_for_file: prefer_const_constructors

import 'package:e2ee_chat_sdk/src/discovery/models/carousel_card.dart';
import 'package:e2ee_chat_sdk/src/discovery/models/discovery_filter.dart';
import 'package:e2ee_chat_sdk/src/discovery/models/discovery_item.dart';
import 'package:e2ee_chat_sdk/src/discovery/models/discovery_item_detail.dart';
import 'package:e2ee_chat_sdk/src/discovery/models/error_report.dart';
import 'package:e2ee_chat_sdk/src/discovery/models/taste_profile.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds a test [DiscoveryItem] with sensible defaults and overridable fields.
DiscoveryItem makeItem({
  String id = 'item-1',
  String title = 'Test Item',
  String? subtitle,
  DiscoveryCategory category = DiscoveryCategory.restaurants,
  String? imageUrl,
  String? description,
  double? price,
  String? currency,
  String? location,
  Map<String, dynamic> metadata = const {},
  double tasteScore = 0.0,
  String? tasteReason,
  String source = 'test',
  DateTime? fetchedAt,
}) {
  return DiscoveryItem(
    id: id,
    title: title,
    subtitle: subtitle,
    category: category,
    imageUrl: imageUrl,
    description: description,
    price: price,
    currency: currency,
    location: location,
    metadata: metadata,
    tasteScore: tasteScore,
    tasteReason: tasteReason,
    source: source,
    fetchedAt: fetchedAt ?? DateTime.utc(2026, 4, 1),
  );
}

void main() {
  // ---------------------------------------------------------------------------
  // DiscoveryItem
  // ---------------------------------------------------------------------------
  group('DiscoveryItem', () {
    test('construction with required fields only', () {
      final item = DiscoveryItem(
        id: 'abc-123',
        title: 'Pasta Place',
        category: DiscoveryCategory.restaurants,
        source: 'apify',
        fetchedAt: DateTime.utc(2026, 4, 1),
      );

      expect(item.id, 'abc-123');
      expect(item.title, 'Pasta Place');
      expect(item.category, DiscoveryCategory.restaurants);
      expect(item.source, 'apify');
      expect(item.fetchedAt, DateTime.utc(2026, 4, 1));
    });

    test('default values: tasteScore=0, metadata={}, optional fields null', () {
      final item = makeItem();

      expect(item.tasteScore, 0.0);
      expect(item.metadata, const <String, dynamic>{});
      expect(item.subtitle, isNull);
      expect(item.imageUrl, isNull);
      expect(item.description, isNull);
      expect(item.price, isNull);
      expect(item.currency, isNull);
      expect(item.location, isNull);
      expect(item.tasteReason, isNull);
    });

    test('equality is based on id only', () {
      final a = makeItem(id: 'same-id', title: 'Title A', price: 10.0);
      final b = makeItem(id: 'same-id', title: 'Title B', price: 99.0);
      final c = makeItem(id: 'different-id', title: 'Title A', price: 10.0);

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });

    test('toString contains id, title, category, tasteScore, source', () {
      final item = makeItem(
        id: 'x-1',
        title: 'Sushi Bar',
        category: DiscoveryCategory.restaurants,
        tasteScore: 0.85,
        source: 'editorial',
      );

      final str = item.toString();

      expect(str, contains('x-1'));
      expect(str, contains('Sushi Bar'));
      expect(str, contains('restaurants'));
      expect(str, contains('0.85'));
      expect(str, contains('editorial'));
    });

    test('copyWith replaces specified fields and preserves others', () {
      final original = makeItem(
        id: 'orig',
        title: 'Original',
        category: DiscoveryCategory.hotels,
        price: 100.0,
        currency: 'EUR',
        tasteScore: 0.3,
        source: 'gemini',
      );

      final copied = original.copyWith(
        title: 'Updated',
        tasteScore: 0.9,
        tasteReason: 'Matches your love of hotels',
      );

      // Changed fields.
      expect(copied.title, 'Updated');
      expect(copied.tasteScore, 0.9);
      expect(copied.tasteReason, 'Matches your love of hotels');

      // Preserved fields.
      expect(copied.id, 'orig');
      expect(copied.category, DiscoveryCategory.hotels);
      expect(copied.price, 100.0);
      expect(copied.currency, 'EUR');
      expect(copied.source, 'gemini');
    });

    test('copyWith with no arguments returns an equal (but distinct) item', () {
      final original = makeItem(id: 'copy-test', title: 'Unchanged');
      final copied = original.copyWith();

      expect(copied, equals(original));
      expect(copied.title, original.title);
      expect(copied.source, original.source);
    });

    test('metadata with tags and nested data preserved', () {
      final item = makeItem(
        metadata: {
          'tags': ['italian', 'seafood'],
          'dietary': ['vegetarian'],
          'rating': 4.5,
        },
      );

      expect(item.metadata['tags'], ['italian', 'seafood']);
      expect(item.metadata['dietary'], ['vegetarian']);
      expect(item.metadata['rating'], 4.5);
    });
  });

  // ---------------------------------------------------------------------------
  // CarouselCard
  // ---------------------------------------------------------------------------
  group('CarouselCard', () {
    test('construction with all required fields', () {
      final items = [
        makeItem(id: 'c-1', title: 'Item 1'),
        makeItem(id: 'c-2', title: 'Item 2'),
        makeItem(id: 'c-3', title: 'Item 3'),
      ];

      final card = CarouselCard(
        id: 'card-1',
        title: 'Top Pasta in Rome',
        subtitle: 'Based on your taste',
        imageUrl: 'https://example.com/hero.jpg',
        heroColor: '#FF6B35',
        category: DiscoveryCategory.restaurants,
        items: items,
        curationType: 'taste_match',
      );

      expect(card.id, 'card-1');
      expect(card.title, 'Top Pasta in Rome');
      expect(card.subtitle, 'Based on your taste');
      expect(card.imageUrl, 'https://example.com/hero.jpg');
      expect(card.heroColor, '#FF6B35');
      expect(card.category, DiscoveryCategory.restaurants);
      expect(card.items, hasLength(3));
      expect(card.curationType, 'taste_match');
    });

    test('items list contains correct DiscoveryItems', () {
      final items = [
        makeItem(id: 'a', title: 'Alpha'),
        makeItem(id: 'b', title: 'Beta'),
      ];

      final card = CarouselCard(
        id: 'card-items',
        title: 'Test Card',
        heroColor: '#000000',
        category: DiscoveryCategory.activities,
        items: items,
        curationType: 'editorial',
      );

      expect(card.items.map((i) => i.id).toList(), ['a', 'b']);
      expect(card.items.first.title, 'Alpha');
    });

    test('equality by id', () {
      final cardA = CarouselCard(
        id: 'same',
        title: 'Card A',
        heroColor: '#111',
        category: DiscoveryCategory.restaurants,
        items: [],
        curationType: 'trending',
      );
      final cardB = CarouselCard(
        id: 'same',
        title: 'Card B',
        heroColor: '#222',
        category: DiscoveryCategory.hotels,
        items: [makeItem()],
        curationType: 'seasonal',
      );
      final cardC = CarouselCard(
        id: 'different',
        title: 'Card A',
        heroColor: '#111',
        category: DiscoveryCategory.restaurants,
        items: [],
        curationType: 'trending',
      );

      expect(cardA, equals(cardB));
      expect(cardA.hashCode, cardB.hashCode);
      expect(cardA, isNot(equals(cardC)));
    });

    test('toString contains id, title, category, curationType, items count',
        () {
      final card = CarouselCard(
        id: 'card-str',
        title: 'Seafood Picks',
        heroColor: '#0066CC',
        category: DiscoveryCategory.restaurants,
        items: [makeItem(), makeItem(id: 'item-2')],
        curationType: 'taste_match',
      );

      final str = card.toString();

      expect(str, contains('card-str'));
      expect(str, contains('Seafood Picks'));
      expect(str, contains('restaurants'));
      expect(str, contains('taste_match'));
      expect(str, contains('2'));
    });

    test('optional subtitle and imageUrl default to null', () {
      final card = CarouselCard(
        id: 'minimal',
        title: 'Minimal Card',
        heroColor: '#FFF',
        category: DiscoveryCategory.dayPlans,
        items: [],
        curationType: 'editorial',
      );

      expect(card.subtitle, isNull);
      expect(card.imageUrl, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // DiscoveryItemDetail
  // ---------------------------------------------------------------------------
  group('DiscoveryItemDetail', () {
    test('composition: wraps a DiscoveryItem with extended fields', () {
      final item = makeItem(id: 'detail-1', title: 'Great Restaurant');
      final detail = DiscoveryItemDetail(
        item: item,
        longDescription: 'An amazing restaurant in the heart of Rome.',
        imageUrls: [
          'https://example.com/1.jpg',
          'https://example.com/2.jpg',
        ],
        hours: {'monday': '9:00-22:00', 'tuesday': '9:00-22:00'},
        website: 'https://example.com',
        phone: '+1-555-0100',
        rating: 4.7,
        reviewCount: 342,
        tags: ['outdoor', 'family-friendly', 'rooftop'],
        aiSummary: 'cozy italian spot with great rooftop views',
      );

      expect(detail.item, equals(item));
      expect(detail.item.id, 'detail-1');
      expect(detail.longDescription,
          'An amazing restaurant in the heart of Rome.');
      expect(detail.imageUrls, hasLength(2));
      expect(detail.hours, isNotNull);
      expect(detail.hours!['monday'], '9:00-22:00');
      expect(detail.website, 'https://example.com');
      expect(detail.phone, '+1-555-0100');
      expect(detail.rating, closeTo(4.7, 0.01));
      expect(detail.reviewCount, 342);
      expect(detail.tags, ['outdoor', 'family-friendly', 'rooftop']);
      expect(detail.aiSummary, contains('rooftop'));
    });

    test('default values: imageUrls=[], tags=[], optionals null', () {
      final detail = DiscoveryItemDetail(item: makeItem());

      expect(detail.imageUrls, isEmpty);
      expect(detail.tags, isEmpty);
      expect(detail.longDescription, isNull);
      expect(detail.hours, isNull);
      expect(detail.website, isNull);
      expect(detail.phone, isNull);
      expect(detail.rating, isNull);
      expect(detail.reviewCount, isNull);
      expect(detail.aiSummary, isNull);
    });

    test('equality based on inner item id', () {
      final itemA = makeItem(id: 'same-detail');
      final itemB = makeItem(id: 'same-detail', title: 'Different Title');

      final detailA = DiscoveryItemDetail(item: itemA, rating: 4.0);
      final detailB =
          DiscoveryItemDetail(item: itemB, rating: 2.0, reviewCount: 99);

      expect(detailA, equals(detailB));
      expect(detailA.hashCode, detailB.hashCode);
    });

    test('inequality when inner items have different ids', () {
      final detailA = DiscoveryItemDetail(item: makeItem(id: 'x'));
      final detailB = DiscoveryItemDetail(item: makeItem(id: 'y'));

      expect(detailA, isNot(equals(detailB)));
    });

    test('toString contains item id, rating, reviewCount, tags', () {
      final detail = DiscoveryItemDetail(
        item: makeItem(id: 'str-test'),
        rating: 3.5,
        reviewCount: 100,
        tags: ['wifi', 'pet-friendly'],
      );

      final str = detail.toString();

      expect(str, contains('str-test'));
      expect(str, contains('3.5'));
      expect(str, contains('100'));
      expect(str, contains('wifi'));
      expect(str, contains('pet-friendly'));
    });
  });

  // ---------------------------------------------------------------------------
  // ErrorReport
  // ---------------------------------------------------------------------------
  group('ErrorReport', () {
    test('construction with all fields', () {
      final now = DateTime.utc(2026, 4, 1);
      final report = ErrorReport(
        id: 'err-1',
        errorType: 'network_timeout',
        errorMessage: 'Request timed out after 30s',
        context: {'url': '/api/feed', 'method': 'GET'},
        occurredAt: now,
      );

      expect(report.id, 'err-1');
      expect(report.errorType, 'network_timeout');
      expect(report.errorMessage, 'Request timed out after 30s');
      expect(report.context['url'], '/api/feed');
      expect(report.context['method'], 'GET');
      expect(report.occurredAt, now);
      expect(report.synced, isFalse);
      expect(report.userDescription, isNull);
    });

    test('default values: synced=false, context={}, userDescription=null', () {
      final report = ErrorReport(
        id: 'err-default',
        errorType: 'parse_error',
        errorMessage: 'Invalid JSON',
        occurredAt: DateTime.utc(2026, 4, 1),
      );

      expect(report.synced, isFalse);
      expect(report.context, const <String, dynamic>{});
      expect(report.userDescription, isNull);
    });

    test('copyWith: update synced flag', () {
      final report = ErrorReport(
        id: 'err-sync',
        errorType: 'api_error',
        errorMessage: 'Server returned 500',
        occurredAt: DateTime.utc(2026, 4, 1),
      );

      final synced = report.copyWith(synced: true);

      expect(synced.synced, isTrue);
      expect(synced.id, report.id);
      expect(synced.errorType, report.errorType);
      expect(synced.errorMessage, report.errorMessage);
    });

    test('copyWith: add userDescription', () {
      final report = ErrorReport(
        id: 'err-desc',
        errorType: 'search_timeout',
        errorMessage: 'Search took too long',
        occurredAt: DateTime.utc(2026, 4, 1),
      );

      final withDesc = report.copyWith(
        userDescription: 'I was searching for restaurants near me',
      );

      expect(
        withDesc.userDescription,
        'I was searching for restaurants near me',
      );
      expect(withDesc.id, report.id);
      expect(withDesc.synced, isFalse);
    });

    test('copyWith: update both synced and userDescription', () {
      final report = ErrorReport(
        id: 'err-both',
        errorType: 'timeout',
        errorMessage: 'Connection lost',
        occurredAt: DateTime.utc(2026, 4, 1),
      );

      final updated = report.copyWith(
        synced: true,
        userDescription: 'Was loading the feed',
      );

      expect(updated.synced, isTrue);
      expect(updated.userDescription, 'Was loading the feed');
    });

    test('equality by id', () {
      final a = ErrorReport(
        id: 'same-err',
        errorType: 'type-a',
        errorMessage: 'msg-a',
        occurredAt: DateTime.utc(2026, 1, 1),
      );
      final b = ErrorReport(
        id: 'same-err',
        errorType: 'type-b',
        errorMessage: 'msg-b',
        occurredAt: DateTime.utc(2026, 12, 31),
      );

      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('toString contains id, errorType, synced, occurredAt', () {
      final report = ErrorReport(
        id: 'err-str',
        errorType: 'rate_limit',
        errorMessage: 'Too many requests',
        occurredAt: DateTime.utc(2026, 4, 1, 12, 30),
        synced: true,
      );

      final str = report.toString();

      expect(str, contains('err-str'));
      expect(str, contains('rate_limit'));
      expect(str, contains('true'));
    });
  });

  // ---------------------------------------------------------------------------
  // TasteProfile
  // ---------------------------------------------------------------------------
  group('TasteProfile', () {
    test('construction with all fields', () {
      final profile = TasteProfile(
        hardConstraints: {
          'dietary': ['vegetarian'],
          'allergies': ['nuts', 'shellfish'],
        },
        implicitWeights: {'restaurants': 0.8, 'activities': 0.6},
        tagWeights: {'italian': 5.0, 'seafood': 3.0},
        priceMin: 15.0,
        priceMax: 60.0,
        dismissedItemIds: ['d-1', 'd-2'],
        savedItemIds: ['s-1'],
      );

      expect(profile.hardConstraints, hasLength(2));
      expect(profile.hardConstraints['dietary'], ['vegetarian']);
      expect(profile.hardConstraints['allergies'], ['nuts', 'shellfish']);
      expect(profile.implicitWeights['restaurants'], 0.8);
      expect(profile.implicitWeights['activities'], 0.6);
      expect(profile.tagWeights['italian'], 5.0);
      expect(profile.tagWeights['seafood'], 3.0);
      expect(profile.priceMin, 15.0);
      expect(profile.priceMax, 60.0);
      expect(profile.dismissedItemIds, ['d-1', 'd-2']);
      expect(profile.savedItemIds, ['s-1']);
    });

    test('TasteProfile.empty has correct defaults', () {
      final empty = TasteProfile.empty;

      expect(empty.hardConstraints, isEmpty);
      expect(empty.implicitWeights, isEmpty);
      expect(empty.tagWeights, isEmpty);
      expect(empty.priceMin, isNull);
      expect(empty.priceMax, isNull);
      expect(empty.dismissedItemIds, isEmpty);
      expect(empty.savedItemIds, isEmpty);
    });

    test('hardConstraints: multiple categories with multiple values', () {
      final profile = TasteProfile(
        hardConstraints: {
          'dietary': ['vegetarian', 'vegan'],
          'allergies': ['peanuts'],
          'accessibility': ['wheelchair'],
        },
      );

      expect(profile.hardConstraints, hasLength(3));
      expect(
        profile.hardConstraints['dietary'],
        containsAll(['vegetarian', 'vegan']),
      );
      expect(profile.hardConstraints['allergies'], ['peanuts']);
      expect(profile.hardConstraints['accessibility'], ['wheelchair']);
    });

    test('implicitWeights: values are within 0.0-1.0 range by convention', () {
      final profile = TasteProfile(
        implicitWeights: {
          'restaurants': 0.0,
          'hotels': 0.5,
          'activities': 1.0,
        },
      );

      for (final weight in profile.implicitWeights.values) {
        expect(weight, greaterThanOrEqualTo(0.0));
        expect(weight, lessThanOrEqualTo(1.0));
      }
    });

    test('tagWeights: can accumulate above 1.0 from multiple signals', () {
      final profile = TasteProfile(
        tagWeights: {
          'italian': 12.0,
          'seafood': 0.5,
          'outdoor': -2.0,
        },
      );

      expect(profile.tagWeights['italian'], 12.0);
      expect(profile.tagWeights['outdoor'], -2.0);
    });

    test('copyWith replaces specific fields', () {
      final original = TasteProfile(
        priceMin: 10.0,
        priceMax: 50.0,
        tagWeights: {'italian': 3.0},
      );

      final updated = original.copyWith(
        priceMax: 100.0,
        dismissedItemIds: ['x-1'],
      );

      expect(updated.priceMin, 10.0);
      expect(updated.priceMax, 100.0);
      expect(updated.tagWeights, {'italian': 3.0});
      expect(updated.dismissedItemIds, ['x-1']);
    });

    test('toString summarizes counts', () {
      final profile = TasteProfile(
        hardConstraints: {
          'dietary': ['vegan'],
        },
        implicitWeights: {'restaurants': 0.8},
        tagWeights: {'a': 1, 'b': 2, 'c': 3},
        dismissedItemIds: ['d1', 'd2'],
        savedItemIds: ['s1'],
      );

      final str = profile.toString();

      // Constraints count.
      expect(str, contains('constraints: 1'));
      // Weights count.
      expect(str, contains('weights: 1'));
      // Tags count.
      expect(str, contains('tags: 3'));
      // Dismissed count.
      expect(str, contains('dismissed: 2'));
      // Saved count.
      expect(str, contains('saved: 1'));
    });
  });

  // ---------------------------------------------------------------------------
  // DiscoveryFilter
  // ---------------------------------------------------------------------------
  group('DiscoveryFilter', () {
    test('default values: limit=20, offset=0, optionals null', () {
      final filter = DiscoveryFilter();

      expect(filter.limit, 20);
      expect(filter.offset, 0);
      expect(filter.query, isNull);
      expect(filter.category, isNull);
      expect(filter.location, isNull);
      expect(filter.excludeIds, isNull);
    });

    test('construction with all fields', () {
      final filter = DiscoveryFilter(
        query: 'pasta in Rome',
        category: DiscoveryCategory.restaurants,
        location: 'Trastevere',
        limit: 10,
        offset: 20,
        excludeIds: ['ex-1', 'ex-2'],
      );

      expect(filter.query, 'pasta in Rome');
      expect(filter.category, DiscoveryCategory.restaurants);
      expect(filter.location, 'Trastevere');
      expect(filter.limit, 10);
      expect(filter.offset, 20);
      expect(filter.excludeIds, ['ex-1', 'ex-2']);
    });

    test('copyWith replaces specified fields and preserves others', () {
      final original = DiscoveryFilter(
        query: 'sushi',
        category: DiscoveryCategory.restaurants,
        limit: 10,
      );

      final updated = original.copyWith(
        offset: 10,
        limit: 25,
      );

      expect(updated.query, 'sushi');
      expect(updated.category, DiscoveryCategory.restaurants);
      expect(updated.limit, 25);
      expect(updated.offset, 10);
    });

    test('toString contains query, category, location, limit, offset', () {
      final filter = DiscoveryFilter(
        query: 'pizza',
        category: DiscoveryCategory.restaurants,
        location: 'Rome',
        limit: 15,
        offset: 5,
      );

      final str = filter.toString();

      expect(str, contains('pizza'));
      expect(str, contains('restaurants'));
      expect(str, contains('Rome'));
      expect(str, contains('15'));
      expect(str, contains('5'));
    });
  });

  // ---------------------------------------------------------------------------
  // DiscoveryCategory enum
  // ---------------------------------------------------------------------------
  group('DiscoveryCategory enum', () {
    test('has exactly 6 values', () {
      expect(DiscoveryCategory.values, hasLength(6));
    });

    test('contains all expected values', () {
      expect(
        DiscoveryCategory.values,
        containsAll([
          DiscoveryCategory.restaurants,
          DiscoveryCategory.hotels,
          DiscoveryCategory.activities,
          DiscoveryCategory.destinations,
          DiscoveryCategory.dayPlans,
          DiscoveryCategory.experiences,
        ]),
      );
    });

    test('each value has a distinct name', () {
      final names = DiscoveryCategory.values.map((v) => v.name).toSet();
      expect(names, hasLength(6));
    });
  });

  // ---------------------------------------------------------------------------
  // DiscoveryState enum
  // ---------------------------------------------------------------------------
  group('DiscoveryState enum', () {
    test('has exactly 4 values', () {
      expect(DiscoveryState.values, hasLength(4));
    });

    test('contains all expected values', () {
      expect(
        DiscoveryState.values,
        containsAll([
          DiscoveryState.loading,
          DiscoveryState.ready,
          DiscoveryState.error,
          DiscoveryState.offline,
        ]),
      );
    });

    test('each value has a distinct name', () {
      final names = DiscoveryState.values.map((v) => v.name).toSet();
      expect(names, hasLength(4));
    });
  });
}
