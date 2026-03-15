// PII redaction before Gemini calls. Pure function, <1ms.

interface Message {
  id: string;
  space_id: string;
  role: string;
  content: string;
  user_id: string | null;
  sender_name: string | null;
  created_at: string;
}

/** Luhn algorithm — validates credit card numbers */
function luhnCheck(digits: string): boolean {
  const nums = digits.split("").map(Number);
  let sum = 0;
  let alt = false;
  for (let i = nums.length - 1; i >= 0; i--) {
    let n = nums[i];
    if (alt) {
      n *= 2;
      if (n > 9) n -= 9;
    }
    sum += n;
    alt = !alt;
  }
  return sum % 10 === 0;
}

/** Redact PII from a single string */
export function redactPII(text: string): string {
  if (!text) return text;

  let result = text;

  // Credit/debit cards: 13-19 digits with optional spaces/dashes, Luhn-validated
  result = result.replace(
    /\b(\d[ -]?){13,19}\b/g,
    (match) => {
      const digits = match.replace(/[ -]/g, "");
      if (digits.length >= 13 && digits.length <= 19 && luhnCheck(digits)) {
        return "[redacted]";
      }
      return match;
    }
  );

  // SSN: XXX-XX-XXXX
  result = result.replace(/\b\d{3}-\d{2}-\d{4}\b/g, "[redacted]");

  // CVV/CVC after keyword (3-4 digits), allows "is", ":", "=" between
  result = result.replace(
    /\b(cvv|cvc|security\s+code)\s+(?:is\s+|:\s*|=\s*)?\d{3,4}\b/gi,
    (match) => {
      const keyword = match.replace(/\s+\d{3,4}$/, "");
      return `${keyword} [redacted]`;
    }
  );

  // Bank account/routing after keyword (8-17 digits)
  result = result.replace(
    /\b(account\s*(?:number)?|routing|iban)\s+\d{8,17}\b/gi,
    (match) => {
      const keyword = match.replace(/\s+\d{8,17}$/, "");
      return `${keyword} [redacted]`;
    }
  );

  return result;
}

/** Sanitize messages for intelligence — strips PII from content only */
export function sanitizeForIntelligence<T extends Message>(messages: T[]): T[] {
  return messages.map((m) => ({
    ...m,
    content: redactPII(m.content),
  }));
}
