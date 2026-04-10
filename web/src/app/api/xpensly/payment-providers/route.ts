import { NextResponse } from 'next/server';

export async function GET() {
  return NextResponse.json({
    providers: ['venmo', 'upi', 'paypal', 'stripe', 'razorpay'],
  });
}
