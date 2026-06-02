import { useState, useEffect } from 'react';
import { useNavigate, useLocation, useSearchParams } from 'react-router-dom';
import { useAuth } from '@/contexts/AuthContext';
import { FaEye, FaEyeSlash } from 'react-icons/fa';
import './AuthPage.css';

const AuthPageOriginal = () => {
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
  const [showPassword, setShowPassword] = useState(false);

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
      await signup(email, password, 'customer', firstName, lastName);

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
      setLoading(false);
    }
  };

  // Handle tab switch
  const handleTabSwitch = (isLoginTab: boolean) => {
    setIsLogin(isLoginTab);
    setError('');
    setSuccess('');
    setPassword('');
  };

  // Toggle password visibility
  const togglePasswordVisibility = () => {
    setShowPassword(!showPassword);
  };

  if (authLoading) {
    return (
      <div className="auth-page">
        <div className="auth-card">
          <div
            className="auth-form-section"
            style={{
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              minHeight: '400px',
            }}
          >
            <div style={{ textAlign: 'center' }}>
              <div style={{ fontSize: '24px', marginBottom: '16px' }}>Loading...</div>
            </div>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="auth-page">
      <div className="auth-card">
        {/* Left Side - Image */}
        <div className="auth-image-section">
          <div className="auth-image-container">
            <div className="auth-logo-overlay">
              <div style={{ fontSize: '32px', fontWeight: 'bold', color: 'white' }}>ELEFIT</div>
            </div>
          </div>
        </div>

        {/* Right Side - Form */}
        <div className="auth-form-section">
          <div className="auth-header">
            <h1>
              {isForgotPassword ? 'Reset Password' : isLogin ? 'Welcome Back!' : 'Create Account'}
            </h1>
            <p>
              {isForgotPassword
                ? 'Enter your email to reset your password'
                : isLogin
                  ? 'Sign in to access your account'
                  : 'Join our community of nutrition experts'}
            </p>
          </div>

          {isLogin && !isForgotPassword && (
            <div className="password-tips">
              <h3>Password Tips:</h3>
              <p>
                If you have a Shopify account, use your Shopify password. If you created an account
                directly here, use your account password.
              </p>
            </div>
          )}

          {/* Error Messages */}
          {error && (
            <div className="auth-error">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                width="16"
                height="16"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                strokeWidth="2"
              >
                <circle cx="12" cy="12" r="10"></circle>
                <line x1="12" y1="8" x2="12" y2="12"></line>
                <line x1="12" y1="16" x2="12.01" y2="16"></line>
              </svg>
              {error}
            </div>
          )}

          {success && (
            <div className="auth-success">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                width="16"
                height="16"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                strokeWidth="2"
              >
                <path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"></path>
                <polyline points="22 4 12 14.01 9 11.01"></polyline>
              </svg>
              {success}
            </div>
          )}

          {searchParams.get('tokenVerified') === 'true' && (
            <div className="auth-success">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                width="16"
                height="16"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                strokeWidth="2"
              >
                <path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"></path>
                <polyline points="22 4 12 14.01 9 11.01"></polyline>
              </svg>
              Your account has been verified! Please sign in to continue.
            </div>
          )}

          <form onSubmit={handleSubmit} className="auth-form">
            {!isLogin && !isForgotPassword && (
              <>
                <div className="form-group">
                  <label htmlFor="firstName">
                    First Name <span className="required-star">*</span>
                  </label>
                  <input
                    type="text"
                    id="firstName"
                    value={firstName}
                    onChange={e => setFirstName(e.target.value)}
                    placeholder="Enter your first name"
                    required
                    disabled={loading}
                  />
                </div>
                <div className="form-group">
                  <label htmlFor="lastName">
                    Last Name <span className="required-star">*</span>
                  </label>
                  <input
                    type="text"
                    id="lastName"
                    value={lastName}
                    onChange={e => setLastName(e.target.value)}
                    placeholder="Enter your last name"
                    required
                    disabled={loading}
                  />
                </div>
              </>
            )}

            <div className="form-group">
              <label htmlFor="email">
                Email Address {!isLogin && <span className="required-star">*</span>}
              </label>
              <input
                type="email"
                id="email"
                value={email}
                onChange={e => setEmail(e.target.value)}
                placeholder="Enter your email"
                required
                disabled={loading}
              />
            </div>

            {!isForgotPassword && (
              <div className="form-group">
                <label htmlFor="password">
                  Password {!isLogin && <span className="required-star">*</span>}
                </label>
                <div className="password-input-container">
                  <input
                    type={showPassword ? 'text' : 'password'}
                    id="password"
                    value={password}
                    onChange={e => setPassword(e.target.value)}
                    placeholder={isLogin ? 'Enter your password' : 'Create a password'}
                    required
                    disabled={loading}
                  />
                  <button
                    type="button"
                    className="password-toggle-btn"
                    onClick={togglePasswordVisibility}
                    aria-label={showPassword ? 'Hide password' : 'Show password'}
                  >
                    {showPassword ? <FaEyeSlash /> : <FaEye />}
                  </button>
                </div>
              </div>
            )}

            {isLogin && !isForgotPassword && (
              <div className="forgot-password">
                <button
                  type="button"
                  className="forgot-link"
                  onClick={() => {
                    setIsForgotPassword(true);
                    setError('');
                    setSuccess('');
                  }}
                  disabled={loading}
                >
                  Forgot password?
                </button>
              </div>
            )}

            <button type="submit" className="auth-button" disabled={loading}>
              {loading
                ? isForgotPassword
                  ? 'Resetting...'
                  : isLogin
                    ? 'Authenticating...'
                    : 'Processing...'
                : isForgotPassword
                  ? 'Reset Password'
                  : isLogin
                    ? 'Sign In'
                    : 'Create Account'}
            </button>

            {isLogin && !isForgotPassword && (
              <div className="signup-link">
                Don't have an Account?{' '}
                <button
                  type="button"
                  className="signup-button"
                  onClick={() => handleTabSwitch(false)}
                  disabled={loading}
                >
                  Sign up
                </button>
              </div>
            )}

            {!isLogin && !isForgotPassword && (
              <div className="signup-link">
                Already have an account?{' '}
                <button
                  type="button"
                  className="signup-button"
                  onClick={() => handleTabSwitch(true)}
                  disabled={loading}
                >
                  Sign in
                </button>
              </div>
            )}

            {isForgotPassword && (
              <>
                <div className="auth-divider">
                  <span>OR</span>
                </div>
                <button
                  type="button"
                  className="auth-button secondary"
                  onClick={() => {
                    setIsForgotPassword(false);
                    setError('');
                    setSuccess('');
                  }}
                  disabled={loading}
                >
                  Back to Sign In
                </button>
              </>
            )}
          </form>
        </div>
      </div>
    </div>
  );
};

export default AuthPageOriginal;
