# Shopify Integration - Quick Reference Card

## 🚀 Quick Start

### Install & Setup
```bash
# No additional packages needed - axios already installed
npm run build      # Verify everything builds
npm run dev        # Start development server
```

### Import & Use
```typescript
import { loginShopifyCustomer } from '@shared/shopifyService';

const customer = await loginShopifyCustomer('user@example.com', 'password');
```

---

## 📋 Function Reference

### Customer Authentication

**`validateShopifyCustomer(customerId, email)`**
```typescript
// Validate customer by ID and email
const customer = await validateShopifyCustomer('123456', 'user@example.com');
// Returns: ShopifyCustomer { id, email, firstName, lastName, ... }
```

**`loginShopifyCustomer(email, password)`**
```typescript
// Login customer and get their data
const customer = await loginShopifyCustomer('user@example.com', 'password123');
// Returns: ShopifyCustomer with access token
```

**`getCustomerByAccessToken(accessToken)`**
```typescript
// Fetch customer data using access token
const customer = await getCustomerByAccessToken(accessToken);
// Returns: ShopifyCustomer
```

**`checkShopifyCustomerExists(email)`**
```typescript
// Check if customer exists (no password needed)
const exists = await checkShopifyCustomerExists('user@example.com');
// Returns: boolean
```

---

### Product Management

**`getShopifyProducts(limit?)`**
```typescript
const products = await getShopifyProducts(20);
// Returns: Array of products with images, prices
```

**`searchShopifyProducts(query, limit?)`**
```typescript
const results = await searchShopifyProducts('yoga mat', 10);
// Returns: Filtered product array
```

---

### Checkout Operations

**`createShopifyCheckout(lineItems)`**
```typescript
const checkout = await createShopifyCheckout([
  { variantId: 'gid://shopify/ProductVariant/1', quantity: 1 }
]);
// Returns: { id, webUrl }
```

**`getShopifyCheckout(checkoutId)`**
```typescript
const checkout = await getShopifyCheckout(checkoutId);
// Returns: Checkout details with line items, totals
```

**`updateShopifyCheckout(checkoutId, input)`**
```typescript
const updated = await updateShopifyCheckout(checkoutId, {
  email: 'customer@example.com'
});
```

---

## 🔧 Type Definitions

### ShopifyCustomer
```typescript
interface ShopifyCustomer {
  id: string;
  email: string;
  firstName?: string;
  lastName?: string;
  displayName?: string;
  phone?: string;
  createdAt?: string;
  updatedAt?: string;
  acceptsMarketing?: boolean;
  defaultAddress?: {
    id: string;
    firstName?: string;
    lastName?: string;
    address1?: string;
    address2?: string;
    city?: string;
    province?: string;
    country?: string;
    zip?: string;
    phone?: string;
  };
}
```

### ShopifyAccessToken
```typescript
interface ShopifyAccessToken {
  accessToken: string;
  expiresAt: string;
}
```

### ShopifyError
```typescript
interface ShopifyError {
  code?: string;
  field?: string[];
  message: string;
}
```

---

## 🛡️ Error Handling

### Common Errors & Solutions

```typescript
try {
  await loginShopifyCustomer(email, password);
} catch (error) {
  if (error.message === 'Email or password is incorrect') {
    // Show wrong credentials message
  } else if (error.message.includes('No response from Shopify API')) {
    // Network issue - ask user to retry
  } else {
    // Generic error
    console.error('Unexpected error:', error.message);
  }
}
```

### Error Messages
| Error | Cause | Fix |
|-------|-------|-----|
| "Email or password is incorrect" | Invalid credentials | Check email/password |
| "Customer not found in Shopify" | Customer ID doesn't exist | Validate customer ID |
| "No response from Shopify API" | Network issue | Check internet, retry |
| "Email does not match customer record" | Email mismatch | Verify email address |

---

## 💻 Integration Examples

### Login Form Integration
```typescript
import { loginShopifyCustomer } from '@shared/shopifyService';
import { useAuth } from '@/contexts/AuthContext';

export function LoginForm() {
  const { login } = useAuth();
  const [error, setError] = useState('');

  const handleLogin = async (email: string, password: string) => {
    try {
      // Validate with Shopify
      const customer = await loginShopifyCustomer(email, password);
      
      // Login to Firebase
      await login(email, password);
      
      // Success
      navigate('/dashboard');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Login failed');
    }
  };

  return (
    <form onSubmit={(e) => {
      e.preventDefault();
      handleLogin(email, password);
    }}>
      {error && <Alert>{error}</Alert>}
      {/* Form fields */}
    </form>
  );
}
```

### Customer Validation on Route
```typescript
import { validateShopifyCustomer } from '@shared/shopifyService';
import { useNavigate, useSearchParams } from 'react-router-dom';

export function CustomerAuthRoute() {
  const navigate = useNavigate();
  const [params] = useSearchParams();
  const customerId = params.get('customerId');
  const email = params.get('email');

  useEffect(() => {
    if (!customerId || !email) {
      navigate('/auth');
      return;
    }

    validateShopifyCustomer(customerId, email)
      .then((customer) => {
        // Customer valid - redirect to login with email pre-filled
        navigate(`/auth?email=${encodeURIComponent(customer.email)}`);
      })
      .catch((error) => {
        // Validation failed
        navigate(`/auth?message=Invalid%20customer&type=error`);
      });
  }, [customerId, email, navigate]);

  return <LoadingSpinner />;
}
```

### Product Listing
```typescript
import { getShopifyProducts } from '@shared/shopifyService';
import { useEffect, useState } from 'react';

export function ProductList() {
  const [products, setProducts] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    getShopifyProducts(20)
      .then(setProducts)
      .catch((error) => console.error('Failed to load products:', error))
      .finally(() => setLoading(false));
  }, []);

  if (loading) return <LoadingSpinner />;

  return (
    <div className="grid gap-4">
      {products.map((product) => (
        <ProductCard key={product.id} product={product} />
      ))}
    </div>
  );
}
```

---

## ⚙️ Environment Configuration

### Required Variables in `.env`
```env
VITE_SHOPIFY_ACCESS_TOKEN=your_token_here
VITE_SHOPIFY_API_KEY=your_api_key
VITE_SHOPIFY_API_SECRET=your_secret
VITE_SHOPIFY_DOMAIN=your-store.myshopify.com
VITE_SHOPIFY_STOREFRONT_API_URL=https://your-store.myshopify.com/api/2023-07/graphql.json
VITE_SHOPIFY_ADMIN_API_URL=https://your-store.myshopify.com/admin/api/2023-07/graphql.json
```

### Access in Code
```typescript
// Automatically loaded from .env
const token = import.meta.env.VITE_SHOPIFY_ACCESS_TOKEN;
const domain = import.meta.env.VITE_SHOPIFY_DOMAIN;
```

---

## 🔒 Security Best Practices

✅ **DO:**
- Store credentials in `.env` (never in code)
- Use VITE_ prefix for client-side variables
- Implement proper error boundaries
- Validate user input before API calls
- Store access tokens securely
- Implement token refresh when expired

❌ **DON'T:**
- Expose API secrets in client-side code
- Log sensitive data
- Hardcode credentials
- Skip error handling
- Trust unvalidated API responses
- Ignore rate limiting

---

## 📊 API Endpoints

### Storefront API
- **URL**: `https://840a56-3.myshopify.com/api/2023-07/graphql.json`
- **Purpose**: Customer-facing operations
- **Auth Header**: `X-Shopify-Storefront-Access-Token`
- **Use Cases**: Login, browse products, checkout

### Admin API
- **URL**: `https://840a56-3.myshopify.com/admin/api/2023-07/graphql.json`
- **Purpose**: Merchant operations
- **Auth Header**: `X-Shopify-Access-Token`
- **Use Cases**: Customer validation, order management

---

## 🧪 Testing

### Test Customer Login
```typescript
// In browser console
import { loginShopifyCustomer } from '@shared/shopifyService';

loginShopifyCustomer('test@example.com', 'password')
  .then(customer => console.log('Success:', customer))
  .catch(error => console.error('Error:', error.message));
```

### Test Customer Existence
```typescript
import { checkShopifyCustomerExists } from '@shared/shopifyService';

checkShopifyCustomerExists('test@example.com')
  .then(exists => console.log('Exists:', exists));
```

### Test Product Listing
```typescript
import { getShopifyProducts } from '@shared/shopifyService';

getShopifyProducts(5)
  .then(products => console.log('Products:', products))
  .catch(error => console.error('Error:', error));
```

---

## 📚 Related Files

- **Service**: [shared/shopifyService.ts](shared/shopifyService.ts)
- **Environment**: [.env](.env)
- **Full Guide**: [SHOPIFY_INTEGRATION.md](SHOPIFY_INTEGRATION.md)
- **Setup Complete**: [SHOPIFY_SETUP_COMPLETE.md](SHOPIFY_SETUP_COMPLETE.md)

---

## 🆘 Troubleshooting

### "Cannot find module '@shared/shopifyService'"
- Check file path is correct
- Ensure Vite server is restarted
- Clear node_modules and reinstall

### "API returns null for customer"
- Verify customer ID format: `gid://shopify/Customer/123456`
- Check email matches exactly (case-insensitive)
- Ensure access token is valid

### "Network error from Shopify"
- Check internet connection
- Verify VITE_SHOPIFY_DOMAIN is correct
- Ensure API endpoints are accessible

### Build fails with TypeScript errors
- Run `npm run typecheck`
- Check all imports use correct paths
- Verify type definitions match usage

---

**Last Updated**: February 2, 2026  
**Status**: ✅ Production Ready  
**Version**: 1.0.0
