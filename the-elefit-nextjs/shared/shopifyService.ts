import axios, { AxiosInstance } from "axios";

// Shopify API credentials from environment variables
const SHOPIFY_ACCESS_TOKEN = process.env.NEXT_PUBLIC_SHOPIFY_ACCESS_TOKEN || '';
const SHOPIFY_API_KEY = process.env.NEXT_PUBLIC_SHOPIFY_API_KEY || '';
const SHOPIFY_API_SECRET = process.env.NEXT_PUBLIC_SHOPIFY_API_SECRET || '';
const SHOPIFY_DOMAIN = process.env.NEXT_PUBLIC_SHOPIFY_DOMAIN || '';

// Storefront API endpoint
const STOREFRONT_API_URL = `https://${SHOPIFY_DOMAIN}/api/2023-07/graphql.json`;

// Admin API endpoint
const ADMIN_API_URL = `https://${SHOPIFY_DOMAIN}/admin/api/2023-07/graphql.json`;

/**
 * Create Axios instance for Storefront API calls
 */
const shopifyClient: AxiosInstance = axios.create({
  baseURL: STOREFRONT_API_URL,
  headers: {
    "Content-Type": "application/json",
    "X-Shopify-Storefront-Access-Token": SHOPIFY_ACCESS_TOKEN
  }
});

/**
 * Create Axios instance for Admin API calls
 */
const shopifyAdminClient: AxiosInstance = axios.create({
  baseURL: ADMIN_API_URL,
  headers: {
    "Content-Type": "application/json",
    "X-Shopify-Access-Token": SHOPIFY_ACCESS_TOKEN
  }
});

// Legacy Storefront API for backward compatibility
const shopifyAPI = axios.create({
  baseURL: `https://${SHOPIFY_DOMAIN}/api/2023-10/graphql.json`,
  headers: {
    "X-Shopify-Storefront-Access-Token": SHOPIFY_ACCESS_TOKEN,
    "Content-Type": "application/json",
  },
});

/**
 * Type definitions for Shopify API responses
 */
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
    company?: string;
    address1?: string;
    address2?: string;
    city?: string;
    province?: string;
    country?: string;
    zip?: string;
    phone?: string;
  };
}

interface ShopifyAccessToken {
  accessToken: string;
  expiresAt: string;
}

interface ShopifyError {
  code?: string;
  field?: string[];
  message: string;
}

/**
 * Helper to handle Shopify API errors
 */
const handleShopifyError = (error: any): void => {
  // Network or axios errors
  if (error.response) {
    // The request was made and the server responded with a status code
    // that falls out of the range of 2xx
    console.error("Shopify API error response:", error.response.data);
    throw new Error(
      `Shopify API error: ${error.response.status} - ${error.response.data.errors || "Unknown error"
      }`
    );
  } else if (error.request) {
    // The request was made but no response was received
    console.error("Shopify API no response:", error.request);
    throw new Error(
      "No response from Shopify API. Please check your internet connection."
    );
  } else {
    // Something happened in setting up the request that triggered an Error
    console.error("Shopify API request error:", error.message);
    throw new Error(`Error setting up request to Shopify: ${error.message}`);
  }
};

/**
 * Execute Shopify GraphQL query (legacy compatibility)
 */
const executeQuery = async (query: string, variables: any = {}) => {
  try {
    const response = await shopifyAPI.post("", {
      query,
      variables,
    });
    return response.data;
  } catch (error) {
    throw new Error(
      error instanceof Error ? error.message : "Shopify API request failed"
    );
  }
};

/**
 * Validate a Shopify customer by ID and email
 * @param customerId - Shopify customer ID
 * @param email - Customer email
 * @returns Customer data if valid
 */
export const validateShopifyCustomer = async (
  customerId: string,
  email: string
): Promise<ShopifyCustomer> => {
  const query = `
    query getCustomer($id: ID!) {
      customer(id: $id) {
        id
        email
        firstName
        lastName
        displayName
        createdAt
        updatedAt
        acceptsMarketing
        phone
        defaultAddress {
          id
          firstName
          lastName
          company
          address1
          address2
          city
          province
          country
          zip
          phone
        }
      }
    }
  `;

  const variables = {
    id: `gid://shopify/Customer/${customerId}`
  };

  try {
    console.log(
      `Validating Shopify customer with ID: ${customerId} and email: ${email}`
    );

    // Try Admin API first (has full access to customer data)
    let response;
    try {
      response = await shopifyAdminClient.post("", {
        query,
        variables
      });
      console.log("Using Admin API for customer validation");
    } catch (adminError) {
      console.log(
        "Admin API failed, trying Storefront API:",
        (adminError as any).message
      );
      // Fallback to Storefront API
      response = await shopifyClient.post("", {
        query,
        variables
      });
      console.log("Using Storefront API for customer validation");
    }

    console.log(
      "Shopify customer validation response:",
      JSON.stringify(response.data, null, 2)
    );
    const { data } = response.data;

    if (!data || !data.customer) {
      console.error("Customer not found in Shopify");
      throw new Error("Customer not found in Shopify");
    }

    const customer = data.customer;

    // Verify the email matches
    if (customer.email.toLowerCase() !== email.toLowerCase()) {
      console.error("Email mismatch for customer");
      throw new Error("Email does not match customer record");
    }

    console.log("Shopify customer validated successfully:", customer);
    return {
      id: customerId,
      email: customer.email,
      firstName: customer.firstName || "",
      lastName: customer.lastName || "",
      displayName: customer.displayName || "",
      createdAt: customer.createdAt,
      updatedAt: customer.updatedAt,
      acceptsMarketing: customer.acceptsMarketing,
      phone: customer.phone,
      defaultAddress: customer.defaultAddress
    };
  } catch (error) {
    console.error("Error validating Shopify customer:", error);

    // Check if it's an API error
    if (axios.isAxiosError(error)) {
      handleShopifyError(error);
    }

    throw error;
  }
};

/**
 * Login Shopify customer with email and password
 * @param email - Customer email
 * @param password - Customer password
 * @returns Customer access token and data
 */
export const loginShopifyCustomer = async (
  email: string,
  password: string
): Promise<ShopifyCustomer> => {
  const mutation = `
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
    input: {
      email,
      password
    }
  };

  try {
    console.log(`Attempting Shopify login for: ${email}`);
    const response = await shopifyClient.post("", {
      query: mutation,
      variables
    });

    console.log(
      "Shopify login response:",
      JSON.stringify(response.data, null, 2)
    );
    const { data } = response.data;

    if (!data || !data.customerAccessTokenCreate) {
      console.error("Invalid response from Shopify API");
      throw new Error("Invalid response from Shopify API");
    }

    // Check for errors
    if (
      data.customerAccessTokenCreate.customerUserErrors &&
      data.customerAccessTokenCreate.customerUserErrors.length > 0
    ) {
      const errors: ShopifyError[] =
        data.customerAccessTokenCreate.customerUserErrors;
      console.error("Shopify login errors:", errors);

      // Make specific error messages more user-friendly
      if (errors[0].code === "UNIDENTIFIED_CUSTOMER") {
        throw new Error("Email or password is incorrect");
      }

      throw new Error(errors[0].message || "Login failed");
    }

    // Make sure we have an access token
    if (!data.customerAccessTokenCreate.customerAccessToken) {
      console.error("Missing access token in Shopify response");
      throw new Error("Authentication failed");
    }

    // Get the access token
    const accessToken =
      data.customerAccessTokenCreate.customerAccessToken.accessToken;
    console.log("Shopify access token obtained successfully");

    // Now get customer information using the token
    return await getCustomerByAccessToken(accessToken);
  } catch (error) {
    console.error("Error logging in Shopify customer:", error);

    // Check if it's an API error
    if (axios.isAxiosError(error)) {
      handleShopifyError(error);
    }

    throw error;
  }
};

/**
 * Get customer information using access token
 * @param accessToken - Customer access token
 * @returns Customer data
 */
export const getCustomerByAccessToken = async (
  accessToken: string
): Promise<ShopifyCustomer> => {
  const query = `
    query {
      customer(customerAccessToken: "${accessToken}") {
        id
        email
        firstName
        lastName
        phone
      }
    }
  `;

  try {
    console.log("Fetching customer data with access token");
    const response = await shopifyClient.post("", { query });

    console.log(
      "Customer data response:",
      JSON.stringify(response.data, null, 2)
    );

    if (
      !response.data ||
      !response.data.data ||
      !response.data.data.customer
    ) {
      console.error("Failed to fetch customer data");
      throw new Error("Failed to fetch customer data");
    }

    const customer = response.data.data.customer;
    console.log(
      `Successfully retrieved customer data for: ${customer.email}`
    );

    return customer;
  } catch (error) {
    console.error("Error getting Shopify customer:", error);

    // Check if it's an API error
    if (axios.isAxiosError(error)) {
      handleShopifyError(error);
    }

    throw error;
  }
};

/**
 * Check if a customer exists in Shopify by email
 * @param email - Customer email to check
 * @returns True if customer exists
 */
export const checkShopifyCustomerExists = async (
  email: string
): Promise<boolean> => {
  try {
    console.log(`Checking if Shopify customer exists for email: ${email}`);

    // Use customerRecover to check for existence
    const recoveryMutation = `
      mutation customerRecover($email: String!) {
        customerRecover(email: $email) {
          customerUserErrors {
            code
            message
          }
        }
      }
    `;

    const recoveryResponse = await shopifyClient.post("", {
      query: recoveryMutation,
      variables: { email }
    });

    console.log(
      "Shopify customer recovery check response:",
      JSON.stringify(recoveryResponse.data, null, 2)
    );

    // If we don't get a specific error saying the customer doesn't exist, assume they do exist
    if (
      recoveryResponse.data &&
      recoveryResponse.data.data &&
      recoveryResponse.data.data.customerRecover
    ) {
      const errors: ShopifyError[] =
        recoveryResponse.data.data.customerRecover.customerUserErrors || [];
      const hasNonExistentError = errors.some(
        (error) =>
          error.code === "CUSTOMER_DOES_NOT_EXIST" ||
          error.message.includes("does not exist") ||
          error.message.includes("not found")
      );

      // If there's no error about the customer not existing, the customer likely exists
      const customerExists = !hasNonExistentError;
      console.log(
        `Shopify customer exists check result from recovery: ${customerExists}`
      );
      console.log(
        "Error codes:",
        errors.map((e) => e.code).join(", ")
      );

      return customerExists;
    }

    // Fallback method: try to login with a dummy password
    const mutation = `
      mutation customerAccessTokenCreate($input: CustomerAccessTokenCreateInput!) {
        customerAccessTokenCreate(input: $input) {
          customerAccessToken {
            accessToken
          }
          customerUserErrors {
            code
            message
          }
        }
      }
    `;

    const variables = {
      input: {
        email,
        password: "ThisIsADummyPasswordThatWillNeverWork123!@#"
      }
    };

    const response = await shopifyClient.post("", {
      query: mutation,
      variables
    });

    console.log(
      "Shopify customer existence check response (fallback):",
      JSON.stringify(response.data, null, 2)
    );

    if (
      !response.data ||
      !response.data.data ||
      !response.data.data.customerAccessTokenCreate
    ) {
      console.error("Invalid response format from Shopify API");
      return false;
    }

    const { customerUserErrors } = response.data.data.customerAccessTokenCreate;

    // Check the error codes to determine if user exists
    const errorCodes = customerUserErrors.map((e: ShopifyError) => e.code);
    console.log("Error codes (fallback):", errorCodes.join(", "));

    // If the error is UNIDENTIFIED_CUSTOMER, user doesn't exist
    // Otherwise, assume user exists
    const customerExists = !errorCodes.includes("UNIDENTIFIED_CUSTOMER");

    console.log(
      `Shopify customer exists check result (fallback): ${customerExists}`
    );

    return customerExists;
  } catch (error) {
    console.error("Error checking if Shopify customer exists:", error);

    // In case of an error, default to false (safer)
    return false;
  }
};

/**
 * Create Shopify customer (legacy version with firstName, lastName, phone)
 */
export const createShopifyCustomerLegacy = async (
  email: string,
  firstName: string,
  lastName: string,
  phone?: string
) => {
  try {
    const mutation = `
      mutation CreateCustomer($input: CustomerInput!) {
        customerCreate(input: $input) {
          customer {
            id
            email
            firstName
            lastName
            phone
          }
          userErrors {
            field
            message
          }
        }
      }
    `;

    const response = await executeQuery(mutation, {
      input: {
        email,
        firstName,
        lastName,
        phone,
      },
    });

    if (response.data.customerCreate.userErrors.length > 0) {
      throw new Error(
        response.data.customerCreate.userErrors[0].message
      );
    }

    return response.data.customerCreate.customer;
  } catch (error) {
    throw new Error(
      error instanceof Error
        ? error.message
        : "Failed to create Shopify customer"
    );
  }
};

/**
 * Get customer by email
 */
export const getShopifyCustomerByEmail = async (email: string) => {
  try {
    const query = `
      query {
        customers(first: 1, query: "email:${email}") {
          edges {
            node {
              id
              email
              firstName
              lastName
              phone
            }
          }
        }
      }
    `;

    const response = await executeQuery(query);
    const customers = response.data.customers.edges;

    if (customers.length === 0) {
      return null;
    }

    return customers[0].node;
  } catch (error) {
    throw new Error(
      error instanceof Error ? error.message : "Failed to fetch Shopify customer"
    );
  }
};

/**
 * Get products
 */
export const getShopifyProducts = async (limit: number = 20) => {
  try {
    const query = `
      query {
        products(first: ${limit}) {
          edges {
            node {
              id
              title
              description
              handle
              priceRange {
                minVariantPrice {
                  amount
                  currencyCode
                }
              }
              images(first: 1) {
                edges {
                  node {
                    url
                    altText
                  }
                }
              }
            }
          }
        }
      }
    `;

    const response = await executeQuery(query);
    return response.data.products.edges.map((edge: any) => edge.node);
  } catch (error) {
    throw new Error(
      error instanceof Error ? error.message : "Failed to fetch products"
    );
  }
};

/**
 * Create checkout
 */
export const createShopifyCheckout = async (lineItems: any[]) => {
  try {
    const mutation = `
      mutation CreateCheckout($input: CheckoutCreateInput!) {
        checkoutCreate(input: $input) {
          checkout {
            id
            webUrl
          }
          userErrors {
            field
            message
          }
        }
      }
    `;

    const response = await executeQuery(mutation, {
      input: {
        lineItems,
      },
    });

    if (response.data.checkoutCreate.userErrors.length > 0) {
      throw new Error(
        response.data.checkoutCreate.userErrors[0].message
      );
    }

    return response.data.checkoutCreate.checkout;
  } catch (error) {
    throw new Error(
      error instanceof Error ? error.message : "Failed to create checkout"
    );
  }
};

/**
 * Get checkout
 */
export const getShopifyCheckout = async (checkoutId: string) => {
  try {
    const query = `
      query GetCheckout($id: ID!) {
        checkout(id: $id) {
          id
          webUrl
          lineItems(first: 100) {
            edges {
              node {
                id
                title
                quantity
                variant {
                  price
                }
              }
            }
          }
          subtotalPrice {
            amount
            currencyCode
          }
        }
      }
    `;

    const response = await executeQuery(query, { id: checkoutId });
    return response.data.checkout;
  } catch (error) {
    throw new Error(
      error instanceof Error ? error.message : "Failed to fetch checkout"
    );
  }
};

/**
 * Update checkout
 */
export const updateShopifyCheckout = async (
  checkoutId: string,
  input: any
) => {
  try {
    const mutation = `
      mutation UpdateCheckout($id: ID!, $input: CheckoutInput!) {
        checkoutUpdate(id: $id, input: $input) {
          checkout {
            id
            webUrl
          }
          userErrors {
            field
            message
          }
        }
      }
    `;

    const response = await executeQuery(mutation, {
      id: checkoutId,
      input,
    });

    if (response.data.checkoutUpdate.userErrors.length > 0) {
      throw new Error(
        response.data.checkoutUpdate.userErrors[0].message
      );
    }

    return response.data.checkoutUpdate.checkout;
  } catch (error) {
    throw new Error(
      error instanceof Error ? error.message : "Failed to update checkout"
    );
  }
};

/**
 * Search products
 */
export const searchShopifyProducts = async (
  query: string,
  limit: number = 20
) => {
  try {
    const searchQuery = `
      query SearchProducts($query: String!, $first: Int!) {
        search(query: $query, first: $first, types: PRODUCT) {
          edges {
            node {
              ... on Product {
                id
                title
                handle
                description
                images(first: 1) {
                  edges {
                    node {
                      url
                      altText
                    }
                  }
                }
              }
            }
          }
        }
      }
    `;

    const response = await executeQuery(searchQuery, {
      query,
      first: limit,
    });
    return response.data.search.edges.map((edge: any) => edge.node);
  } catch (error) {
    throw new Error(
      error instanceof Error ? error.message : "Failed to search products"
    );
  }
};
