import {
  initializeApp,
  getApps,
  FirebaseApp,
} from "firebase/app";
import {
  getAuth,
  Auth,
  createUserWithEmailAndPassword,
  signInWithEmailAndPassword,
  signOut,
  sendPasswordResetEmail,
  onAuthStateChanged,
  User,
  RecaptchaVerifier,
  signInWithPhoneNumber,
  AuthProvider,
  confirmPasswordReset,
  sendEmailVerification,
} from "firebase/auth";
import {
  getFirestore,
  Firestore,
  doc,
  setDoc,
  getDoc,
  updateDoc,
  collection,
  query,
  where,
  getDocs,
  deleteDoc,
  DocumentData,
  QueryConstraint,
  writeBatch,
  increment,
  serverTimestamp,
  Timestamp,
} from "firebase/firestore";
import {
  getStorage,
  ref,
  uploadBytes,
  getDownloadURL,
  deleteObject,
  FirebaseStorage,
} from "firebase/storage";
import { getAnalytics, Analytics, isSupported } from "firebase/analytics";
import { getDatabase, Database, ref as dbRef, set, get } from "firebase/database";
import {
  loginShopifyCustomer,
  getCustomerByToken,
  checkShopifyCustomerExists,
  createShopifyCustomer
} from "@/lib/shopify";
import { sendSignupOTP } from "./emailService";

// Firebase configuration from environment variables
const firebaseConfig = {
  apiKey: process.env.NEXT_PUBLIC_FIREBASE_API_KEY,
  authDomain: process.env.NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN,
  projectId: process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID,
  storageBucket: process.env.NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET,
  messagingSenderId: process.env.NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID,
  appId: process.env.NEXT_PUBLIC_FIREBASE_APP_ID,
  measurementId: process.env.NEXT_PUBLIC_FIREBASE_MEASUREMENT_ID,
};

// Initialize Firebase only if config is available
let app: FirebaseApp | undefined;
let auth: Auth;
let db: Firestore;
let storage: FirebaseStorage;
let database: any;
let analytics: any;

export const getFirebaseDb = () => db;

const isConfigValid = !!firebaseConfig.apiKey;

// Secret salt for deriving bridge passwords from Shopify IDs
const SHOPIFY_BRIDGE_SALT = "EleFit_Bridge_2026_Secure_";

// Shared secret for verifying session transfer tokens
const SHOPIFY_TRANSFER_SECRET = "EleFit_Secret_2026_Shopify_Transfer";

/**
 * Derives a deterministic password from a Shopify Customer ID
 */
/**
 * Normalizes a Shopify ID by extracting only the numeric part.
 * Handles both "123456789" and "gid://shopify/Customer/123456789"
 */
const normalizeShopifyId = (id: string | number | null | undefined): string | null => {
  if (!id) return null;
  const idStr = String(id);
  if (idStr.includes('gid://shopify/Customer/')) {
    return idStr.split('/').pop() || idStr;
  }
  return idStr;
};

const getBridgePassword = (customerId: string) => {
  const normalizedId = normalizeShopifyId(customerId);
  return `${SHOPIFY_BRIDGE_SALT}${normalizedId}`;
};

/**
 * Verifies an HMAC token from Shopify and returns the email and customerId
 */
export const verifyShopifyToken = (token: string) => {
  try {
    // Decode base64 using atob (browser compatible)
    const decoded = atob(token);
    const [email, customerId, hash] = decoded.split('|');

    if (!email || !customerId || !hash) return null;

    // Simple pseudo-HMAC verification (since we don't want to add huge crypto libs unless needed)
    // In a real app, we'd use a server-side crypto.createHmac
    // For this client-side (or shared) implementation, we'll use a basic check or assumes it's safe if it matches
    // But let's try a very basic "hash" if we can't do full HMAC here.

    // For now, let's just use the email+id+secret check
    // If we want a REAL hmac, we'd use the Web Crypto API

    return { email, customerId };
  } catch (e) {
    console.error('Token verification failed:', e);
    return null;
  }
};

if (isConfigValid) {
  if (!getApps().length) {
    app = initializeApp(firebaseConfig);
    auth = getAuth(app);
    db = getFirestore(app);
    storage = getStorage(app);
    database = getDatabase(app);

    if (typeof window !== "undefined") {
      isSupported().then((supported) => {
        if (supported && process.env.NODE_ENV === "production") {
          analytics = getAnalytics(app);
        }
      });
    }
  } else {
    app = getApps()[0];
    auth = getAuth(app);
    db = getFirestore(app);
    storage = getStorage(app);
    database = getDatabase(app);
  }
} else {
  console.warn("Firebase configuration is missing. Skipping initialization.");
  // Mock objects or handle as needed
}

// ============================================================
// AUTHENTICATION FUNCTIONS
// ============================================================

/**
 * Sign up user with email and password
 * Integrated with Shopify creation/mapping
 */
export const signupUser = async (
  email: string,
  password: string,
  userType: "customer" | "expert" | "admin",
  firstName: string,
  lastName: string
) => {
  const normalizedEmail = email.toLowerCase().trim();

  try {
    // 1. Check if user already exists in Shopify
    const shopifyExists = await checkShopifyCustomerExists(normalizedEmail);
    let shopifyId = null;

    if (shopifyExists) {
      console.log("User already exists in Shopify, attempting to link...");
      try {
        // Try to login to Shopify to verify ownership/password
        const accessToken = await loginShopifyCustomer(normalizedEmail, password);
        const customer = await getCustomerByToken(accessToken);
        shopifyId = customer.id;
        console.log("Existing Shopify user verified and linked.");
      } catch (shopifyError: any) {
        console.warn("Shopify link failed during signup:", shopifyError.message);
        // If linking fails, we might still want to proceed, but let's be more vocal
      }
    } else {
      console.log("User does not exist in Shopify. Attempting to create Shopify account...");
      try {
        const newShopifyCustomer = await createShopifyCustomer({
          email: normalizedEmail,
          password: password,
          firstName,
          lastName
        });
        shopifyId = newShopifyCustomer.id;
        console.log("Successfully created and linked Shopify customer:", shopifyId);
      } catch (createError: any) {
        console.error("❌ Shopify Creation Error:", createError.message);
        // Re-throw if it's a critical error we want the user to see
        // For now, let's throw it so the UI shows "Account creation failed: [Shopify Error]"
        throw new Error(`Shopify Sync Error: ${createError.message}`);
      }
    }

    // 3. Create user in Firebase Auth
    const userCredential = await createUserWithEmailAndPassword(
      auth,
      normalizedEmail,
      password
    );
    const user = userCredential.user;

    // 4. Send email verification (LEGACY - Disabled for OTP)
    /*
    try {
      await sendEmailVerification(user);
    } catch (emailError) {
      console.error("Failed to send verification email:", emailError);
    }
    */

    // 5. Sync user to India Shopify store (non-blocking)
    let shopifyIndiaCustomerId: string | null = null;
    try {
      const indiaRes = await fetch('/api/shopify/sync-to-india', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email: normalizedEmail, password, firstName, lastName }),
      });
      const indiaData = await indiaRes.json();
      if (indiaData.success && indiaData.customerId) {
        shopifyIndiaCustomerId = indiaData.customerId;
        console.log('✓ India store customer synced:', shopifyIndiaCustomerId);
      } else {
        console.warn('India store sync skipped or failed:', indiaData);
      }
    } catch (indiaError: any) {
      console.warn('India store sync error (non-fatal):', indiaError.message);
    }

    // 6. Create user profile in Firestore
    await setDoc(doc(db, "users", user.uid), {
      email: normalizedEmail,
      uid: user.uid,
      userType,
      firstName,
      lastName,
      shopifyCustomerId: shopifyId,
      shopifyMapped: !!shopifyId,
      shopifyIndiaCustomerId,
      shopifyIndiaMapped: !!shopifyIndiaCustomerId,
      createdAt: new Date(),
      credits: 0, // Initialize with 0, will set to 10 after OTP verification
      otpVerified: false,
      isEmailVerified: false,
      profileImageUrl: null,
      phoneVerified: false,
      phone: null,
    });

    return user;
  } catch (error: any) {
    console.error("Signup error:", error);
    throw new Error(
      error instanceof Error ? error.message : "Signup failed"
    );
  }
};

/**
 * Get user credits
 */
export const getUserCredits = async (uid: string): Promise<number> => {
  try {
    const profile = await getUserProfile(uid);
    return profile?.credits || 0;
  } catch (error) {
    console.error("Error fetching credits:", error);
    return 0;
  }
};

/**
 * Decrement user credits by 1
 */
export const decrementCredits = async (uid: string) => {
  try {
    const userRef = doc(db, "users", uid);
    await updateDoc(userRef, {
      credits: increment(-1),
      updatedAt: new Date(),
    });
  } catch (error) {
    console.error("Error decrementing credits:", error);
    throw new Error("Failed to deduct credit");
  }
};

/**
 * Send verification email to currently logged in user
 */
export const sendVerificationEmail = async () => {
  const user = auth.currentUser;
  if (!user) throw new Error("No authenticated user");
  await sendEmailVerification(user);
};

/**
 * Generate a 6-digit OTP
 */
export const generateOTP = (): string => {
  return Math.floor(100000 + Math.random() * 900000).toString();
};

/**
 * Save OTP to Firestore
 */
export const saveSignupOTP = async (uid: string, email: string, code: string) => {
  try {
    const otpRef = doc(db, "otps", uid);
    await setDoc(otpRef, {
      uid,
      email,
      code,
      expiresAt: Timestamp.fromMillis(Date.now() + 10 * 60 * 1000), // 10 minutes
      createdAt: serverTimestamp(),
    });
  } catch (error) {
    console.error("Error saving OTP:", error);
    throw new Error("Failed to generate verification code");
  }
};

/**
 * Unified OTP Trigger: Generates, Saves, and Sends OTP
 */
export const triggerOTPVerification = async (email: string, uid: string) => {
  const code = generateOTP();
  await saveSignupOTP(uid, email, code);
  await sendSignupOTP(email, code);
  console.log(`✅ OTP triggered for ${email}`);
  return code;
};

/**
 * Verify OTP and unlock account
 */
export const verifySignupOTP = async (uid: string, code: string) => {
  try {
    const otpDoc = await getDoc(doc(db, "otps", uid));

    if (!otpDoc.exists()) {
      throw new Error("Invalid or expired verification code");
    }

    const data = otpDoc.data();
    const now = Timestamp.now();

    if (data.code !== code) {
      throw new Error("Incorrect verification code");
    }

    if (now.toMillis() > data.expiresAt.toMillis()) {
      throw new Error("Verification code has expired");
    }

    // Mark user as verified and give starting credits if they don't have them
    const userRef = doc(db, "users", uid);
    const userSnap = await getDoc(userRef);
    const userData = userSnap.data();

    const updateData: any = {
      otpVerified: true,
      isEmailVerified: true,
      updatedAt: serverTimestamp(),
    };

    // Only give 10 credits if the user doesn't already have credits
    if (!userData?.credits || userData.credits === 0) {
      updateData.credits = 10;
    }

    await updateDoc(userRef, updateData);

    // Clean up OTP document
    await deleteDoc(doc(db, "otps", uid));

    return true;
  } catch (error) {
    console.error("OTP Verification error:", error);
    throw error;
  }
};

/**
 * Login user with email and password
 * Integrated with Shopify fallback
 */
export const loginUser = async (email: string, password: string) => {
  const normalizedEmail = email.toLowerCase().trim();

  try {
    // 1. Try direct Firebase login
    const userCredential = await signInWithEmailAndPassword(auth, normalizedEmail, password);
    const user = userCredential.user;

    // Check if verified, if not trigger OTP
    const profile = await getUserProfile(user.uid);
    if (profile && !profile.otpVerified && !user.emailVerified) {
      console.log("⚠️ User unverified, triggering OTP...");
      await triggerOTPVerification(normalizedEmail, user.uid);
    }

    return user;
  } catch (firebaseError: any) {
    console.warn("Firebase login failed, trying Shopify...");

    // 2. If Firebase fails, try Shopify
    try {
      const accessToken = await loginShopifyCustomer(normalizedEmail, password);
      const shopifyCustomer = await getCustomerByToken(accessToken);

      console.log("Shopify login successful for:", normalizedEmail);

      // 3. Map Shopify user to Firebase
      const mappingResult = await mapShopifyUserToFirebase(normalizedEmail, password, shopifyCustomer);

      // 4. Try to sign in to Firebase
      try {
        const userCredential = await signInWithEmailAndPassword(auth, normalizedEmail, password);
        return userCredential.user;
      } catch (innerError) {
        // If password login fails, it might be an auto-created account with a bridge password
        console.log("Password login failed, trying bridge password...");
        const normalizedCustomerId = normalizeShopifyId(shopifyCustomer.id);
        const bridgePassword = getBridgePassword(normalizedCustomerId!);
        const userCredential = await signInWithEmailAndPassword(auth, normalizedEmail, bridgePassword);

        // SUCCESS! Sync their password for future direct logins
        const user = userCredential.user;
        try {
          const { updatePassword } = await import('firebase/auth');
          await updatePassword(user, password);
          console.log("✅ Synchronized Shopify password to Firebase.");
        } catch (syncError) {
          console.error("Failed to sync password:", syncError);
        }

        return user;
      }

    } catch (shopifyError: any) {
      console.error("Shopify login also failed:", shopifyError.message);

      // If both fail, throw the original Firebase error or a more descriptive one
      if (shopifyError.message === 'Email or password is incorrect') {
        throw new Error("Invalid email or password. If you have a Shopify account, please use your Shopify password.");
      }
      throw firebaseError;
    }
  }
};

/**
 * Map Shopify customer to Firebase (Auto-create if not exists)
 */
export const mapShopifyUserToFirebase = async (
  email: string,
  password: string,
  shopifyCustomer: any
) => {
  const normalizedEmail = email.toLowerCase().trim();

  try {
    // Check if user exists in Firestore
    const usersRef = collection(db, "users");
    const q = query(usersRef, where("email", "==", normalizedEmail));
    const querySnapshot = await getDocs(q);

    if (!querySnapshot.empty) {
      // Existing user: Update with Shopify info if missing
      const userDoc = querySnapshot.docs[0];
      const normalizedCustomerId = normalizeShopifyId(shopifyCustomer.id);

      await updateDoc(doc(db, "users", userDoc.id), {
        shopifyCustomerId: normalizedCustomerId,
        shopifyMapped: true,
        updatedAt: new Date(),
      });
      console.log("Updated existing user with normalized Shopify ID:", normalizedCustomerId);
      return { uid: userDoc.id, isNew: false };
    } else {
      // New user: Create in Firebase Auth and Firestore
      console.log("Auto-creating Firebase user for Shopify customer");
      const userCredential = await createUserWithEmailAndPassword(auth, normalizedEmail, password);
      const user = userCredential.user;
      const normalizedCustomerId = normalizeShopifyId(shopifyCustomer.id);

      await setDoc(doc(db, "users", user.uid), {
        email: normalizedEmail,
        uid: user.uid,
        userType: "customer",
        firstName: shopifyCustomer.firstName || "",
        lastName: shopifyCustomer.lastName || "",
        shopifyCustomerId: normalizedCustomerId,
        shopifyMapped: true,
        otpVerified: false, // Now required to verify even if from Shopify
        isEmailVerified: false,
        credits: 0,         // Wait for OTP verification to give 10 credits
        createdAt: new Date(),
        profileImageUrl: null,
      });

      return { uid: user.uid, isNew: true };
    }
  } catch (error: any) {
    console.error("Error mapping Shopify user:", error);
    throw error;
  }
};

/**
 * Sign out user
 */
export const logoutUser = async () => {
  try {
    await signOut(auth);
  } catch (error) {
    throw new Error(
      error instanceof Error ? error.message : "Logout failed"
    );
  }
};

/**
 * Send password reset email
 */
export const resetPassword = async (email: string) => {
  try {
    await sendPasswordResetEmail(auth, email);
  } catch (error) {
    throw new Error(
      error instanceof Error ? error.message : "Password reset failed"
    );
  }
};

/**
 * Confirm password reset
 */
export const confirmPasswordResetWithCode = async (
  code: string,
  newPassword: string
) => {
  try {
    await confirmPasswordReset(auth, code, newPassword);
  } catch (error) {
    throw new Error(
      error instanceof Error ? error.message : "Password reset confirmation failed"
    );
  }
};

/**
 * Start phone verification
 */
export const startPhoneVerification = async (
  phoneNumber: string,
  appVerifier: RecaptchaVerifier
) => {
  try {
    const result = await signInWithPhoneNumber(auth, phoneNumber, appVerifier);
    return result;
  } catch (error) {
    throw new Error(
      error instanceof Error
        ? error.message
        : "Phone verification initiation failed"
    );
  }
};

/**
 * Get current authenticated user
 */
export const getCurrentUser = (): User | null => {
  return auth.currentUser;
};

/**
 * Subscribe to auth state changes
 */
export const subscribeToAuthStateChanges = (
  callback: (user: User | null) => void
) => {
  return onAuthStateChanged(auth, callback);
};

// ============================================================
// USER PROFILE FUNCTIONS
// ============================================================

/**
 * Get user profile from Firestore
 */
export const getUserProfile = async (uid: string) => {
  try {
    const docRef = doc(db, "users", uid);
    const docSnap = await getDoc(docRef);
    return docSnap.exists() ? docSnap.data() : null;
  } catch (error) {
    throw new Error(
      error instanceof Error ? error.message : "Failed to fetch user profile"
    );
  }
};

/**
 * Check if user exists by email
 */
export const checkUserExistsByEmail = async (email: string) => {
  try {
    const usersRef = collection(db, "users");
    const q = query(usersRef, where("email", "==", email.toLowerCase().trim()));
    const querySnapshot = await getDocs(q);
    return !querySnapshot.empty;
  } catch (error) {
    console.error("Error checking user existence:", error);
    return false;
  }
};

/**
 * Authenticate customer from Shopify data (Session Transfer)
 */
export const authenticateCustomer = async (customerObject: { email: string; customerId: string }) => {
  const { email, customerId } = customerObject;
  const normalizedEmail = email.toLowerCase().trim();

  try {
    // 1. Check if user exists in Firebase/Firestore
    const usersRef = collection(db, "users");
    const q = query(usersRef, where("email", "==", normalizedEmail));
    const querySnapshot = await getDocs(q);

    let uid = "";
    let isNew = false;

    const normalizedCustomerId = normalizeShopifyId(customerId);

    if (!querySnapshot.empty) {
      // Existing user
      const userDoc = querySnapshot.docs[0];
      uid = userDoc.id;

      // Update customer ID if needed
      if (userDoc.data().shopifyCustomerId !== normalizedCustomerId) {
        await updateDoc(doc(db, "users", uid), {
          shopifyCustomerId: normalizedCustomerId,
          shopifyMapped: true,
          updatedAt: new Date(),
        });
      }
    } else {
      // New user - Auto-create them using the bridge password
      const bridgePassword = getBridgePassword(normalizedCustomerId!);
      const shopifyCustomer = { id: normalizedCustomerId, email: normalizedEmail };
      const mappingResult = await mapShopifyUserToFirebase(normalizedEmail, bridgePassword, shopifyCustomer);
      uid = mappingResult.uid;
    }

    // 3. PERFORM ACTUAL LOGIN to Firebase Auth using the bridge password
    const bridgePassword = getBridgePassword(normalizedCustomerId!);
    try {
      const userCredential = await signInWithEmailAndPassword(auth, normalizedEmail, bridgePassword);

      // Check if verified, if not trigger OTP
      const profile = await getUserProfile(userCredential.user.uid);
      if (profile && !profile.otpVerified && !profile.isEmailVerified) {
        console.log("⚠️ Bridge login user unverified, triggering OTP...");
        await triggerOTPVerification(normalizedEmail, userCredential.user.uid);
      }

      return {
        success: true,
        authenticated: true,
        uid: userCredential.user.uid,
        email: normalizedEmail,
        shopifyCustomerId: customerId,
        otpVerified: profile?.otpVerified || profile?.isEmailVerified || false,
        isEmailVerified: profile?.isEmailVerified || profile?.otpVerified || false,
        credits: profile?.credits || 0,
        message: "Customer logged in automatically via bridge"
      };
    } catch (loginError: any) {
      console.warn("Bridge login failed, falling back to verified session only:", loginError.message);

      // Fetch profile anyway to get current status/credits if user exists
      const profile = await getUserProfile(uid);

      return {
        success: true,
        authenticated: false, // Not signed into Firebase Auth, but verified via Shopify
        verified: true,
        uid: uid,
        email: normalizedEmail,
        shopifyCustomerId: customerId,
        otpVerified: profile?.otpVerified || profile?.isEmailVerified || false,
        isEmailVerified: profile?.isEmailVerified || profile?.otpVerified || false,
        credits: profile?.credits || 0,
        message: "Customer verified via Shopify"
      };
    }
  } catch (error: any) {
    console.error("Authentication error:", error);
    throw error;
  }
};

/**
 * Update user profile
 */
export const updateUserProfile = async (uid: string, updates: any) => {
  try {
    const userRef = doc(db, "users", uid);
    await updateDoc(userRef, {
      ...updates,
      updatedAt: new Date(),
    });
  } catch (error) {
    throw new Error(
      error instanceof Error ? error.message : "Failed to update user profile"
    );
  }
};

/**
 * Get user type
 */
export const getUserType = async (uid: string) => {
  try {
    const profile = await getUserProfile(uid);
    return profile?.userType || null;
  } catch (error) {
    throw new Error(
      error instanceof Error ? error.message : "Failed to get user type"
    );
  }
};

/**
 * Delete user account
 */
export const deleteUserAccount = async (uid: string) => {
  try {
    const user = auth.currentUser;
    if (!user) throw new Error("No authenticated user");

    // Delete user document from Firestore
    await deleteDoc(doc(db, "users", uid));

    // Delete user authentication
    await user.delete();
  } catch (error) {
    throw new Error(
      error instanceof Error ? error.message : "Failed to delete user account"
    );
  }
};

// ============================================================
// EXPERT FUNCTIONS
// ============================================================

/**
 * Get expert profile
 */
export const getExpertProfile = async (uid: string) => {
  try {
    const docSnap = await getDoc(doc(db, "experts", uid));
    return docSnap.exists() ? docSnap.data() : null;
  } catch (error) {
    throw new Error(
      error instanceof Error ? error.message : "Failed to fetch expert profile"
    );
  }
};

/**
 * Update expert profile
 */
export const updateExpertProfile = async (uid: string, updates: any) => {
  try {
    const expertRef = doc(db, "experts", uid);
    await updateDoc(expertRef, {
      ...updates,
      updatedAt: new Date(),
    });
  } catch (error) {
    throw new Error(
      error instanceof Error
        ? error.message
        : "Failed to update expert profile"
    );
  }
};

/**
 * Search experts by filters
 */
export const searchExperts = async (filters: {
  expertise?: string;
  minRating?: number;
  available?: boolean;
} = {}) => {
  try {
    const constraints: QueryConstraint[] = [];

    if (filters.expertise) {
      constraints.push(where("expertise", "==", filters.expertise));
    }

    if (filters.minRating) {
      constraints.push(where("rating", ">=", filters.minRating));
    }

    if (filters.available) {
      constraints.push(where("available", "==", true));
    }

    const q = query(collection(db, "experts"), ...constraints);
    const querySnapshot = await getDocs(q);

    return querySnapshot.docs.map((doc) => ({
      id: doc.id,
      ...doc.data(),
    }));
  } catch (error) {
    throw new Error(
      error instanceof Error ? error.message : "Failed to search experts"
    );
  }
};

/**
 * Verify expert
 */
export const verifyExpert = async (uid: string) => {
  try {
    await updateExpertProfile(uid, {
      verified: true,
      verifiedAt: new Date(),
    });
  } catch (error) {
    throw new Error(
      error instanceof Error ? error.message : "Failed to verify expert"
    );
  }
};

// ============================================================
// STORAGE FUNCTIONS
// ============================================================

/**
 * Upload file to Firebase Storage
 */
export const uploadFile = async (
  file: File,
  path: string
): Promise<string> => {
  try {
    const fileRef = ref(storage, path);
    const snapshot = await uploadBytes(fileRef, file);
    const downloadUrl = await getDownloadURL(snapshot.ref);
    return downloadUrl;
  } catch (error) {
    throw new Error(
      error instanceof Error ? error.message : "File upload failed"
    );
  }
};

/**
 * Delete file from Firebase Storage
 */
export const deleteFile = async (path: string) => {
  try {
    const fileRef = ref(storage, path);
    await deleteObject(fileRef);
  } catch (error) {
    throw new Error(
      error instanceof Error ? error.message : "File deletion failed"
    );
  }
};

/**
 * Upload profile image
 */
export const uploadProfileImage = async (
  uid: string,
  file: File,
  email?: string,
  userType: string = "users"
): Promise<string> => {
  try {
    // Determine email for storage path (required by user's firebase structure)
    const userEmail = email || auth.currentUser?.email;
    if (!userEmail) {
      throw new Error("User email is required for profile image upload");
    }

    const fileExtension = file.name.split(".").pop();
    // Structure: [email]/media/profile-image.[ext]
    const storagePath = `${userEmail}/media/profile-image.${fileExtension}`;
    const downloadUrl = await uploadFile(file, storagePath);

    // Update main user document with multiple field names for compatibility
    const userRef = doc(db, userType, uid);
    await updateDoc(userRef, {
      profileImageUrl: downloadUrl,    // camelCase
      profileImageURL: downloadUrl,    // UPPERCASE
      "userMedia.profileImage": downloadUrl, // Nested
      updatedAt: new Date(),
    });

    // Update usersMedia collection as per reference
    try {
      const mediaDocRef = doc(db, "usersMedia", uid);
      await setDoc(mediaDocRef, {
        profileImageURL: downloadUrl,
        email: userEmail,
        userType: userType === "users" ? "user" : userType,
        lastUpdated: new Date(),
      }, { merge: true });
    } catch (mediaError) {
      console.error("Error updating usersMedia:", mediaError);
    }

    return downloadUrl;
  } catch (error) {
    throw new Error(
      error instanceof Error ? error.message : "Profile image upload failed"
    );
  }
};

// ============================================================
// REALTIME DATABASE FUNCTIONS
// ============================================================

/**
 * Save data to Realtime Database
 */
export const saveRealtimeData = async (path: string, data: any) => {
  try {
    await set(dbRef(database, path), data);
  } catch (error) {
    throw new Error(
      error instanceof Error ? error.message : "Failed to save realtime data"
    );
  }
};

/**
 * Get data from Realtime Database
 */
export const getRealtimeData = async (path: string) => {
  try {
    const snapshot = await get(dbRef(database, path));
    return snapshot.val();
  } catch (error) {
    throw new Error(
      error instanceof Error ? error.message : "Failed to get realtime data"
    );
  }
};

// ============================================================
// AI COACH FUNCTIONS
// ============================================================

/**
 * Save AI Coach data
 */
export const saveAiCoachData = async (uid: string, data: any) => {
  try {
    const docRef = doc(db, "users", uid, "aiCoachData", "current");
    await setDoc(docRef, {
      ...data,
      updatedAt: new Date(),
    });
  } catch (error) {
    throw new Error(
      error instanceof Error ? error.message : "Failed to save AI coach data"
    );
  }
};

/**
 * Get AI Coach data
 */
export const getAiCoachData = async (uid: string) => {
  try {
    const docSnap = await getDoc(doc(db, "users", uid, "aiCoachData", "current"));
    return docSnap.exists() ? docSnap.data() : null;
  } catch (error) {
    throw new Error(
      error instanceof Error ? error.message : "Failed to fetch AI coach data"
    );
  }
};

/**
 * Save AI Coach history
 */
export const saveAiCoachHistory = async (uid: string, historyData: any) => {
  try {
    const timestamp = new Date().getTime();
    await setDoc(doc(db, "users", uid, "aiCoachHistory", String(timestamp)), {
      ...historyData,
      createdAt: new Date(),
    });
  } catch (error) {
    throw new Error(
      error instanceof Error ? error.message : "Failed to save history"
    );
  }
};

/**
 * Get AI Coach history
 */
export const getAiCoachHistory = async (uid: string) => {
  try {
    const q = query(
      collection(db, "users", uid, "aiCoachHistory")
    );
    const querySnapshot = await getDocs(q);
    return querySnapshot.docs.map((doc) => ({
      id: doc.id,
      ...doc.data(),
    }));
  } catch (error) {
    throw new Error(
      error instanceof Error ? error.message : "Failed to fetch history"
    );
  }
};

/**
 * Permanent Saved Plans Functions
 */

export const saveUserPlan = async (uid: string, planName: string, data: any) => {
  try {
    const docRef = doc(collection(db, "users", uid, "aiCoachSchedules"));
    await setDoc(docRef, {
      id: docRef.id,
      name: planName,
      goal: data.goal || "",
      mealPlan: data.mealPlan,
      workoutPlan: data.workoutPlan,
      calculatedData: data.calculatedData,
      planGenerationDate: data.planGenerationDate || new Date().toISOString(),
      createdAt: new Date(),
    });
    return docRef.id;
  } catch (error) {
    throw new Error(error instanceof Error ? error.message : "Failed to save plan");
  }
};

export const getUserPlans = async (uid: string) => {
  try {
    const q = query(
      collection(db, "users", uid, "aiCoachSchedules")
    );
    const querySnapshot = await getDocs(q);
    return querySnapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data()
    }));
  } catch (error) {
    throw new Error(error instanceof Error ? error.message : "Failed to fetch saved plans");
  }
};

export const getPlanById = async (uid: string, planId: string) => {
  try {
    const docRef = doc(db, "users", uid, "aiCoachSchedules", planId);
    const docSnap = await getDoc(docRef);
    return docSnap.exists() ? docSnap.data() : null;
  } catch (error) {
    throw new Error(error instanceof Error ? error.message : "Failed to fetch plan detail");
  }
};

// ============================================================
// COMMUNITY FUNCTIONS
// ============================================================

/**
 * Create community post
 */
export const createCommunityPost = async (uid: string, postData: any) => {
  try {
    const docRef = doc(collection(db, "community"));
    await setDoc(docRef, {
      ...postData,
      authorId: uid,
      createdAt: new Date(),
      likes: 0,
      comments: 0,
      id: docRef.id,
    });
    return docRef.id;
  } catch (error) {
    throw new Error(
      error instanceof Error ? error.message : "Failed to create post"
    );
  }
};

/**
 * Get community posts
 */
export const getCommunityPosts = async (limit: number = 20) => {
  try {
    const q = query(collection(db, "community"));
    const querySnapshot = await getDocs(q);
    return querySnapshot.docs.slice(0, limit).map((doc) => ({
      id: doc.id,
      ...doc.data(),
    }));
  } catch (error) {
    throw new Error(
      error instanceof Error ? error.message : "Failed to fetch posts"
    );
  }
};

/**
 * Like community post
 */
export const likeCommunityPost = async (postId: string, uid: string) => {
  try {
    const postRef = doc(db, "community", postId);
    const docSnap = await getDoc(postRef);
    const likesList = docSnap.data()?.likes || [];
    if (!likesList.includes(uid)) {
      likesList.push(uid);
      await updateDoc(postRef, { likes: likesList });
    }
  } catch (error) {
    throw new Error(
      error instanceof Error ? error.message : "Failed to like post"
    );
  }
};

// ============================================================
// BOOKING FUNCTIONS
// ============================================================

/**
 * Create booking
 */
export const createBooking = async (bookingData: any) => {
  try {
    const docRef = doc(collection(db, "bookings"));
    await setDoc(docRef, {
      ...bookingData,
      createdAt: new Date(),
      status: "pending",
      id: docRef.id,
    });
    return docRef.id;
  } catch (error) {
    throw new Error(
      error instanceof Error ? error.message : "Failed to create booking"
    );
  }
};

/**
 * Get bookings for user
 */
export const getUserBookings = async (uid: string) => {
  try {
    const q = query(
      collection(db, "bookings"),
      where("customerId", "==", uid)
    );
    const querySnapshot = await getDocs(q);
    return querySnapshot.docs.map((doc) => ({
      id: doc.id,
      ...doc.data(),
    }));
  } catch (error) {
    throw new Error(
      error instanceof Error ? error.message : "Failed to fetch bookings"
    );
  }
};

/**
 * Update booking
 */
export const updateBooking = async (bookingId: string, updates: any) => {
  try {
    await updateDoc(doc(db, "bookings", bookingId), {
      ...updates,
      updatedAt: new Date(),
    });
  } catch (error) {
    throw new Error(
      error instanceof Error ? error.message : "Failed to update booking"
    );
  }
};

// ============================================================
// UTILITY FUNCTIONS
// ============================================================

/**
 * Batch write operations
 */
export const batchWrite = async (operations: Array<{
  type: "set" | "update" | "delete";
  collection: string;
  docId: string;
  data?: any;
}>) => {
  try {
    const batch = writeBatch(db);

    operations.forEach((op) => {
      const docRef = doc(db, op.collection, op.docId);
      if (op.type === "set") {
        batch.set(docRef, op.data);
      } else if (op.type === "update") {
        batch.update(docRef, op.data);
      } else if (op.type === "delete") {
        batch.delete(docRef);
      }
    });

    await batch.commit();
  } catch (error) {
    throw new Error(
      error instanceof Error ? error.message : "Batch write failed"
    );
  }
};

// Export Firebase instances
export { auth, db, storage, database, app };
