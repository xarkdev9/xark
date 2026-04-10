import { NextResponse } from 'next/server';

export async function GET() {
  return NextResponse.json({
    currencies: ['USD', 'EUR', 'GBP', 'CHF', 'INR', 'JPY', 'CAD', 'AUD', 'CNY', 'KRW'],
  });
}
