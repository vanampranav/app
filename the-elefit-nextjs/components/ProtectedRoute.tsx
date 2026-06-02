"use client";

import React, { useEffect } from "react";
import { useRouter } from "next/navigation";
import { useAuth } from "@/contexts/AuthContext";

interface ProtectedRouteProps {
  children: React.ReactNode;
  requiredUserType?: "customer" | "expert" | "admin";
}

/**
 * ProtectedRoute - Protects routes that require authentication
 */
export const ProtectedRoute: React.FC<ProtectedRouteProps> = ({
  children,
  requiredUserType,
}) => {
  const { isAuthenticated, loading, userType } = useAuth();
  const router = useRouter();

  useEffect(() => {
    if (!loading) {
      if (!isAuthenticated) {
        router.replace("/auth");
      } else if (requiredUserType && userType !== requiredUserType) {
        router.replace("/");
      }
    }
  }, [isAuthenticated, loading, userType, requiredUserType, router]);

  if (loading || !isAuthenticated || (requiredUserType && userType !== requiredUserType)) {
    return (
      <div className="flex items-center justify-center min-h-screen bg-black">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary"></div>
      </div>
    );
  }

  return <>{children}</>;
};

/**
 * PublicRoute - Prevents authenticated users from accessing auth pages
 */
export const PublicRoute: React.FC<{ children: React.ReactNode }> = ({
  children,
}) => {
  const { isAuthenticated, loading } = useAuth();
  const router = useRouter();

  useEffect(() => {
    if (!loading && isAuthenticated) {
      router.replace("/");
    }
  }, [isAuthenticated, loading, router]);

  if (loading || isAuthenticated) {
    return (
      <div className="flex items-center justify-center min-h-screen bg-black">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary"></div>
      </div>
    );
  }

  return <>{children}</>;
};

/**
 * RoleBasedRoute - Protects routes based on user role
 */
export const RoleBasedRoute: React.FC<{
  children: React.ReactNode;
  allowedRoles: ("customer" | "expert" | "admin")[];
}> = ({ children, allowedRoles }) => {
  const { isAuthenticated, loading, userType } = useAuth();
  const router = useRouter();

  useEffect(() => {
    if (!loading) {
      if (!isAuthenticated) {
        router.replace("/auth");
      } else if (userType && !allowedRoles.includes(userType)) {
        router.replace("/unauthorized");
      }
    }
  }, [isAuthenticated, loading, userType, allowedRoles, router]);

  if (loading || !isAuthenticated || (userType && !allowedRoles.includes(userType))) {
    return (
      <div className="flex items-center justify-center min-h-screen bg-black">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary"></div>
      </div>
    );
  }

  return <>{children}</>;
};

/**
 * AdminRoute - Protects admin-only routes
 */
export const AdminRoute: React.FC<{ children: React.ReactNode }> = ({
  children,
}) => {
  return (
    <RoleBasedRoute allowedRoles={["admin"]}>
      {children}
    </RoleBasedRoute>
  );
};

/**
 * ExpertRoute - Protects expert-only routes
 */
export const ExpertRoute: React.FC<{ children: React.ReactNode }> = ({
  children,
}) => {
  return (
    <ProtectedRoute requiredUserType="expert">
      {children}
    </ProtectedRoute>
  );
};

/**
 * CustomerRoute - Protects customer-only routes
 */
export const CustomerRoute: React.FC<{ children: React.ReactNode }> = ({
  children,
}) => {
  return (
    <ProtectedRoute requiredUserType="customer">
      {children}
    </ProtectedRoute>
  );
};

/**
 * Not Authorized Page
 */
export const UnauthorizedPage: React.FC = () => {
  return (
    <div className="flex flex-col items-center justify-center min-h-screen bg-black">
      <div className="text-center">
        <h1 className="text-4xl font-bold text-white mb-4">403</h1>
        <p className="text-lg text-[#AFAFAF] mb-6">
          You don't have permission to access this page
        </p>
        <button
          onClick={() => window.location.href = "/"}
          className="inline-block px-6 py-2 bg-primary text-black font-bold rounded-lg hover:bg-primary/90"
        >
          Go Home
        </button>
      </div>
    </div>
  );
};
