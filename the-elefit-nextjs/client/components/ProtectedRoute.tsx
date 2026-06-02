import React from "react";
import { Navigate } from "react-router-dom";
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

  if (loading) {
    return (
      <div className="flex items-center justify-center min-h-screen">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary"></div>
      </div>
    );
  }

  if (!isAuthenticated) {
    return <Navigate to="/auth/login" replace />;
  }

  if (requiredUserType && userType !== requiredUserType) {
    return <Navigate to="/" replace />;
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

  if (loading) {
    return (
      <div className="flex items-center justify-center min-h-screen">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary"></div>
      </div>
    );
  }

  if (isAuthenticated) {
    return <Navigate to="/" replace />;
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

  if (loading) {
    return (
      <div className="flex items-center justify-center min-h-screen">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary"></div>
      </div>
    );
  }

  if (!isAuthenticated) {
    return <Navigate to="/auth/login" replace />;
  }

  if (userType && !allowedRoles.includes(userType)) {
    return <Navigate to="/unauthorized" replace />;
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
    <div className="flex flex-col items-center justify-center min-h-screen bg-background">
      <div className="text-center">
        <h1 className="text-4xl font-bold text-foreground mb-4">403</h1>
        <p className="text-lg text-muted-foreground mb-6">
          You don't have permission to access this page
        </p>
        <a
          href="/"
          className="inline-block px-6 py-2 bg-primary text-primary-foreground rounded-lg hover:bg-primary/90"
        >
          Go Home
        </a>
      </div>
    </div>
  );
};
