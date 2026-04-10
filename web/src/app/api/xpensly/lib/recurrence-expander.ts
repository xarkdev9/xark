// Port of Dart RecurrenceExpander — expands a recurring expense into
// individual expense instances. One expense per occurrence from
// expense.date up to (but not including) expense.recurring.until.

import { Expense } from './types';

/**
 * Advance a date by one period based on the frequency string.
 */
function advanceDate(date: Date, frequency: string): Date {
  switch (frequency) {
    case 'daily':
      return new Date(date.getFullYear(), date.getMonth(), date.getDate() + 1);
    case 'weekly':
      return new Date(date.getFullYear(), date.getMonth(), date.getDate() + 7);
    case 'monthly':
      return new Date(date.getFullYear(), date.getMonth() + 1, date.getDate());
    default:
      throw new Error(`Unsupported frequency: ${frequency}`);
  }
}

/**
 * Expand a recurring expense into a list of individual expenses.
 * If the expense has no recurring field, returns a single-element
 * array containing the original expense unchanged.
 *
 * Supported frequencies: "daily", "weekly", "monthly".
 * Each generated expense receives an id of `${expense.id}_${index}`
 * and has its recurring field set to undefined.
 */
export function expandRecurrence(expense: Expense): Expense[] {
  if (!expense.recurring) return [expense];

  const until = new Date(expense.recurring.until);
  const frequency = expense.recurring.frequency;
  const results: Expense[] = [];
  let current = expense.date ? new Date(expense.date) : new Date();
  let index = 0;

  while (current < until) {
    results.push({
      ...expense,
      id: `${expense.id}_${index}`,
      date: current.toISOString().split('T')[0],
      recurring: undefined,
    });

    current = advanceDate(current, frequency);
    index++;
  }

  return results;
}
