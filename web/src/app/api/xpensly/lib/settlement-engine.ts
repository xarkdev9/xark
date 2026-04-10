// Port of Dart SettlementEngine — computes full settlement for a group
// of expenses, refunds, and prior settlements. Produces per-member
// ledger entries, raw pairwise debts, simplified debts, and aggregate stats.

import {
  Member, Expense, Refund, SettlementRecord,
  DebtDelta, LedgerEntry, Settlement,
} from './types';
import { convertAmount } from './currency-converter';
import { simplifyDebts } from './debt-simplifier';
import { computeShareMap } from './split-calculator';

function round2(value: number): number {
  return Math.round(value * 100) / 100;
}

export interface ComputeSettlementParams {
  members: Member[];
  expenses: Expense[];
  refunds?: Refund[];
  priorSettlements?: SettlementRecord[];
  baseCurrency: string;
  exchangeRates?: Record<string, number>;
}

/**
 * Compute the settlement across all provided expenses, refunds,
 * and prior settlement records.
 */
export function computeSettlement(params: ComputeSettlementParams): Settlement {
  const {
    members,
    expenses,
    refunds = [],
    priorSettlements = [],
    baseCurrency,
    exchangeRates = {},
  } = params;

  // Per-user balance: positive = owed money, negative = owes money.
  const balances: Record<string, number> = {};
  const totalPaidMap: Record<string, number> = {};
  const totalOwesMap: Record<string, number> = {};
  const expenseItems: Record<string, { title: string; amount: number }[]> = {};

  // Aggregate stats.
  const byCurrency: Record<string, number> = {};
  const byCategory: Record<string, number> = {};
  let totalSpent = 0;

  // Initialize maps for all members.
  for (const m of members) {
    balances[m.id] = 0;
    totalPaidMap[m.id] = 0;
    totalOwesMap[m.id] = 0;
    expenseItems[m.id] = [];
  }

  // Step 1: Process each expense.
  for (const expense of expenses) {
    const convertedAmount = convertAmount(
      expense.amount, expense.currency, baseCurrency, exchangeRates
    );

    // Aggregate by original currency.
    byCurrency[expense.currency] = (byCurrency[expense.currency] ?? 0) + expense.amount;

    // Aggregate by category.
    const category = expense.category ?? 'uncategorized';
    byCategory[category] = (byCategory[category] ?? 0) + convertedAmount;

    totalSpent += convertedAmount;

    // Credit each payer.
    for (const payer of expense.paidBy) {
      const convertedPaid = convertAmount(
        payer.amount, expense.currency, baseCurrency, exchangeRates
      );
      balances[payer.userId] = (balances[payer.userId] ?? 0) + convertedPaid;
      totalPaidMap[payer.userId] = (totalPaidMap[payer.userId] ?? 0) + convertedPaid;
    }

    // Debit each user for their share.
    const shareMap = computeShareMap(expense);

    for (const [userId, share] of Object.entries(shareMap)) {
      const convertedShare = convertAmount(
        share, expense.currency, baseCurrency, exchangeRates
      );
      balances[userId] = (balances[userId] ?? 0) - convertedShare;
      totalOwesMap[userId] = (totalOwesMap[userId] ?? 0) + convertedShare;
      if (!expenseItems[userId]) expenseItems[userId] = [];
      expenseItems[userId].push({ title: expense.title, amount: convertedShare });
    }
  }

  // Step 2: Apply refunds.
  for (const refund of refunds) {
    const convertedAmount = convertAmount(
      refund.amount, refund.currency, baseCurrency, exchangeRates
    );
    balances[refund.refundedTo] = (balances[refund.refundedTo] ?? 0) + convertedAmount;
  }

  // Step 3: Apply prior settlements.
  for (const settlement of priorSettlements) {
    const convertedAmount = convertAmount(
      settlement.amount, settlement.currency, baseCurrency, exchangeRates
    );
    balances[settlement.fromUser] = (balances[settlement.fromUser] ?? 0) - convertedAmount;
    balances[settlement.toUser] = (balances[settlement.toUser] ?? 0) + convertedAmount;
  }

  // Step 4: Build ledger entries.
  const entries: LedgerEntry[] = members.map((m) => ({
    userId: m.id,
    name: m.name,
    totalPaid: round2(totalPaidMap[m.id] ?? 0),
    totalOwes: round2(totalOwesMap[m.id] ?? 0),
    netBalance: round2(balances[m.id] ?? 0),
    items: expenseItems[m.id] ?? [],
  }));

  // Step 5: Build raw debt deltas from balances.
  const deltas = buildDeltas(balances, baseCurrency);

  // Step 6: Simplify.
  const simplified = simplifyDebts(deltas, baseCurrency);

  const memberCount = members.length;
  const perPerson = memberCount > 0 ? round2(totalSpent / memberCount) : 0;

  return {
    entries,
    deltas,
    simplified,
    totalSpent: round2(totalSpent),
    perPerson,
    byCurrency,
    byCategory,
    memberCount,
  };
}

/** Build raw debt deltas from net balances. */
function buildDeltas(
  balances: Record<string, number>,
  currency: string
): DebtDelta[] {
  const creditors: { userId: string; amount: number }[] = [];
  const debtors: { userId: string; amount: number }[] = [];

  for (const [userId, balance] of Object.entries(balances)) {
    const rounded = round2(balance);
    if (rounded > 0) {
      creditors.push({ userId, amount: rounded });
    } else if (rounded < 0) {
      debtors.push({ userId, amount: Math.abs(rounded) });
    }
  }

  creditors.sort((a, b) => b.amount - a.amount);
  debtors.sort((a, b) => b.amount - a.amount);

  const deltas: DebtDelta[] = [];
  let ci = 0;
  let di = 0;

  while (ci < creditors.length && di < debtors.length) {
    const transfer = round2(Math.min(creditors[ci].amount, debtors[di].amount));

    if (transfer > 0) {
      deltas.push({
        from: debtors[di].userId,
        to: creditors[ci].userId,
        amount: transfer,
        currency,
      });
    }

    creditors[ci] = {
      userId: creditors[ci].userId,
      amount: round2(creditors[ci].amount - transfer),
    };
    debtors[di] = {
      userId: debtors[di].userId,
      amount: round2(debtors[di].amount - transfer),
    };

    if (creditors[ci].amount === 0) ci++;
    if (debtors[di].amount === 0) di++;
  }

  return deltas;
}
