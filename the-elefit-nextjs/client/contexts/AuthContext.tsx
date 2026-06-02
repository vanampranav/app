import React, { createContext, ReactNode } from "react";
import { User } from "firebase/auth";
import {
  subscribeToAuthStateChanges,
  loginUser,
  signupUser,
  logoutUser,
  getUserProfile,
  getUserType,
} from "@shared/firebase";

export interface AuthUser extends User {
  userType?: "customer" | "expert" | "admin" | null;
}

export interface AuthContextType {
  user: AuthUser | null;
  loading: boolean;
  error: string | null;
  login: (email: string, password: string) => Promise<void>;
  signup: (
    email: string,
    password: string,
    userType: "customer" | "expert" | "admin",
    firstName: string,
    lastName: string
  ) => Promise<void>;
  logout: () => Promise<void>;
  userType: "customer" | "expert" | "admin" | null;
  isAuthenticated: boolean;
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
    const unsubscribe = subscribeToAuthStateChanges(async (firebaseUser) => {
      try {
        if (firebaseUser) {
          // Fetch user type from profile
          const profile = await getUserProfile(firebaseUser.uid);
          const type = profile?.userType || null;

          setUser({
            ...firebaseUser,
            userType: type,
          } as AuthUser);
          setUserType(type);
        } else {
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

  const login = async (email: string, password: string) => {
    try {
      setError(null);
      setLoading(true);
      const firebaseUser = await loginUser(email, password);

      // Fetch user type
      const profile = await getUserProfile(firebaseUser.uid);
      const type = profile?.userType || null;

      setUser({
        ...firebaseUser,
        userType: type,
      } as AuthUser);
      setUserType(type);
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

      setUser({
        ...firebaseUser,
        userType: userTypeValue,
      } as AuthUser);
      setUserType(userTypeValue);
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
