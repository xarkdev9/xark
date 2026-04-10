// Port of Dart CurrencyConverter — converts monetary amounts between
// currencies using exchange rates. Rates are expressed relative to a
// common base (e.g., all rates relative to EUR: {"EUR": 1.0, "USD": 1.08}).

function round2(value: number): number {
  return Math.round(value * 100) / 100;
}

/**
 * Convert an amount from one currency to another using the provided
 * exchange rates map. If from and to are the same, returns amount unchanged.
 * Throws if either currency code is missing from rates.
 * Result is rounded to 2 decimal places.
 */
export function convert(
  amount: number,
  from: string,
  to: string,
  rates: Record<string, number>
): number {
  if (from === to) return amount;

  if (!(from in rates)) {
    throw new Error(`Exchange rate missing for source currency: ${from}`);
  }
  if (!(to in rates)) {
    throw new Error(`Exchange rate missing for target currency: ${to}`);
  }

  const fromRate = rates[from];
  const toRate = rates[to];

  if (fromRate === 0) {
    throw new Error(`Exchange rate for ${from} must not be zero.`);
  }

  const converted = amount * (toRate / fromRate);
  return round2(converted);
}

/**
 * Convert an amount, returning the original amount if both currencies
 * are the same or no rates are provided.
 */
export function convertAmount(
  amount: number,
  from: string,
  to: string,
  rates: Record<string, number>
): number {
  if (from === to || Object.keys(rates).length === 0) return amount;
  return convert(amount, from, to, rates);
}
