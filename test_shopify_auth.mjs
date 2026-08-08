// Diagnoses why a Shopify user can/can't auto-login to coach.theelefit.com.
//
// It reproduces exactly what coach's authenticateCustomer() does, and checks
// which password the user's Firebase account actually has.
//
// Run (your password never leaves your machine):
//   EMAIL='you@example.com' PASSWORD='yourShopifyPassword' node test_shopify_auth.mjs
//
// Node 18+ (has global fetch).

const FIREBASE_API_KEY = 'AIzaSyA2zu144EAVw0j7lC9uTyjPfBmSW7jHEbU';
const SHOPIFY_STORE = 'theelefit.com';
const SHOPIFY_TOKEN = '3476fc91bc4860c5b02aea3983766cb1';
const BRIDGE_SALT = 'EleFit_Bridge_2026_Secure_';

const email = (process.env.EMAIL || '').toLowerCase().trim();
const password = process.env.PASSWORD || '';
if (!email || !password) {
  console.error("Usage: EMAIL='..' PASSWORD='..' node test_shopify_auth.mjs");
  process.exit(1);
}

function normalizeShopifyId(id) {
  const s = String(id);
  return s.includes('gid://shopify/Customer/') ? s.split('/').pop() : s;
}

async function shopifyGraphql(query, variables) {
  const res = await fetch(`https://${SHOPIFY_STORE}/api/2024-01/graphql`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-Shopify-Storefront-Access-Token': SHOPIFY_TOKEN,
    },
    body: JSON.stringify({ query, variables }),
  });
  return res.json();
}

async function firebaseSignIn(pw) {
  const res = await fetch(
    `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${FIREBASE_API_KEY}`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password: pw, returnSecureToken: true }),
    }
  );
  const json = await res.json();
  return json.idToken ? 'LOGGED IN' : (json.error?.message || 'FAILED');
}

console.log(`\n=== Diagnosing ${email} ===\n`);

// 1. Shopify login (validate their store password + get their customer id)
const login = await shopifyGraphql(
  `mutation($i: CustomerAccessTokenCreateInput!){ customerAccessTokenCreate(input:$i){ customerAccessToken{ accessToken } customerUserErrors{ message } } }`,
  { i: { email, password } }
);
const token = login?.data?.customerAccessTokenCreate?.customerAccessToken?.accessToken;
console.log('1) Shopify login with this password:',
  token ? 'VALID (they are a Shopify customer)'
        : `INVALID -> ${JSON.stringify(login?.data?.customerAccessTokenCreate?.customerUserErrors || login?.errors)}`);

let bridgePw = null;
if (token) {
  const cust = await shopifyGraphql(
    `query($t: String!){ customer(customerAccessToken:$t){ id email } }`, { t: token });
  const gid = cust?.data?.customer?.id;
  const numericId = gid ? normalizeShopifyId(gid) : null;
  console.log('2) Shopify customer id:', gid, '-> numeric:', numericId);
  if (numericId) bridgePw = BRIDGE_SALT + numericId;
}

// 3. What password does their FIREBASE account actually accept?
console.log('\n--- Firebase login attempts ---');
console.log('3) With their SHOPIFY password :', await firebaseSignIn(password));
if (bridgePw) {
  console.log('4) With the BRIDGE password    :', await firebaseSignIn(bridgePw));
}

console.log(`
=== Interpretation ===
- "3 = LOGGED IN" -> Firebase password IS their Shopify password (real-password account).
    Coach auto-login uses the BRIDGE password, so it FAILS -> the error you saw.
- "4 = LOGGED IN" -> Firebase password IS the bridge password (bridge-origin account).
    Coach auto-login SHOULD work; if it doesn't, look elsewhere.
- Both FAILED -> a third/diverged password; needs a reset or custom-token login.
`);
