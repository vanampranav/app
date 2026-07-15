// Diagnostic: reproduces the participant payment-proof upload path outside the app.
//   1. Signs in with email/password (Firebase Auth REST — same as the app).
//   2. Uploads a test file to payment_proofs/... in Firebase Storage using the ID token.
// Reports the exact result/error so we can tell whether it's auth, rules, bucket,
// or App Check. Run: node scripts/test_storage_upload.mjs

const WEB_API_KEY = 'AIzaSyAqeG-3oPRaS8kw_2YojhU51EpTbCUXmjQ';
const BUCKET = 'getfit-with-elefit.firebasestorage.app';
const EMAIL = 'vanam.abhinav005@gmail.com';
const PASSWORD = 'vijayalaxmi';

function line() { console.log('─'.repeat(60)); }

async function main() {
  line();
  console.log('STEP 1 — Sign in (Firebase Auth REST)');
  line();
  const signInRes = await fetch(
    `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${WEB_API_KEY}`,
    { method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: EMAIL, password: PASSWORD, returnSecureToken: true }) }
  );
  const signIn = await signInRes.json();
  if (!signInRes.ok) {
    console.log('❌ SIGN-IN FAILED —', signInRes.status);
    console.log(JSON.stringify(signIn, null, 2));
    console.log('\n→ The account/password is invalid, or the web API key is restricted.');
    return;
  }
  const idToken = signIn.idToken;
  const uid = signIn.localId;
  console.log('✅ Signed in.  uid =', uid, ' email =', signIn.email);

  line();
  console.log('STEP 2 — Upload test file to payment_proofs/ (Storage REST)');
  line();
  const path = `payment_proofs/diagnostic-challenge/${uid}-${Date.now()}.jpg`;
  const url = `https://firebasestorage.googleapis.com/v0/b/${BUCKET}/o?uploadType=media&name=${encodeURIComponent(path)}`;
  const body = Buffer.from('diagnostic-test-image-bytes');
  console.log('bucket:', BUCKET);
  console.log('path  :', path);

  const upRes = await fetch(url, {
    method: 'POST',
    headers: { 'Authorization': `Firebase ${idToken}`, 'Content-Type': 'image/jpeg' },
    body,
  });
  const upText = await upRes.text();

  line();
  if (upRes.ok) {
    console.log('✅ UPLOAD SUCCEEDED —', upRes.status);
    console.log('→ Auth token + Storage rules + bucket are all GOOD.');
    console.log('→ So the app failure is client-side: the Firebase Auth SDK session');
    console.log('  is not present in the app when it uploads (or App Check on the app).');
  } else {
    console.log('❌ UPLOAD FAILED —', upRes.status);
    console.log(upText.slice(0, 1000));
    console.log('\nInterpretation:');
    if (upRes.status === 403) {
      console.log('  403 → the token is valid but Storage denied it. Likely the Storage');
      console.log('        SECURITY RULES (not published/too strict) or App Check enforcement.');
    } else if (upRes.status === 404) {
      console.log('  404 → the BUCKET name is wrong / bucket does not exist for this project.');
    } else if (upRes.status === 401) {
      console.log('  401 → the ID token was rejected (auth problem).');
    }
  }
  line();
}

main().catch((e) => { console.log('SCRIPT ERROR:', e); });
