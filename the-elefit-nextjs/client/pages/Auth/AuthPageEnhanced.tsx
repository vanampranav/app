import { useState, useEffect } from 'react';
import { useNavigate, useLocation, useSearchParams } from 'react-router-dom';
import { useAuth } from '@/contexts/AuthContext';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Card } from '@/components/ui/card';
import { Alert, AlertDescription } from '@/components/ui/alert';
import { Eye, EyeOff, AlertCircle, CheckCircle2, Loader } from 'lucide-react';
import { cn } from '@/lib/utils';

const AuthPageEnhanced = () => {
  const navigate = useNavigate();
  const location = useLocation();
  const [searchParams] = useSearchParams();
  const { isAuthenticated, loading: authLoading, userType, login, signup } = useAuth();

  // Get redirect path from URL params or state
  const redirectPath = searchParams.get('redirect') || location.state?.returnPath || null;

  // Manual authentication state
  const [isLogin, setIsLogin] = useState(true);
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [firstName, setFirstName] = useState('');
  const [lastName, setLastName] = useState('');
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');
  const [loading, setLoading] = useState(false);
  const [isForgotPassword, setIsForgotPassword] = useState(false);
  const [retryData, setRetryData] = useState<any>(null);
  const [showLoginHint, setShowLoginHint] = useState(false);
  const [showPassword, setShowPassword] = useState(false);

  // Session token authentication state
  const [sessionTokenLoading, setSessionTokenLoading] = useState(false);
  const [sessionTokenError, setSessionTokenError] = useState('');
  const [sessionTokenSuccess, setSessionTokenSuccess] = useState('');

  // Enhanced email validator
  const isValidEmail = (value: string): boolean => {
    const emailPattern =
      /^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$/;
    const trimmedEmail = value.trim();

    if (!emailPattern.test(trimmedEmail)) return false;
    if (trimmedEmail.length > 254) return false;
    if (trimmedEmail.startsWith('.') || trimmedEmail.endsWith('.')) return false;
    if (trimmedEmail.includes('..')) return false;

    return true;
  };

  // Handle manual sign-in
  const handleManualSignIn = async (email: string, password: string) => {
    try {
      await login(email, password);
      checkUserTypeAndNavigate();
    } catch (loginError: any) {
      console.error('Login error:', loginError);

      const code = loginError?.code || '';
      const msg = loginError?.message || '';

      // Handle specific Firebase auth error codes
      if (code === 'auth/user-not-found') {
        setError(
          'No account found with this email address. Please check your email or sign up for a new account.'
        );
      } else if (code === 'auth/wrong-password') {
        setError('Incorrect password. Please try again or reset your password.');
      } else if (code === 'auth/invalid-email') {
        setError('Please enter a valid email address.');
      } else if (code === 'auth/user-disabled') {
        setError('This account has been disabled. Please contact support.');
      } else if (code === 'auth/too-many-requests') {
        setError('Too many failed login attempts. Please try again later or reset your password.');
      } else if (code === 'auth/invalid-credential' || code === 'auth/invalid-login-credentials') {
        if (msg.includes('Email or password is incorrect')) {
          setError(
            'Invalid email or password. If you have a Shopify account, please use your Shopify password, or reset your password using the "Forgot password?" link below.'
          );
        } else {
          setError('Invalid email or password. Please check your credentials and try again.');
        }
      } else if (msg.includes('The email address is not valid')) {
        setError('Please enter a valid email address.');
      } else if (msg.includes('Password should be at least 6 characters')) {
        setError('Password must be at least 6 characters long.');
      } else if (
        msg.includes('Email or password is incorrect') ||
        msg.includes('INVALID_LOGIN_CREDENTIALS')
      ) {
        setError(
          'Invalid email or password. If you have a Shopify account, please use your Shopify password, or reset your password using the "Forgot password?" link below.'
        );
      } else if (msg.includes('network') || msg.includes('Network')) {
        setError('Network error. Please check your internet connection and try again.');
      } else {
        setError('Login failed. Please check your email and password and try again.');
      }
    }
  };

  // Handle manual sign-up
  const handleManualSignUp = async (
    email: string,
    password: string,
    firstName: string,
    lastName: string
  ) => {
    try {
      await signup(email, password, 'user', firstName, lastName);

      // Clear form and switch to login
      setPassword('');
      setFirstName('');
      setLastName('');
      setIsLogin(true);

      // Set success message
      setSuccess('Account created successfully! Please sign in with your credentials.');
      setEmail(email);
    } catch (signupError: any) {
      const code = signupError?.code || '';
      const msg = signupError?.message || '';

      if (code === 'auth/email-already-in-use') {
        setError('An account with this email already exists. Please sign in instead.');
      } else if (code === 'auth/weak-password') {
        setError('Password is too weak. Please use a stronger password.');
      } else if (code === 'auth/invalid-email') {
        setError('Please enter a valid email address.');
      } else if (msg.includes('network') || msg.includes('Network')) {
        setError('Network error. Please check your internet connection and try again.');
      } else {
        setError('Account creation failed. Please try again.');
      }
    }
  };

  // Function to check user type and navigate appropriately
  const checkUserTypeAndNavigate = async () => {
    try {
      // Determine redirect path
      let finalRedirectPath = redirectPath || '/';

      if (redirectPath && redirectPath !== '/') {
        console.log('🔍 AuthPage: Using redirect path from URL:', redirectPath);
        finalRedirectPath = redirectPath;
      } else {
        // Otherwise, redirect based on user type
        if (userType === 'expert') {
          finalRedirectPath = '/expert-dashboard';
        } else {
          finalRedirectPath = '/user-dashboard';
        }
        console.log('🔍 AuthPage: Using default redirect based on user type:', finalRedirectPath);
      }

      console.log('🚀 AuthPage: Redirecting to:', finalRedirectPath);
      navigate(finalRedirectPath, { replace: true });
    } catch (error) {
      console.error('❌ AuthPage: Error checking user type:', error);
      setError('Error verifying user account. Please try again.');
      setLoading(false);
    }
  };

  // Check if user is already logged in
  useEffect(() => {
    if (!authLoading && isAuthenticated && userType) {
      setLoading(false);
    } else if (!authLoading && !isAuthenticated) {
      setLoading(false);
    }
  }, [authLoading, isAuthenticated, userType]);

  // Handle URL parameters for pre-filling email and messages
  useEffect(() => {
    const emailParam = searchParams.get('email');
    const messageParam = searchParams.get('message');
    const customerIdParam = searchParams.get('customerId');
    const tokenVerified = searchParams.get('tokenVerified');
    const isSignUpParam = searchParams.get('isSignUp');

    if (emailParam) {
      setEmail(decodeURIComponent(emailParam));
      console.log('📧 AuthPage: Prefilled email from URL:', emailParam);
    }

    if (customerIdParam) {
      console.log('🛍️ AuthPage: Shopify Customer ID from URL:', customerIdParam);
      localStorage.setItem('shopifyCustomerId', customerIdParam);
    }

    if (messageParam) {
      setSuccess(decodeURIComponent(messageParam));
      console.log('💬 AuthPage: Welcome message from URL:', messageParam);
    }

    if (tokenVerified === 'true') {
      console.log('✅ AuthPage: Token verified, user should be able to login easily');
    }

    if (isSignUpParam === 'true') {
      console.log('📝 AuthPage: Switching to sign-up mode for new user');
      setIsLogin(false);
    }
  }, [searchParams]);

  // Handle form submission
  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    setSuccess('');
    setLoading(true);
    setShowLoginHint(false);

    try {
      if (!isLogin) {
        // Registration
        if (!firstName.trim()) {
          setError('Please enter your first name');
          setLoading(false);
          return;
        }
        if (!lastName.trim()) {
          setError('Please enter your last name');
          setLoading(false);
          return;
        }
        if (!isValidEmail(email)) {
          setError('Please enter a valid email address');
          setLoading(false);
          return;
        }
        if (!password || password.length < 6) {
          setError('Password must be at least 6 characters long');
          setLoading(false);
          return;
        }

        await handleManualSignUp(email, password, firstName, lastName);
      } else if (isForgotPassword) {
        // TODO: Implement password reset
        setSuccess('Password reset functionality coming soon.');
        setIsForgotPassword(false);
      } else {
        // Login
        const emailValid = isValidEmail(email);
        const passwordValid = typeof password === 'string' && password.length >= 6;

        if (!emailValid && !passwordValid) {
          setError('Please enter a valid email address and password');
          setLoading(false);
          return;
        }
        if (!emailValid) {
          setError('Please enter a valid email address');
          setLoading(false);
          return;
        }
        if (!passwordValid) {
          setError('Password must be at least 6 characters long');
          setLoading(false);
          return;
        }

        await handleManualSignIn(email, password);
      }
    } catch (error: any) {
      setError(error.message);
    } finally {
      if (!retryData) {
        setLoading(false);
      }
    }
  };

  // Handle tab switch
  const handleTabSwitch = (isLoginTab: boolean) => {
    setIsLogin(isLoginTab);
    setError('');
    setSuccess('');
    setRetryData(null);
    setShowLoginHint(false);
    setPassword('');
  };

  // Toggle password visibility
  const togglePasswordVisibility = () => {
    setShowPassword(!showPassword);
  };

  if (authLoading) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-background">
        <div className="text-center">
          <Loader className="h-12 w-12 animate-spin text-primary mx-auto mb-4" />
          <p>Loading authentication...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-background to-secondary flex items-center justify-center p-4">
      <div className="w-full max-w-2xl">
        {/* Header */}
        <div className="text-center mb-8">
          <h1 className="text-4xl font-bold text-foreground">ELEFIT</h1>
          <p className="text-muted-foreground mt-2">Your fitness journey starts here</p>
        </div>

        <Card className="p-8">
          {/* Header */}
          <div className="text-center mb-6">
            <h2 className="text-2xl font-bold">
              {isForgotPassword ? 'Reset Password' : isLogin ? 'Welcome Back!' : 'Create Account'}
            </h2>
            <p className="text-muted-foreground mt-1">
              {isForgotPassword
                ? 'Enter your email to reset your password'
                : isLogin
                  ? 'Sign in to access your account'
                  : 'Join our community of nutrition experts'}
            </p>
          </div>

          {isLogin && !isForgotPassword && (
            <div className="bg-blue-50 border border-blue-200 rounded-lg p-4 mb-6">
              <h3 className="font-semibold text-blue-800 mb-2">Password Tips:</h3>
              <p className="text-blue-700 text-sm">
                If you have a Shopify account, use your Shopify password. If you created an account
                directly here, use your account password.
              </p>
            </div>
          )}

          {/* Session Token Messages */}
          {sessionTokenError && (
            <Alert variant="destructive" className="mb-4">
              <AlertCircle className="h-4 w-4" />
              <AlertDescription>{sessionTokenError}</AlertDescription>
            </Alert>
          )}

          {sessionTokenSuccess && (
            <Alert className="mb-4 border-green-200 bg-green-50">
              <CheckCircle2 className="h-4 w-4 text-green-600" />
              <AlertDescription className="text-green-800">{sessionTokenSuccess}</AlertDescription>
            </Alert>
          )}

          {/* Manual Authentication Messages */}
          {error && (
            <Alert variant="destructive" className="mb-4">
              <AlertCircle className="h-4 w-4" />
              <AlertDescription>{error}</AlertDescription>
            </Alert>
          )}

          {success && (
            <Alert className="mb-4 border-green-200 bg-green-50">
              <CheckCircle2 className="h-4 w-4 text-green-600" />
              <AlertDescription className="text-green-800">{success}</AlertDescription>
            </Alert>
          )}

          {showLoginHint && (
            <Alert className="mb-4">
              <AlertCircle className="h-4 w-4" />
              <AlertDescription>Setting up your account, please wait...</AlertDescription>
            </Alert>
          )}

          {searchParams.get('tokenVerified') === 'true' && (
            <Alert className="mb-4 border-green-200 bg-green-50">
              <CheckCircle2 className="h-4 w-4 text-green-600" />
              <AlertDescription className="text-green-800">
                Your account has been verified! Please sign in to continue.
              </AlertDescription>
            </Alert>
          )}

          {sessionTokenLoading && (
            <Alert className="mb-4">
              <AlertCircle className="h-4 w-4" />
              <AlertDescription>
                {searchParams.get('token')
                  ? 'Authenticating with token, please wait...'
                  : 'Processing authentication, please wait...'}
              </AlertDescription>
            </Alert>
          )}

          <form onSubmit={handleSubmit} className="space-y-4">
            {!isLogin && !isForgotPassword && (
              <>
                <div className="grid grid-cols-2 gap-4">
                  <div className="space-y-2">
                    <label htmlFor="firstName" className="block text-sm font-medium">
                      First Name <span className="text-destructive">*</span>
                    </label>
                    <Input
                      id="firstName"
                      value={firstName}
                      onChange={e => setFirstName(e.target.value)}
                      placeholder="Enter your first name"
                      required
                      disabled={loading || sessionTokenLoading}
                    />
                  </div>
                  <div className="space-y-2">
                    <label htmlFor="lastName" className="block text-sm font-medium">
                      Last Name <span className="text-destructive">*</span>
                    </label>
                    <Input
                      id="lastName"
                      value={lastName}
                      onChange={e => setLastName(e.target.value)}
                      placeholder="Enter your last name"
                      required
                      disabled={loading || sessionTokenLoading}
                    />
                  </div>
                </div>
              </>
            )}

            <div className="space-y-2">
              <label htmlFor="email" className="block text-sm font-medium">
                Email Address {!isLogin && <span className="text-destructive">*</span>}
              </label>
              <Input
                id="email"
                type="email"
                value={email}
                onChange={e => setEmail(e.target.value)}
                placeholder="Enter your email"
                required
                disabled={loading || sessionTokenLoading}
              />
            </div>

            {!isForgotPassword && (
              <div className="space-y-2">
                <label htmlFor="password" className="block text-sm font-medium">
                  Password {!isLogin && <span className="text-destructive">*</span>}
                </label>
                <div className="relative">
                  <Input
                    id="password"
                    type={showPassword ? 'text' : 'password'}
                    value={password}
                    onChange={e => setPassword(e.target.value)}
                    placeholder={isLogin ? 'Enter your password' : 'Create a password'}
                    required
                    disabled={loading || sessionTokenLoading}
                  />
                  <button
                    type="button"
                    className="absolute right-3 top-1/2 -translate-y-1/2 text-muted-foreground hover:text-foreground"
                    onClick={togglePasswordVisibility}
                    aria-label={showPassword ? 'Hide password' : 'Show password'}
                  >
                    {showPassword ? <EyeOff className="h-4 w-4" /> : <Eye className="h-4 w-4" />}
                  </button>
                </div>
              </div>
            )}

            {isLogin && !isForgotPassword && (
              <div className="text-right">
                <Button
                  type="button"
                  variant="link"
                  className="h-auto p-0 text-sm"
                  onClick={() => {
                    setIsForgotPassword(true);
                    setError('');
                    setSuccess('');
                  }}
                  disabled={loading || sessionTokenLoading}
                >
                  Forgot password?
                </Button>
              </div>
            )}

            <Button
              type="submit"
              className="w-full"
              disabled={loading || sessionTokenLoading}
              size="lg"
            >
              {loading
                ? isForgotPassword
                  ? 'Resetting...'
                  : isLogin && retryData
                    ? 'Connecting account...'
                    : isLogin
                      ? 'Authenticating...'
                      : 'Processing...'
                : sessionTokenLoading
                  ? 'Processing authentication...'
                  : isForgotPassword
                    ? 'Reset Password'
                    : isLogin
                      ? 'Sign In'
                      : 'Create Account'}
            </Button>

            {isLogin && !isForgotPassword && (
              <div className="text-center text-sm">
                <span className="text-muted-foreground">Don't have an Account? </span>
                <Button
                  type="button"
                  variant="link"
                  className="h-auto p-0"
                  onClick={() => handleTabSwitch(false)}
                  disabled={loading || sessionTokenLoading}
                >
                  Sign up
                </Button>
              </div>
            )}

            {!isLogin && !isForgotPassword && (
              <div className="text-center text-sm">
                <span className="text-muted-foreground">Already have an account? </span>
                <Button
                  type="button"
                  variant="link"
                  className="h-auto p-0"
                  onClick={() => handleTabSwitch(true)}
                  disabled={loading || sessionTokenLoading}
                >
                  Sign in
                </Button>
              </div>
            )}

            {isForgotPassword && (
              <>
                <div className="relative">
                  <div className="absolute inset-0 flex items-center">
                    <div className="w-full border-t border-border" />
                  </div>
                  <div className="relative flex justify-center text-xs uppercase">
                    <span className="bg-background px-2 text-muted-foreground">OR</span>
                  </div>
                </div>
                <Button
                  type="button"
                  variant="outline"
                  className="w-full"
                  onClick={() => {
                    setIsForgotPassword(false);
                    setError('');
                    setSuccess('');
                  }}
                  disabled={loading || sessionTokenLoading}
                >
                  Back to Sign In
                </Button>
              </>
            )}
          </form>
        </Card>
      </div>
    </div>
  );
};

export default AuthPageEnhanced;
