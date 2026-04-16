// Port of Dart TripAggregator — aggregates expense data into a
// comprehensive trip summary. Computes totals by currency, category,
// phase, and member, along with top payer/spender and timeline data.

import { Expense, Member, TripSummary } from './types';
import { convertAmount } from './currency-converter';
import { computeShareMap } from './split-calculator';

function round2(value: number): number {
  return Math.round(value * 100) / 100;
}

function maxKey(map: Record<string, number>): string {
  const keys = Object.keys(map);
  if (keys.length === 0) return '';
  let best = keys[0];
  let bestVal = map[best];
  for (const key of keys) {
    if (map[key] > bestVal) {
      best = key;
      bestVal = map[key];
    }
  }
  return best;
}

export interface SummarizeParams {
  expenses: Expense[];
  members: Member[];
  baseCurrency: string;
  exchangeRates?: Record<string, number>;
}

/**
 * Produce a TripSummary from a list of expenses and members.
 * All amounts are converted to baseCurrency for aggregation.
 * Original currency amounts are preserved in byCurrency.
 */
export function summarizeTrip(params: SummarizeParams): TripSummary {
  const { expenses, members, baseCurrency, exchangeRates = {} } = params;

  let totalSpent = 0;
  const byCurrency: Record<string, number> = {};
  const byCategory: Record<string, number> = {};
  const byPhase: Record<string, number> = {};
  const byMemberPaid: Record<string, number> = {};
  const byMemberShare: Record<string, number> = {};
  const dailyMap: Record<string, { total: number; count: number }> = {};

  for (const expense of expenses) {
    const converted = convertAmount(
      expense.amount, expense.currency, baseCurrency, exchangeRates
    );

    totalSpent += converted;

    // By original currency.
    byCurrency[expense.currency] = (byCurrency[expense.currency] ?? 0) + expense.amount;

    // By category (in base currency).
    const category = expense.category ?? 'uncategorized';
    byCategory[category] = (byCategory[category] ?? 0) + converted;

    // By phase (in base currency).
    if (expense.phase) {
      byPhase[expense.phase] = (byPhase[expense.phase] ?? 0) + converted;
    }

    // By member paid (in base currency).
    for (const payer of expense.paidBy) {
      const convertedPaid = convertAmount(
        payer.amount, expense.currency, baseCurrency, exchangeRates
      );
      byMemberPaid[payer.userId] = (byMemberPaid[payer.userId] ?? 0) + convertedPaid;
    }

    // By member share (in base currency).
    const shareMap = computeShareMap(expense);
    for (const [userId, share] of Object.entries(shareMap)) {
      const convertedShare = convertAmount(
        share, expense.currency, baseCurrency, exchangeRates
      );
      byMemberShare[userId] = (byMemberShare[userId] ?? 0) + convertedShare;
    }

    // Timeline: group by date.
    const dateKey = expense.date
      ? expense.date.split('T')[0]
      : new Date().toISOString().split('T')[0];
    if (!dailyMap[dateKey]) {
      dailyMap[dateKey] = { total: 0, count: 0 };
    }
    dailyMap[dateKey].total += converted;
    dailyMap[dateKey].count += 1;
  }

  // Top payer: member who paid the most.
  const topPayer = maxKey(byMemberPaid);

  // Top spender: member whose split share is highest.
  const topSpender = maxKey(byMemberShare);

  // Distinct expense dates for avgPerDay.
  const distinctDates = Object.keys(dailyMap).length;
  const avgPerDay = distinctDates > 0 ? round2(totalSpent / distinctDates) : 0;
  const avgPerPerson = members.length > 0 ? round2(totalSpent / members.length) : 0;

  // Build sorted timeline.
  const sortedDates = Object.keys(dailyMap).sort();
  const timeline = sortedDates.map((date) => ({
    date,
    total: round2(dailyMap[date].total),
    count: dailyMap[date].count,
  }));

  return {
    totalSpent: round2(totalSpent),
    byCurrency,
    byCategory,
    byPhase,
    byMember: byMemberPaid,
    topPayer,
    topSpender,
    avgPerDay,
    avgPerPerson,
    timeline,
  };
}
