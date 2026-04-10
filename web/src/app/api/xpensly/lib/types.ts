// Xpensly Core Types — TypeScript port of xpensly_core Dart models

export interface Member {
  id: string;
  name: string;
}

export interface Payer {
  userId: string;
  amount: number;
}

export type SplitMode = 'equal' | 'exact' | 'percentage' | 'shares';

export interface Expense {
  id?: string;
  title: string;
  amount: number;
  currency: string;
  paidBy: Payer[];
  splitAmong: string[];
  splitMode: SplitMode;
  splitDetails?: Record<string, number>;
  category?: string;
  phase?: string;
  date?: string;
  notes?: string;
  receiptUrl?: string;
  tags?: string[];
  recurring?: { frequency: string; until: string };
}

export interface SplitResult {
  userId: string;
  owes: number;
  owesTo: string;
}

export interface DebtDelta {
  from: string;
  to: string;
  amount: number;
  currency: string;
}

export interface LedgerEntry {
  userId: string;
  name: string;
  totalPaid: number;
  totalOwes: number;
  netBalance: number;
  items: { title: string; amount: number }[];
}

export interface Settlement {
  entries: LedgerEntry[];
  deltas: DebtDelta[];
  simplified: DebtDelta[];
  totalSpent: number;
  perPerson: number;
  byCurrency: Record<string, number>;
  byCategory: Record<string, number>;
  memberCount: number;
}

export interface TripSummary {
  totalSpent: number;
  byCurrency: Record<string, number>;
  byCategory: Record<string, number>;
  byPhase: Record<string, number>;
  byMember: Record<string, number>;
  topPayer: string;
  topSpender: string;
  avgPerDay: number;
  avgPerPerson: number;
  timeline: { date: string; total: number; count: number }[];
}

export interface Refund {
  id?: string;
  originalExpenseId?: string;
  amount: number;
  currency: string;
  refundedTo: string;
  reason: string;
  date: string;
}

export interface SettlementRecord {
  id?: string;
  tripId: string;
  fromUser: string;
  toUser: string;
  amount: number;
  currency: string;
  provider?: string;
  proof?: string;
  note?: string;
  settledAt?: string;
}
