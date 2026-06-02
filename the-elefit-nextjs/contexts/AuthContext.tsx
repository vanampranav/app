import React, { createContext, ReactNode } from "react";
import { User } from "firebase/auth";
import {
  subscribeToAuthStateChanges,
  loginUser,
  signupUser,
  logoutUser,
  getUserProfile,
  getUserType,
  authenticateCustomer
} from "@/shared/firebase";

export interface AuthUser extends User {
  userType?: "customer" | "expert" | "admin" | null;
  shopifyMapped?: boolean;
  shopifyCustomerId?: string | null;
  credits?: number;
  otpVerified?: boolean;
  isEmailVerified?: boolean;
}

export interface AuthContextType {
  user: AuthUser | null;
  loading: boolean;
  error: string | null;
  login: (email: string, password: string) => Promise<User>;
  signup: (
    email: string,
    password: string,
    userType: "customer" | "expert" | "admin",
    firstName: string,
    lastName: string
  ) => Promise<User>;
  logout: () => Promise<void>;
  userType: "customer" | "expert" | "admin" | null;
  isAuthenticated: boolean;
  authenticate: (sessionData: any) => void;
  refreshProfile: () => Promise<void>;
}

export const AuthContext = createContext<AuthContextType | undefined>(
  undefined
);

interface AuthProviderProps {
  children: ReactNode;
}

export const AuthProvider: React.FC<AuthProviderProps> = ({ children }) => {
  const [user, setUser] = React.useState<AuthUser | null>(null);
  const [loading, setLoading] = React.useState(true);
  const [error, setError] = React.useState<string | null>(null);
  const [userType, setUserType] = React.useState<
    "customer" | "expert" | "admin" | null
  >(null);

  // Subscribe to auth state changes
  React.useEffect(() => {
    // 1. Check for verified customer session first (for automatic login from theelefit.com)
    const checkVerifiedSession = async () => {
      if (typeof window !== 'undefined') {
        const verifiedSession = localStorage.getItem('verifiedCustomerSession');
        if (verifiedSession) {
          try {
            const sessionData = JSON.parse(verifiedSession);
            const sessionAge = Date.now() - sessionData.timestamp;
            const maxAge = 30 * 60 * 1000; // 30 minutes

            if (sessionAge < maxAge && sessionData.verified) {
              console.log('🔐 AuthProvider: Valid verified session found, setting local state');
              // Create a mock user object to satisfy the context
              const mockUser = {
                uid: sessionData.uid,
                email: sessionData.email,
                userType: sessionData.userType || 'customer',
                shopifyCustomerId: sessionData.customerId,
                shopifyMapped: true,
                credits: sessionData.credits || 0,
                otpVerified: !!sessionData.otpVerified,
                isEmailVerified: !!sessionData.isEmailVerified,
              } as AuthUser;

              setUser(mockUser);
              setUserType(mockUser.userType as any);
              setLoading(false);
              return true;
            } else {
              localStorage.removeItem('verifiedCustomerSession');
            }
          } catch (e) {
            console.error('Error parsing verified session:', e);
            localStorage.removeItem('verifiedCustomerSession');
          }
        }
      }
      return false;
    };

    const unsubscribe = subscribeToAuthStateChanges(async (firebaseUser) => {
      try {
        // 1. Check for verified session as a fast-path fallback
        const hasVerifiedSession = await checkVerifiedSession();

        if (firebaseUser) {
          // Fetch fresh profile regardless of local session to ensure sync
          const profile = await getUserProfile(firebaseUser.uid);
          let currentCredits = profile?.credits || 0;
          let currentOtpVerified = profile?.otpVerified || false;
          let currentIsEmailVerified = profile?.isEmailVerified || profile?.otpVerified || false;

          // LEGACY CREDIT GIFT: If user is verified but has 0 credits, grant 10
          if ((firebaseUser.emailVerified || currentOtpVerified) && (profile?.credits === undefined || profile?.credits === 0)) {
            console.log("🎁 Gifting 10 credits to legacy verified user:", firebaseUser.email);
            const { doc, updateDoc, getFirestore } = await import('firebase/firestore');
            const db = getFirestore();
            await updateDoc(doc(db, "users", firebaseUser.uid), {
              credits: 10,
              updatedAt: new Date()
            });
            currentCredits = 10;
          }

          const freshUser = {
            ...firebaseUser,
            userType: profile?.userType || null,
            shopifyMapped: profile?.shopifyMapped || false,
            shopifyCustomerId: profile?.shopifyCustomerId || null,
            credits: currentCredits,
            otpVerified: currentOtpVerified,
            isEmailVerified: currentIsEmailVerified,
          } as AuthUser;

          setUser(freshUser);
          setUserType(profile?.userType || null);

          // Update local session storage with fresh data
          if (typeof window !== 'undefined' && profile?.otpVerified) {
            localStorage.setItem('verifiedCustomerSession', JSON.stringify({
              uid: firebaseUser.uid,
              email: firebaseUser.email,
              customerId: profile.shopifyCustomerId,
              verified: true,
              timestamp: Date.now(),
              credits: currentCredits,
              otpVerified: currentOtpVerified,
              isEmailVerified: currentIsEmailVerified,
              userType: profile.userType
            }));
          }
        } else if (!hasVerifiedSession) {
          setUser(null);
          setUserType(null);
        }
      } catch (err) {
        console.error("Error fetching user profile:", err);
        setError(
          err instanceof Error ? err.message : "Failed to fetch user profile"
        );
      } finally {
        setLoading(false);
      }
    });

    return () => unsubscribe();
  }, []);

  const authenticate = (sessionData: any) => {
    const mockUser = {
      uid: sessionData.uid,
      email: sessionData.email,
      userType: sessionData.userType || 'customer',
      shopifyCustomerId: sessionData.customerId,
      shopifyMapped: true,
      credits: sessionData.credits || 0,
      otpVerified: !!sessionData.otpVerified,
      isEmailVerified: !!sessionData.isEmailVerified,
    } as AuthUser;

    setUser(mockUser);
    setUserType(mockUser.userType as any);
    setLoading(false);
  };

  const refreshProfile = async () => {
    if (!user) return;
    try {
      const profile = await getUserProfile(user.uid);
      const isOtpVerified = profile?.otpVerified || profile?.isEmailVerified || false;
      const isEmailVerified = profile?.isEmailVerified || profile?.otpVerified || false;
      const credits = profile?.credits || 0;

      setUser(prev => prev ? {
        ...prev,
        ...profile,
        otpVerified: isOtpVerified,
        isEmailVerified: isEmailVerified,
        credits: credits,
      } : null);

      // Keep local session storage in sync
      if (typeof window !== 'undefined' && isOtpVerified) {
        localStorage.setItem('verifiedCustomerSession', JSON.stringify({
          uid: user.uid,
          email: user.email,
          customerId: profile?.shopifyCustomerId,
          verified: true,
          timestamp: Date.now(),
          credits: credits,
          otpVerified: isOtpVerified,
          isEmailVerified: isEmailVerified,
          userType: profile?.userType
        }));
      }
    } catch (err) {
      console.error("Error refreshing profile:", err);
    }
  };

  const login = async (email: string, password: string) => {
    try {
      setError(null);
      setLoading(true);
      const firebaseUser = await loginUser(email, password);

      // Fetch user type
      const profile = await getUserProfile(firebaseUser.uid);
      const type = profile?.userType || null;

      const authUser = {
        ...firebaseUser,
        userType: type,
        shopifyMapped: profile?.shopifyMapped || false,
        shopifyCustomerId: profile?.shopifyCustomerId || null,
        credits: profile?.credits || 0,
        otpVerified: profile?.otpVerified || false,
        isEmailVerified: profile?.isEmailVerified || profile?.otpVerified || false,
      } as AuthUser;

      setUser(authUser);
      setUserType(type);
      return authUser;
    } catch (err) {
      const errorMessage =
        err instanceof Error ? err.message : "Login failed";
      setError(errorMessage);
      throw err;
    } finally {
      setLoading(false);
    }
  };

  const signup = async (
    email: string,
    password: string,
    userTypeValue: "customer" | "expert" | "admin",
    firstName: string,
    lastName: string
  ) => {
    try {
      setError(null);
      setLoading(true);
      const firebaseUser = await signupUser(
        email,
        password,
        userTypeValue,
        firstName,
        lastName
      );

      const authUser = {
        ...firebaseUser,
        userType: userTypeValue,
        credits: 0,
        otpVerified: false,
        isEmailVerified: false,
      } as AuthUser;

      setUser(authUser);
      setUserType(userTypeValue);
      return authUser;
    } catch (err) {
      const errorMessage =
        err instanceof Error ? err.message : "Signup failed";
      setError(errorMessage);
      throw err;
    } finally {
      setLoading(false);
    }
  };

  const logout = async () => {
    try {
      setError(null);
      setLoading(true);
      await logoutUser();
      setUser(null);
      setUserType(null);
    } catch (err) {
      const errorMessage =
        err instanceof Error ? err.message : "Logout failed";
      setError(errorMessage);
      throw err;
    } finally {
      setLoading(false);
    }
  };

  return (
    <AuthContext.Provider
      value={{
        user,
        loading,
        error,
        login,
        signup,
        logout,
        userType,
        isAuthenticated: !!user,
        authenticate,
        refreshProfile,
      }}
    >
      {children}
    </AuthContext.Provider>
  );
};

/**
 * Hook to use auth context
 */
export const useAuth = () => {
  const context = React.useContext(AuthContext);
  if (!context) {
    throw new Error("useAuth must be used within AuthProvider");
  }
  return context;
};
