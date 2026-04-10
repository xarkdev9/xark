// Port of Dart SplitCalculator — calculates how an expense should be
// split among participants. Supports equal, exact, percentage, and shares
// modes. Handles multi-payer expenses and distributes rounding remainders.

import { Expense, SplitResult } from './types';

function round2(value: number): number {
  return Math.round(value * 100) / 100;
}

/** Compute per-user shares based on split mode. */
function computeShares(expense: Expense): Record<string, number> {
  switch (expense.splitMode) {
    case 'equal':
      return equalShares(expense);
    case 'exact':
      return exactShares(expense);
    case 'percentage':
      return percentageShares(expense);
    case 'shares':
      return relativeShares(expense);
    default:
      throw new Error(`Unsupported split mode: ${expense.splitMode}`);
  }
}

function equalShares(expense: Expense): Record<string, number> {
  const count = expense.splitAmong.length;
  if (count === 0) {
    throw new Error('splitAmong must not be empty');
  }

  const totalCents = Math.round(expense.amount * 100);
  const baseShare = Math.floor(totalCents / count);
  const remainder = totalCents - baseShare * count;

  const shares: Record<string, number> = {};
  for (let i = 0; i < expense.splitAmong.length; i++) {
    const userId = expense.splitAmong[i];
    const cents = baseShare + (i < remainder ? 1 : 0);
    shares[userId] = cents / 100;
  }
  return shares;
}

function exactShares(expense: Expense): Record<string, number> {
  const details = expense.splitDetails;
  if (!details) {
    throw new Error('splitDetails is required for exact split mode');
  }

  const sum = Object.values(details).reduce((a, b) => a + b, 0);
  if (Math.abs(sum - expense.amount) > 0.01) {
    throw new Error(
      `Exact split details sum to ${sum} but expense amount is ${expense.amount}. Difference exceeds $0.01.`
    );
  }

  return { ...details };
}

function percentageShares(expense: Expense): Record<string, number> {
  const details = expense.splitDetails;
  if (!details) {
    throw new Error('splitDetails is required for percentage split mode');
  }

  const percentSum = Object.values(details).reduce((a, b) => a + b, 0);
  if (Math.abs(percentSum - 100) > 0.01) {
    throw new Error(
      `Percentage split details sum to ${percentSum}, expected 100.`
    );
  }

  const totalCents = Math.round(expense.amount * 100);
  const entries = Object.entries(details);
  const rawCents: Record<string, number> = {};
  let allocatedCents = 0;

  for (let i = 0; i < entries.length; i++) {
    const [key, value] = entries[i];
    if (i === entries.length - 1) {
      // Last entry gets remainder to ensure exact total.
      rawCents[key] = totalCents - allocatedCents;
    } else {
      const cents = Math.round((value / 100) * totalCents);
      rawCents[key] = cents;
      allocatedCents += cents;
    }
  }

  const shares: Record<string, number> = {};
  for (const [key, cents] of Object.entries(rawCents)) {
    shares[key] = cents / 100;
  }
  return shares;
}

function relativeShares(expense: Expense): Record<string, number> {
  const details = expense.splitDetails;
  if (!details) {
    throw new Error('splitDetails is required for shares split mode');
  }

  const totalShares = Object.values(details).reduce((a, b) => a + b, 0);
  if (totalShares === 0) {
    throw new Error('Total shares must be greater than zero.');
  }

  const totalCents = Math.round(expense.amount * 100);
  const entries = Object.entries(details);
  const rawCents: Record<string, number> = {};
  let allocatedCents = 0;

  for (let i = 0; i < entries.length; i++) {
    const [key, value] = entries[i];
    if (i === entries.length - 1) {
      rawCents[key] = totalCents - allocatedCents;
    } else {
      const cents = Math.round((value / totalShares) * totalCents);
      rawCents[key] = cents;
      allocatedCents += cents;
    }
  }

  const shares: Record<string, number> = {};
  for (const [key, cents] of Object.entries(rawCents)) {
    shares[key] = cents / 100;
  }
  return shares;
}

/** Resolve who owes whom based on each user's share vs what they paid. */
function resolveDebts(expense: Expense, shares: Record<string, number>): SplitResult[] {
  // Per-user balance: positive = overpaid (is owed money),
  // negative = underpaid (owes money).
  const balances: Record<string, number> = {};

  // Credit each payer for what they paid.
  for (const payer of expense.paidBy) {
    balances[payer.userId] = (balances[payer.userId] ?? 0) + payer.amount;
  }

  // Debit each user for their share.
  for (const [userId, share] of Object.entries(shares)) {
    balances[userId] = (balances[userId] ?? 0) - share;
  }

  // Separate into creditors (positive balance) and debtors (negative).
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

  // Sort for deterministic output: largest amounts first.
  creditors.sort((a, b) => b.amount - a.amount);
  debtors.sort((a, b) => b.amount - a.amount);

  // Greedily match debtors to creditors.
  const results: SplitResult[] = [];
  let ci = 0;
  let di = 0;
  const cBal = creditors.map((e) => e.amount);
  const dBal = debtors.map((e) => e.amount);

  while (ci < creditors.length && di < debtors.length) {
    const transfer = round2(Math.min(cBal[ci], dBal[di]));
    if (transfer > 0) {
      results.push({
        userId: debtors[di].userId,
        owes: transfer,
        owesTo: creditors[ci].userId,
      });
    }
    cBal[ci] = round2(cBal[ci] - transfer);
    dBal[di] = round2(dBal[di] - transfer);

    if (cBal[ci] === 0) ci++;
    if (dBal[di] === 0) di++;
  }

  return results;
}

/** Calculate split results for a single expense. */
export function calculateSplit(expense: Expense): SplitResult[] {
  const shares = computeShares(expense);
  return resolveDebts(expense, shares);
}

/**
 * Compute the per-user share map for an expense (used internally by
 * settlement engine and trip aggregator).
 */
export function computeShareMap(expense: Expense): Record<string, number> {
  return computeShares(expense);
}
