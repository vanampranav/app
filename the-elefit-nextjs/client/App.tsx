import "./global.css";

import { Toaster } from "@/components/ui/toaster";
import { createRoot } from "react-dom/client";
import { Toaster as Sonner } from "@/components/ui/sonner";
import { TooltipProvider } from "@/components/ui/tooltip";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { BrowserRouter, Routes, Route } from "react-router-dom";
import { AuthProvider } from "@/contexts/AuthContext";
import Index from "./pages/Index";
import NotFound from "./pages/NotFound";
import Community from "./pages/Community";
import FindExpert from "./pages/FindExpert";
import ApplyExpert from "./pages/ApplyExpert";
import Schedule from "./pages/Schedule";
import Profile from "./pages/Profile";
import AICoachWelcome from "./pages/AICoach/Welcome";
import AICoachGoal from "./pages/AICoach/Goal";
import AICoachDetails from "./pages/AICoach/Details";
import AICoachPreferences from "./pages/AICoach/Preferences";
import AICoachCalories from "./pages/AICoach/Calories";
import AuthPage from "./pages/Auth/AuthPage";
import CustomerAuth from "./pages/Auth/CustomerAuth";
import {
  ProtectedRoute,
  PublicRoute,
  UnauthorizedPage,
} from "./components/ProtectedRoute";

const queryClient = new QueryClient();

const App = () => (
  <QueryClientProvider client={queryClient}>
    <AuthProvider>
      <TooltipProvider>
        <Toaster />
        <Sonner />
        <BrowserRouter>
          <Routes>
            {/* Public Routes */}
            <Route path="/" element={<Index />} />
            <Route path="/unauthorized" element={<UnauthorizedPage />} />
            
            {/* Authentication Routes */}
            <Route path="/auth" element={<AuthPage />} />
            <Route path="/auth/customer" element={<CustomerAuth />} />
            
            {/* Protected Routes - AI Coach */}
            <Route
              path="/ai-coach"
              element={
                <ProtectedRoute>
                  <AICoachWelcome />
                </ProtectedRoute>
              }
            />
            <Route
              path="/ai-coach/welcome"
              element={
                <ProtectedRoute>
                  <AICoachWelcome />
                </ProtectedRoute>
              }
            />
            <Route
              path="/ai-coach/goal"
              element={
                <ProtectedRoute>
                  <AICoachGoal />
                </ProtectedRoute>
              }
            />
            <Route
              path="/ai-coach/details"
              element={
                <ProtectedRoute>
                  <AICoachDetails />
                </ProtectedRoute>
              }
            />
            <Route
              path="/ai-coach/preferences"
              element={
                <ProtectedRoute>
                  <AICoachPreferences />
                </ProtectedRoute>
              }
            />
            <Route
              path="/ai-coach/calories"
              element={
                <ProtectedRoute>
                  <AICoachCalories />
                </ProtectedRoute>
              }
            />
            
            {/* Protected Routes - Main Features */}
            <Route
              path="/community"
              element={
                <ProtectedRoute>
                  <Community />
                </ProtectedRoute>
              }
            />
            <Route
              path="/find-expert"
              element={
                <ProtectedRoute>
                  <FindExpert />
                </ProtectedRoute>
              }
            />
            <Route
              path="/apply-expert"
              element={
                <ProtectedRoute>
                  <ApplyExpert />
                </ProtectedRoute>
              }
            />
            <Route
              path="/schedule"
              element={
                <ProtectedRoute>
                  <Schedule />
                </ProtectedRoute>
              }
            />
            <Route
              path="/profile"
              element={
                <ProtectedRoute>
                  <Profile />
                </ProtectedRoute>
              }
            />
            
            {/* ADD ALL CUSTOM ROUTES ABOVE THE CATCH-ALL "*" ROUTE */}
            <Route path="*" element={<NotFound />} />
          </Routes>
        </BrowserRouter>
      </TooltipProvider>
    </AuthProvider>
  </QueryClientProvider>
);

createRoot(document.getElementById("root")!).render(<App />);
