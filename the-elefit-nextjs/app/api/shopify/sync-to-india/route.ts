import { NextResponse } from 'next/server';

const INDIA_DOMAIN = 'nad691-1n.myshopify.com';
const INDIA_ADMIN_TOKEN = process.env.SHOPIFY_INDIA_ADMIN_TOKEN || '';
const API_VERSION = '2025-01';

async function findCustomerByEmail(email: string) {
  const res = await fetch(
    `https://${INDIA_DOMAIN}/admin/api/${API_VERSION}/customers/search.json?query=email:${encodeURIComponent(email)}&limit=1`,
    { headers: { 'X-Shopify-Access-Token': INDIA_ADMIN_TOKEN } }
  );
  const data = await res.json();
  return data.customers?.[0] || null;
}

async function createOrFindCustomer(
  email: string,
  password: string,
  firstName: string,
  lastName: string
) {
  const res = await fetch(
    `https://${INDIA_DOMAIN}/admin/api/${API_VERSION}/customers.json`,
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Shopify-Access-Token': INDIA_ADMIN_TOKEN,
      },
      body: JSON.stringify({
        customer: {
          email,
          password,
          password_confirmation: password,
          first_name: firstName,
          last_name: lastName,
          verified_email: true,
          send_email_welcome: false,
        },
      }),
    }
  );

  // 422 = validation error (most likely email already taken)
  if (res.status === 422) {
    const data = await res.json();
    if (data.errors?.email) {
      return await findCustomerByEmail(email);
    }
    throw new Error(JSON.stringify(data.errors));
  }

  if (!res.ok) {
    const text = await res.text();
    throw new Error(`India store error ${res.status}: ${text}`);
  }

  const data = await res.json();
  return data.customer;
}

export async function POST(req: Request) {
  try {
    if (!INDIA_ADMIN_TOKEN) {
      console.warn('SHOPIFY_INDIA_ADMIN_TOKEN not set — skipping India store sync');
      return NextResponse.json({ skipped: true, reason: 'India store not configured' });
    }

    const { email, password, firstName, lastName } = await req.json();

    if (!email || !password) {
      return NextResponse.json({ error: 'email and password are required' }, { status: 400 });
    }

    const customer = await createOrFindCustomer(
      email.toLowerCase().trim(),
      password,
      firstName || '',
      lastName || ''
    );

    if (!customer) {
      return NextResponse.json({ error: 'Failed to create/find customer in India store' }, { status: 500 });
    }

    const numericId = String(customer.id).replace('gid://shopify/Customer/', '');
    console.log(`✓ India store customer synced: ${email} → ID ${numericId}`);

    return NextResponse.json({ success: true, customerId: numericId });
  } catch (err: any) {
    console.error('India store sync error:', err.message);
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}

// GET: look up a customer by email in India store (used for login cross-check)
export async function GET(req: Request) {
  try {
    if (!INDIA_ADMIN_TOKEN) {
      return NextResponse.json({ skipped: true });
    }

    const { searchParams } = new URL(req.url);
    const email = searchParams.get('email');

    if (!email) {
      return NextResponse.json({ error: 'email required' }, { status: 400 });
    }

    const customer = await findCustomerByEmail(email);

    if (!customer) {
      return NextResponse.json({ exists: false });
    }

    const numericId = String(customer.id).replace('gid://shopify/Customer/', '');
    return NextResponse.json({ exists: true, customerId: numericId });
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}
