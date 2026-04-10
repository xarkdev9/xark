// Port of Dart DebtSimplifier — reduces the number of transactions
// needed to settle all debts. Uses a net-balance greedy algorithm that
// minimizes total number of transfers by computing each person's net
// position and greedily matching the largest creditor with the largest debtor.

import { DebtDelta } from './types';

function round2(value: number): number {
  return Math.round(value * 100) / 100;
}

/**
 * Simplify a list of debt deltas into the minimum number of transactions
 * needed to settle all balances.
 */
export function simplifyDebts(
  deltas: DebtDelta[],
  currency: string = 'USD'
): DebtDelta[] {
  if (deltas.length === 0) return [];

  // Step 1: Compute net balance per person.
  // Positive = net creditor (owed money), negative = net debtor (owes money).
  const balances: Record<string, number> = {};
  for (const delta of deltas) {
    balances[delta.from] = (balances[delta.from] ?? 0) - delta.amount;
    balances[delta.to] = (balances[delta.to] ?? 0) + delta.amount;
  }

  // Step 2: Separate into creditors and debtors.
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

  // Step 3: Sort — largest amounts first for greedy matching.
  creditors.sort((a, b) => b.amount - a.amount);
  debtors.sort((a, b) => b.amount - a.amount);

  // Step 4: Greedily match largest creditor with largest debtor.
  const simplified: DebtDelta[] = [];
  let ci = 0;
  let di = 0;

  while (ci < creditors.length && di < debtors.length) {
    const transfer = round2(Math.min(creditors[ci].amount, debtors[di].amount));

    if (transfer > 0) {
      simplified.push({
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

  return simplified;
}

/**
 * Return the deltas as-is without simplification. Useful when the caller
 * wants to preserve the original pairwise debt structure.
 */
export function pairwiseDebts(deltas: DebtDelta[]): DebtDelta[] {
  return [...deltas];
}
