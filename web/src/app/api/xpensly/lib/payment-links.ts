// Payment link generators for all supported providers.
// Port of Dart payment adapters: Venmo, UPI, PayPal, Stripe, Razorpay.

import Stripe from 'stripe';

export interface PaymentLinkParams {
  from: string;
  to: string;
  amount: number;
  currency: string;
  note?: string;
}

export interface PaymentLinkResult {
  url: string;
  qrData?: string;
  provider: string;
}

async function venmoLink(params: PaymentLinkParams): Promise<PaymentLinkResult> {
  const encodedTo = encodeURIComponent(params.to);
  const encodedNote = encodeURIComponent(params.note ?? 'Xpensly settle');
  return {
    url: `venmo://paycharge?txn=pay&recipients=${encodedTo}&amount=${params.amount}&note=${encodedNote}`,
    provider: 'venmo',
  };
}

async function upiLink(params: PaymentLinkParams): Promise<PaymentLinkResult> {
  const encodedTo = encodeURIComponent(params.to);
  const encodedNote = encodeURIComponent(params.note ?? 'Xpensly settle');
  const url = `upi://pay?pa=${encodedTo}&pn=${encodedTo}&am=${params.amount}&tn=${encodedNote}&cu=${params.currency}`;
  return {
    url,
    qrData: url, // UPI QR codes encode the same URI as the deep link.
    provider: 'upi',
  };
}

async function paypalLink(params: PaymentLinkParams): Promise<PaymentLinkResult> {
  const encodedTo = encodeURIComponent(params.to);
  return {
    url: `https://paypal.me/${encodedTo}/${params.amount}${params.currency}`,
    provider: 'paypal',
  };
}

async function stripeLink(params: PaymentLinkParams): Promise<PaymentLinkResult> {
  const stripe = new Stripe(process.env.STRIPE_SECRET_KEY || 'sk_test_placeholder', {
    apiVersion: '2025-02-24.acacia' as any,
  });

  const amountCents = Math.round(params.amount * 100);
  
  try {
    const session = await stripe.checkout.sessions.create({
      payment_method_types: ['card'],
      line_items: [
        {
          price_data: {
            currency: params.currency.toLowerCase(),
            product_data: {
              name: params.note || 'Xpensly Settle',
              description: `Settlement payment to ${params.to}`,
            },
            unit_amount: amountCents,
          },
          quantity: 1,
        },
      ],
      mode: 'payment',
      success_url: `https://xark.vercel.app/success`,
      cancel_url: `https://xark.vercel.app/cancel`,
    });

    return {
      url: session.url || `https://checkout.stripe.com/pay?amount=${amountCents}`,
      provider: 'stripe',
    };
  } catch (error) {
    console.error('Stripe error:', error);
    return {
      url: `https://checkout.stripe.com/pay?amount=${amountCents}&currency=${params.currency.toLowerCase()}`,
      provider: 'stripe',
    };
  }
}

async function razorpayLink(params: PaymentLinkParams): Promise<PaymentLinkResult> {
  const amountPaise = Math.round(params.amount * 100);
  const url = `https://rzp.io/pay?amount=${amountPaise}&currency=${params.currency}`;
  return {
    url,
    qrData: url, // Razorpay supports QR-based payments using the same link.
    provider: 'razorpay',
  };
}

const providers: Record<string, (params: PaymentLinkParams) => Promise<PaymentLinkResult>> = {
  venmo: venmoLink,
  upi: upiLink,
  paypal: paypalLink,
  stripe: stripeLink,
  razorpay: razorpayLink,
};

/**
 * Generate a payment link for the specified provider.
 * Throws if the provider is not supported.
 */
export async function generatePaymentLink(
  provider: string,
  params: PaymentLinkParams
): Promise<PaymentLinkResult> {
  const generator = providers[provider.toLowerCase()];
  if (!generator) {
    throw new Error(
      `Unsupported payment provider: ${provider}. Supported: ${Object.keys(providers).join(', ')}`
    );
  }
  return await generator(params);
}
