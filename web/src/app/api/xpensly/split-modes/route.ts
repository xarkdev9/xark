import { NextResponse } from 'next/server';

export async function GET() {
  return NextResponse.json({
    modes: ['equal', 'exact', 'percentage', 'shares'],
  });
}
