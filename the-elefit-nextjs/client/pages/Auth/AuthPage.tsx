import { useState, useEffect } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { useAuth } from '@/contexts/AuthContext';
import Login from './Login';
import Signup from './Signup';
import { Alert, AlertDescription } from '@/components/ui/alert';
import { AlertCircle, CheckCircle2 } from 'lucide-react';

export default function AuthPage() {
  const navigate = useNavigate();
  const [searchParams] = useSearchParams();
  const { isAuthenticated, loading: authLoading, userType } = useAuth();

  // Page state
  const [isLogin, setIsLogin] = useState(true);
  const [message, setMessage] = useState('');
  const [messageType, setMessageType] = useState<'success' | 'error' | ''>('');

  // Check if user should be redirected
  useEffect(() => {
    if (!authLoading && isAuthenticated && userType) {
      // Redirect authenticated users
      const redirectPath = searchParams.get('redirect');
      
      if (redirectPath) {
        navigate(redirectPath, { replace: true });
      } else {
        // Redirect based on user type
        const defaultPath = userType === 'expert' ? '/expert-dashboard' : '/dashboard';
        navigate(defaultPath, { replace: true });
      }
    }
  }, [isAuthenticated, authLoading, userType, navigate, searchParams]);

  // Check for message in URL
  useEffect(() => {
    const msg = searchParams.get('message');
    const urlMessage = searchParams.get('error') ? 'error' : 'success';
    
    if (msg) {
      setMessage(decodeURIComponent(msg));
      setMessageType(urlMessage as 'success' | 'error');
    }

    // Check if should switch to signup
    const isSignUp = searchParams.get('isSignUp');
    if (isSignUp === 'true') {
      setIsLogin(false);
    }
  }, [searchParams]);

  if (authLoading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary mx-auto mb-4"></div>
          <p>Loading...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-background to-secondary flex flex-col items-center justify-center p-4">
      {/* Container */}
      <div className="w-full max-w-md">
        {/* Logo/Branding */}
        <div className="text-center mb-8">
          <h2 className="text-3xl font-bold">ELEFIT</h2>
          <p className="text-muted-foreground mt-2">Your fitness journey starts here</p>
        </div>

        {/* Message from URL */}
        {message && (
          <div className="mb-6">
            {messageType === 'success' ? (
              <Alert className="border-green-200 bg-green-50">
                <CheckCircle2 className="h-4 w-4 text-green-600" />
                <AlertDescription className="text-green-800">{message}</AlertDescription>
              </Alert>
            ) : (
              <Alert variant="destructive">
                <AlertCircle className="h-4 w-4" />
                <AlertDescription>{message}</AlertDescription>
              </Alert>
            )}
          </div>
        )}

        {/* Auth Forms */}
        {isLogin ? (
          <Login onSwitchToSignup={() => setIsLogin(false)} />
        ) : (
          <Signup onSwitchToLogin={() => setIsLogin(true)} />
        )}

        {/* Footer */}
        <div className="mt-8 text-center text-xs text-muted-foreground space-y-1">
          <p>By signing in, you agree to our Terms of Service and Privacy Policy</p>
          <p>© 2026 ELEFIT. All rights reserved.</p>
        </div>
      </div>
    </div>
  );
}
