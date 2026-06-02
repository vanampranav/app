import { GraphQLClient, gql } from 'graphql-request';

const SHOPIFY_DOMAIN = process.env.NEXT_PUBLIC_SHOPIFY_DOMAIN || '840a56-3.myshopify.com';
const SHOPIFY_ACCESS_TOKEN = process.env.NEXT_PUBLIC_SHOPIFY_STOREFRONT_ACCESS_TOKEN || '3476fc91bc4860c5b02aea3983766cb1';
const STOREFRONT_API_URL = `https://${SHOPIFY_DOMAIN}/api/2023-07/graphql.json`;

const shopifyClient = new GraphQLClient(STOREFRONT_API_URL, {
  headers: {
    'X-Shopify-Storefront-Access-Token': SHOPIFY_ACCESS_TOKEN,
  },
});

export interface ShopifyProduct {
  id: string;
  title: string;
  handle: string;
  description: string;
  onlineStoreUrl: string;
  images: {
    edges: {
      node: {
        url: string;
        altText: string;
      };
    }[];
  };
  priceRange: {
    minVariantPrice: {
      amount: string;
      currencyCode: string;
    };
  };
}

/**
 * Authenticate customer with Shopify and return access token
 */
export const loginShopifyCustomer = async (email: string, password: string) => {
  const mutation = gql`
    mutation customerAccessTokenCreate($input: CustomerAccessTokenCreateInput!) {
      customerAccessTokenCreate(input: $input) {
        customerAccessToken {
          accessToken
          expiresAt
        }
        customerUserErrors {
          code
          field
          message
        }
      }
    }
  `;

  const variables = {
    input: { email, password },
  };

  try {
    const data: any = await shopifyClient.request(mutation, variables);
    const { customerAccessTokenCreate } = data;

    if (customerAccessTokenCreate.customerUserErrors.length > 0) {
      const error = customerAccessTokenCreate.customerUserErrors[0];
      if (error.code === 'UNIDENTIFIED_CUSTOMER') {
        throw new Error('Email or password is incorrect');
      }
      throw new Error(error.message || 'Login failed');
    }

    return customerAccessTokenCreate.customerAccessToken.accessToken;
  } catch (error: any) {
    console.error('Shopify login error:', error);
    throw error;
  }
};

/**
 * Get customer details using access token
 */
export const getCustomerByToken = async (accessToken: string) => {
  const query = gql`
    query getCustomer($customerAccessToken: String!) {
      customer(customerAccessToken: $customerAccessToken) {
        id
        email
        firstName
        lastName
        displayName
      }
    }
  `;

  const variables = { customerAccessToken: accessToken };

  try {
    const data: any = await shopifyClient.request(query, variables);
    if (!data.customer) {
      throw new Error('Customer not found');
    }
    return data.customer;
  } catch (error: any) {
    console.error('Shopify get customer error:', error);
    throw error;
  }
};

/**
 * Check if a customer exists in Shopify by email
 * (Uses a dummy login attempt to check for UNIDENTIFIED_CUSTOMER error)
 */
export const checkShopifyCustomerExists = async (email: string) => {
  const query = gql`
    query {
      shop {
        name
      }
    }
  `;

  try {
    // Attempting to create with an empty password/names just to check for EMAIL_ALREADY_EXISTS 
    // is one way, but customerRecover is safer if it works correctly.
    // Let's stick with customerRecover but improve error parsing.
    const mutation = gql`
      mutation customerRecover($email: String!) {
        customerRecover(email: $email) {
          customerUserErrors {
            code
            message
          }
        }
      }
    `;

    const variables = { email };
    const data: any = await shopifyClient.request(mutation, variables);
    const errors = data.customerRecover.customerUserErrors;

    // If there are no errors, it means the recovery email was "sent" (or would be),
    // which implies the customer exists.
    if (errors.length === 0) return true;

    // Check for specific "not found" codes
    const notFound = errors.some((e: any) =>
      e.code === 'CUSTOMER_DOES_NOT_EXIST' ||
      e.message.toLowerCase().includes('not found') ||
      e.code === 'UNIDENTIFIED_CUSTOMER'
    );

    return !notFound;
  } catch (error: any) {
    if (error.message?.includes('403') || error.message?.includes('401')) {
      console.error('❌ Shopify API Auth Error: Check if Storefront Access Token has "unauthenticated_write_customers" permission.');
    }
    console.error('Shopify existence check error:', error);
    return false;
  }
};

/**
 * Create a new customer in Shopify
 */
export const createShopifyCustomer = async (input: {
  email: string;
  password: string;
  firstName: string;
  lastName: string;
}) => {
  const mutation = gql`
    mutation customerCreate($input: CustomerCreateInput!) {
      customerCreate(input: $input) {
        customer {
          id
          email
        }
        customerUserErrors {
          code
          field
          message
        }
      }
    }
  `;

  const variables = {
    input: {
      email: input.email,
      password: input.password,
      firstName: input.firstName,
      lastName: input.lastName,
      acceptsMarketing: false,
    },
  };

  try {
    const data: any = await shopifyClient.request(mutation, variables);
    const { customerCreate } = data;

    if (customerCreate.customerUserErrors.length > 0) {
      const errors = customerCreate.customerUserErrors;
      console.error('❌ Shopify Customer Creation Errors:', errors);
      const error = errors[0];

      let friendlyMessage = error.message || 'Failed to create Shopify customer';
      if (error.code === 'TAKEN') {
        friendlyMessage = 'An account with this email already exists in our store.';
      } else if (error.code === 'TOO_SHORT') {
        friendlyMessage = 'Password is too short for Shopify (minimum 5 characters).';
      }

      throw new Error(friendlyMessage);
    }

    return customerCreate.customer;
  } catch (error: any) {
    console.error('Shopify customer creation error:', error);
    throw error;
  }
};

/**
 * Fetch products from Shopify
 */
export const getShopifyProducts = async (first: number = 20) => {
  const query = gql`
    query getProducts($first: Int!) {
      products(first: $first) {
        edges {
          node {
            id
            title
            handle
            description
            onlineStoreUrl
            images(first: 1) {
              edges {
                node {
                  url
                  altText
                }
              }
            }
            priceRange {
              minVariantPrice {
                amount
                currencyCode
              }
            }
          }
        }
      }
    }
  `;

  const variables = { first };

  try {
    const data: any = await shopifyClient.request(query, variables);
    return data.products.edges.map((edge: any) => edge.node) as ShopifyProduct[];
  } catch (error: any) {
    console.error('Shopify get products error:', error);
    return [];
  }
};

// ─────────────────────────────────────────────────────────────
// INDIA STORE — Storefront API client
// ─────────────────────────────────────────────────────────────
const INDIA_DOMAIN = process.env.NEXT_PUBLIC_SHOPIFY_INDIA_DOMAIN || 'nad691-1n.myshopify.com';
const INDIA_STOREFRONT_TOKEN = process.env.NEXT_PUBLIC_SHOPIFY_INDIA_STOREFRONT_TOKEN || '';
const INDIA_API_VERSION = '2025-01';

const indiaShopifyClient = new GraphQLClient(
  `https://${INDIA_DOMAIN}/api/${INDIA_API_VERSION}/graphql.json`,
  {
    headers: {
      'X-Shopify-Storefront-Access-Token': INDIA_STOREFRONT_TOKEN,
    },
  }
);

/**
 * Login a customer on the India store and return their access token
 */
export const loginIndiaShopifyCustomer = async (email: string, password: string) => {
  const mutation = gql`
    mutation customerAccessTokenCreate($input: CustomerAccessTokenCreateInput!) {
      customerAccessTokenCreate(input: $input) {
        customerAccessToken {
          accessToken
          expiresAt
        }
        customerUserErrors {
          code
          field
          message
        }
      }
    }
  `;

  try {
    const data: any = await indiaShopifyClient.request(mutation, {
      input: { email, password },
    });
    const { customerAccessTokenCreate } = data;

    if (customerAccessTokenCreate.customerUserErrors.length > 0) {
      const error = customerAccessTokenCreate.customerUserErrors[0];
      if (error.code === 'UNIDENTIFIED_CUSTOMER') {
        throw new Error('Email or password is incorrect');
      }
      throw new Error(error.message || 'India store login failed');
    }

    return customerAccessTokenCreate.customerAccessToken.accessToken as string;
  } catch (error: any) {
    console.error('India Shopify login error:', error);
    throw error;
  }
};

/**
 * Get India store customer details by access token
 */
export const getIndiaCustomerByToken = async (accessToken: string) => {
  const query = gql`
    query getCustomer($customerAccessToken: String!) {
      customer(customerAccessToken: $customerAccessToken) {
        id
        email
        firstName
        lastName
        displayName
      }
    }
  `;

  try {
    const data: any = await indiaShopifyClient.request(query, { customerAccessToken: accessToken });
    if (!data.customer) throw new Error('Customer not found in India store');
    return data.customer;
  } catch (error: any) {
    console.error('India Shopify get customer error:', error);
    throw error;
  }
};
