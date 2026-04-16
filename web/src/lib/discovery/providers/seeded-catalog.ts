import type { DiscoveryProvider } from '../provider-registry';
import type {
  DiscoveryCategory,
  DiscoveryItem,
  DiscoveryItemDetail,
} from '../types';

const MOCK_ITEMS: DiscoveryItem[] = [
  // Restaurants — Rome
  {
    id: 'seed-rest-001',
    title: 'Roscioli Salumeria con Cucina',
    subtitle: 'Roman trattoria meets gourmet deli',
    category: 'restaurants',
    imageUrl: 'https://images.unsplash.com/photo-discovery-placeholder?rome-roscioli',
    description:
      'Legendary salumeria in the heart of Centro Storico. Handmade pasta, curated Italian wines, and a cheese counter that could make you weep.',
    price: 45,
    currency: 'EUR',
    location: 'Rome, Italy',
    metadata: { cuisine: 'Italian', neighborhood: 'Centro Storico', michelin: false },
    tasteScore: 92,
    tasteReason: 'Authentic Roman cuisine with exceptional ingredients',
    source: 'seeded_catalog',
    fetchedAt: new Date().toISOString(),
  },
  {
    id: 'seed-rest-002',
    title: 'Da Enzo al 29',
    subtitle: 'Trastevere classic, no reservations',
    category: 'restaurants',
    imageUrl: 'https://images.unsplash.com/photo-discovery-placeholder?rome-daenzo',
    description:
      'Queue-worthy Trastevere trattoria known for cacio e pepe and carbonara. Cash only, zero pretense, maximum flavor.',
    price: 25,
    currency: 'EUR',
    location: 'Rome, Italy',
    metadata: { cuisine: 'Roman', neighborhood: 'Trastevere', cashOnly: true },
    tasteScore: 88,
    tasteReason: 'Unpretentious Roman comfort food at its peak',
    source: 'seeded_catalog',
    fetchedAt: new Date().toISOString(),
  },
  {
    id: 'seed-rest-003',
    title: 'Armando al Pantheon',
    subtitle: 'Family-run since 1961',
    category: 'restaurants',
    imageUrl: 'https://images.unsplash.com/photo-discovery-placeholder?rome-armando',
    description:
      'Three generations of Roman cooking steps from the Pantheon. The abbacchio and artichokes are non-negotiable.',
    price: 40,
    currency: 'EUR',
    location: 'Rome, Italy',
    metadata: { cuisine: 'Roman', neighborhood: 'Pigna', yearFounded: 1961 },
    tasteScore: 90,
    tasteReason: 'Heritage Roman dining with soul',
    source: 'seeded_catalog',
    fetchedAt: new Date().toISOString(),
  },

  // Hotels — Paris
  {
    id: 'seed-hotel-001',
    title: 'Hotel des Grands Boulevards',
    subtitle: 'Rooftop terrace in the 2nd',
    category: 'hotels',
    imageUrl: 'https://images.unsplash.com/photo-discovery-placeholder?paris-grands-boulevards',
    description:
      'An 18th-century mansion turned boutique hotel. Lush rooftop bar, Italian restaurant, and rooms that feel like a Parisian apartment you wish you owned.',
    price: 220,
    currency: 'EUR',
    location: 'Paris, France',
    metadata: { stars: 4, neighborhood: '2nd Arrondissement', rooftop: true },
    tasteScore: 87,
    tasteReason: 'Design-forward boutique with genuine neighborhood feel',
    source: 'seeded_catalog',
    fetchedAt: new Date().toISOString(),
  },
  {
    id: 'seed-hotel-002',
    title: 'Le Pigalle',
    subtitle: 'South Pigalle neighborhood hotel',
    category: 'hotels',
    imageUrl: 'https://images.unsplash.com/photo-discovery-placeholder?paris-lepigalle',
    description:
      'A love letter to SoPi. Vinyl collections in-room, local coffee partnerships, and a lobby bar that doubles as the neighborhood living room.',
    price: 180,
    currency: 'EUR',
    location: 'Paris, France',
    metadata: { stars: 4, neighborhood: 'South Pigalle', vinylInRoom: true },
    tasteScore: 85,
    tasteReason: 'Hyper-local immersion with impeccable taste',
    source: 'seeded_catalog',
    fetchedAt: new Date().toISOString(),
  },
  {
    id: 'seed-hotel-003',
    title: 'Hotel Monge',
    subtitle: 'Latin Quarter calm',
    category: 'hotels',
    imageUrl: 'https://images.unsplash.com/photo-discovery-placeholder?paris-monge',
    description:
      'Quiet elegance in the 5th. Walking distance to Jardin des Plantes, with interiors that blend modern comfort and Haussmann bones.',
    price: 260,
    currency: 'EUR',
    location: 'Paris, France',
    metadata: { stars: 4, neighborhood: 'Latin Quarter' },
    tasteScore: 83,
    tasteReason: 'Classic Parisian elegance without the attitude',
    source: 'seeded_catalog',
    fetchedAt: new Date().toISOString(),
  },

  // Activities — NYC
  {
    id: 'seed-act-001',
    title: 'Sunrise Brooklyn Bridge Walk',
    subtitle: 'Golden hour over Manhattan',
    category: 'activities',
    imageUrl: 'https://images.unsplash.com/photo-discovery-placeholder?nyc-brooklyn-bridge',
    description:
      'Cross the Brooklyn Bridge at sunrise before the crowds. Start in DUMBO, end with coffee at a Lower Manhattan cafe. Free, unforgettable.',
    price: 0,
    currency: 'USD',
    location: 'New York, USA',
    metadata: { duration: '90min', difficulty: 'easy', bestTime: 'sunrise' },
    tasteScore: 94,
    tasteReason: 'Iconic NYC moment without the tourist crush',
    source: 'seeded_catalog',
    fetchedAt: new Date().toISOString(),
  },
  {
    id: 'seed-act-002',
    title: 'Jazz at Smalls',
    subtitle: 'Greenwich Village late-night sets',
    category: 'activities',
    imageUrl: 'https://images.unsplash.com/photo-discovery-placeholder?nyc-smalls-jazz',
    description:
      'Intimate basement jazz club in the Village. Late-night sets from 12:30 AM with some of the best musicians in the city. BYOB spirit, world-class sound.',
    price: 20,
    currency: 'USD',
    location: 'New York, USA',
    metadata: { duration: '2h', genre: 'jazz', lateNight: true },
    tasteScore: 91,
    tasteReason: 'Authentic NYC nightlife that transcends tourism',
    source: 'seeded_catalog',
    fetchedAt: new Date().toISOString(),
  },
  {
    id: 'seed-act-003',
    title: 'Chelsea Market Food Tour',
    subtitle: 'Self-guided grazing through the Meatpacking District',
    category: 'activities',
    imageUrl: 'https://images.unsplash.com/photo-discovery-placeholder?nyc-chelsea-market',
    description:
      'Wander through the converted Nabisco factory. Lobster rolls at Lobster Place, tacos at Los Tacos No.1, and gelato at L\'Arte del Gelato.',
    price: 50,
    currency: 'USD',
    location: 'New York, USA',
    metadata: { duration: '2-3h', foodStops: 5, selfGuided: true },
    tasteScore: 86,
    tasteReason: 'Curated grazing in a landmark space',
    source: 'seeded_catalog',
    fetchedAt: new Date().toISOString(),
  },

  // Day Plans — Barcelona
  {
    id: 'seed-day-001',
    title: 'Barcelona Gothic Quarter Day',
    subtitle: 'Medieval lanes to beachfront sunset',
    category: 'day_plans',
    imageUrl: 'https://images.unsplash.com/photo-discovery-placeholder?barcelona-gothic',
    description:
      'Morning: Cathedral + Placa Reial. Lunch: El Xampanyet (cava + tapas). Afternoon: Born neighborhood galleries. Evening: Barceloneta beach sunset.',
    price: 60,
    currency: 'EUR',
    location: 'Barcelona, Spain',
    metadata: { stops: 6, walkingKm: 8, meals: 2 },
    tasteScore: 89,
    tasteReason: 'Perfect balance of culture, food, and coastal vibes',
    source: 'seeded_catalog',
    fetchedAt: new Date().toISOString(),
  },
  {
    id: 'seed-day-002',
    title: 'Gaudi Architecture Immersion',
    subtitle: 'Sagrada Familia to Park Guell',
    category: 'day_plans',
    imageUrl: 'https://images.unsplash.com/photo-discovery-placeholder?barcelona-gaudi',
    description:
      'Morning: Sagrada Familia (book 9 AM slot). Midday: Casa Batllo facade. Lunch: Eixample neighborhood. Afternoon: Park Guell. Evening: rooftop drinks at Hotel Ohla.',
    price: 85,
    currency: 'EUR',
    location: 'Barcelona, Spain',
    metadata: { stops: 5, walkingKm: 6, ticketsRequired: true },
    tasteScore: 93,
    tasteReason: 'Definitive Gaudi day with smart sequencing',
    source: 'seeded_catalog',
    fetchedAt: new Date().toISOString(),
  },
  {
    id: 'seed-day-003',
    title: 'Montjuic to Poble Sec Tapas Crawl',
    subtitle: 'Hilltop views then neighborhood eats',
    category: 'day_plans',
    imageUrl: 'https://images.unsplash.com/photo-discovery-placeholder?barcelona-montjuic',
    description:
      'Morning: Montjuic cable car + Miro Foundation. Lunch: Quimet & Quimet (standing-room tapas). Afternoon: Carrer de Blai pintxos crawl. Evening: flamenco at Tablao Cordobes.',
    price: 55,
    currency: 'EUR',
    location: 'Barcelona, Spain',
    metadata: { stops: 7, walkingKm: 5, meals: 3 },
    tasteScore: 87,
    tasteReason: 'Locals-only tapas trail with cultural depth',
    source: 'seeded_catalog',
    fetchedAt: new Date().toISOString(),
  },

  // Destinations
  {
    id: 'seed-dest-001',
    title: 'Cinque Terre',
    subtitle: 'Five villages clinging to the Ligurian coast',
    category: 'destinations',
    imageUrl: 'https://images.unsplash.com/photo-discovery-placeholder?cinque-terre',
    description:
      'Pastel fishing villages connected by coastal trails and train. Best in shoulder season (April-May, September-October). Skip Monterosso, start from Riomaggiore.',
    price: 120,
    currency: 'EUR',
    location: 'Liguria, Italy',
    metadata: { bestSeason: 'shoulder', villages: 5, daysRecommended: 3 },
    tasteScore: 91,
    tasteReason: 'Coastal Italy at its most photogenic and walkable',
    source: 'seeded_catalog',
    fetchedAt: new Date().toISOString(),
  },

  // Experiences
  {
    id: 'seed-exp-001',
    title: 'Truffle Hunting in Tuscany',
    subtitle: 'Dogs, dirt, and diamonds of the kitchen',
    category: 'experiences',
    imageUrl: 'https://images.unsplash.com/photo-discovery-placeholder?tuscany-truffle',
    description:
      'Join a third-generation truffle hunter and their Lagotto Romagnolo dogs in the hills outside San Miniato. Hunt, then cook and eat your finds.',
    price: 150,
    currency: 'EUR',
    location: 'Tuscany, Italy',
    metadata: { duration: '4h', groupSize: 8, includes: ['lunch', 'wine'] },
    tasteScore: 95,
    tasteReason: 'Once-in-a-lifetime sensory experience with zero tourist veneer',
    source: 'seeded_catalog',
    fetchedAt: new Date().toISOString(),
  },
];

const MOCK_DETAILS: Record<string, DiscoveryItemDetail> = {};
for (const item of MOCK_ITEMS) {
  MOCK_DETAILS[item.id] = {
    ...item,
    longDescription: `${item.description} This is one of the most beloved ${item.category} options in ${item.location}. Visitors consistently praise the authentic experience and attention to detail.`,
    imageUrls: [
      item.imageUrl ?? '',
      `${item.imageUrl}-2`,
      `${item.imageUrl}-3`,
    ],
    hours: {
      monday: '10:00-22:00',
      tuesday: '10:00-22:00',
      wednesday: '10:00-22:00',
      thursday: '10:00-22:00',
      friday: '10:00-23:00',
      saturday: '10:00-23:00',
      sunday: '11:00-21:00',
    },
    website: `https://example.com/${item.id}`,
    phone: '+1-555-0100',
    rating: 4.2 + Math.round((item.tasteScore / 100) * 8) / 10,
    reviewCount: 120 + Math.floor(item.tasteScore * 3),
    tags: [item.category, item.location ?? 'global', ...(item.metadata.cuisine ? [item.metadata.cuisine as string] : [])],
    aiSummary: undefined,
  };
}

export class SeededCatalogProvider implements DiscoveryProvider {
  name = 'seeded_catalog';
  priority = 0;
  supports: DiscoveryCategory[] = [
    'restaurants',
    'hotels',
    'activities',
    'destinations',
    'day_plans',
    'experiences',
  ];

  async search(params: {
    query?: string;
    category?: DiscoveryCategory;
    location?: string;
    limit: number;
  }): Promise<DiscoveryItem[]> {
    let results = [...MOCK_ITEMS];

    if (params.category) {
      results = results.filter((item) => item.category === params.category);
    }

    if (params.location) {
      const loc = params.location.toLowerCase();
      results = results.filter(
        (item) => item.location?.toLowerCase().includes(loc),
      );
    }

    if (params.query) {
      const q = params.query.toLowerCase();
      results = results.filter(
        (item) =>
          item.title.toLowerCase().includes(q) ||
          item.description?.toLowerCase().includes(q) ||
          item.location?.toLowerCase().includes(q) ||
          item.category.includes(q),
      );
    }

    return results.slice(0, params.limit);
  }

  async getDetail(externalId: string): Promise<DiscoveryItemDetail | null> {
    return MOCK_DETAILS[externalId] ?? null;
  }

  async healthCheck(): Promise<{ status: 'ok' | 'degraded' | 'down' }> {
    return { status: 'ok' };
  }
}
