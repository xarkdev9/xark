export type DiscoveryCategory =
  | 'restaurants'
  | 'hotels'
  | 'activities'
  | 'destinations'
  | 'day_plans'
  | 'experiences';

export interface DiscoveryItem {
  id: string;
  title: string;
  subtitle?: string;
  category: DiscoveryCategory;
  imageUrl?: string;
  description?: string;
  price?: number;
  currency?: string;
  location?: string;
  metadata: Record<string, unknown>;
  tasteScore: number;
  tasteReason?: string;
  source: string;
  fetchedAt: string;
}

export interface CarouselCard {
  id: string;
  title: string;
  subtitle?: string;
  imageUrl?: string;
  heroColor: string;
  category: DiscoveryCategory;
  items: DiscoveryItem[];
  curationType: 'trending' | 'seasonal' | 'taste_match' | 'editorial';
}

export interface DiscoveryItemDetail extends DiscoveryItem {
  longDescription?: string;
  imageUrls: string[];
  hours?: Record<string, string>;
  website?: string;
  phone?: string;
  rating?: number;
  reviewCount?: number;
  tags: string[];
  aiSummary?: string;
}

export interface ErrorReportPayload {
  type: 'error' | 'bug' | 'suggestion';
  errorType?: string;
  errorMessage?: string;
  userDescription?: string;
  context: {
    screen: string;
    action: string;
    timestamp: string;
    deviceInfo: {
      os: string;
      version: string;
      model: string;
      appVersion: string;
    };
    stackTrace?: string;
    requestId?: string;
  };
}

export interface FeedbackRecord {
  id: string;
  userId: string;
  type: string;
  errorType?: string;
  errorMessage?: string;
  userDescription?: string;
  context: Record<string, unknown>;
  status: string;
  createdAt: string;
}
