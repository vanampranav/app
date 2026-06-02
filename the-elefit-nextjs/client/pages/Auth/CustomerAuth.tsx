import { useState, useEffect } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { Card } from '@/components/ui/card';
import { Alert, AlertDescription } from '@/components/ui/alert';
import { CheckCircle2, AlertCircle, Loader } from 'lucide-react';
import { loginUser } from '@shared/firebase';

export default function CustomerAuth() {
  const navigate = useNavigate();
  const [searchParams] = useSearchParams();
  const [isLoading, setIsLoading] = useState(true);
  const [message, setMessage] = useState('');
  const [error, setError] = useState('');

  useEffect(() => {
    const handleCustomerAuth = async () => {
      try {
        // Get customer data from URL parameters
        const email = searchParams.get('email');
        const customerId = searchParams.get('customerId');
        
        if (!email || !customerId) {
          setError('Missing customer information. Please try again.');
          setIsLoading(false);
          return;
        }

        const decodedEmail = decodeURIComponent(email);
        const decodedCustomerId = decodeURIComponent(customerId);

        console.log('🛍️ Validating customer with Shopify:', {
          email: decodedEmail,
          customerId: decodedCustomerId
        });

        setMessage('Validating customer with Shopify...');

        // Validate customer with Shopify
        // This would call your shopifyService to validate the customer
        // For now, we'll just store the customer data and redirect to login
        
        localStorage.setItem('shopifyCustomerEmail', decodedEmail);
        localStorage.setItem('shopifyCustomerId', decodedCustomerId);

        console.log('✅ Customer data stored');

        setMessage('Customer validated successfully! Redirecting to login...');

        // Redirect to auth page with customer info
        setTimeout(() => {
          navigate(
            `/auth?email=${encodeURIComponent(decodedEmail)}&customerId=${encodeURIComponent(decodedCustomerId)}&message=${encodeURIComponent('Shopify customer verified! Please sign in to continue.')}&autoLogin=true`,
            { replace: true }
          );
        }, 2000);

      } catch (err: any) {
        console.error('❌ Customer validation error:', err);
        setError(`Customer validation failed: ${err.message}. Please check your credentials.`);
        
        // Redirect to auth page after delay
        setTimeout(() => {
          navigate('/auth', { replace: true });
        }, 3000);
      }
    };

    handleCustomerAuth();
  }, [searchParams, navigate]);

  return (
    <div className="min-h-screen bg-gradient-to-br from-background to-secondary flex items-center justify-center p-4">
      <Card className="w-full max-w-md p-8">
        <div className="text-center space-y-4">
          <h1 className="text-2xl font-bold">Shopify Customer Authentication</h1>

          {/* Success State */}
          {message && !error && (
            <div className="space-y-4">
              <Alert className="border-green-200 bg-green-50">
                <CheckCircle2 className="h-4 w-4 text-green-600" />
                <AlertDescription className="text-green-800">{message}</AlertDescription>
              </Alert>

              {isLoading && (
                <div className="flex justify-center">
                  <Loader className="h-8 w-8 animate-spin text-primary" />
                </div>
              )}
            </div>
          )}

          {/* Error State */}
          {error && (
            <div className="space-y-4">
              <Alert variant="destructive">
                <AlertCircle className="h-4 w-4" />
                <AlertDescription>{error}</AlertDescription>
              </Alert>

              <p className="text-sm text-muted-foreground">
                Redirecting to login page...
              </p>
            </div>
          )}

          {/* Initial Loading State */}
          {!message && !error && (
            <div className="space-y-4">
              <Loader className="h-8 w-8 animate-spin text-primary mx-auto" />
              <p className="text-muted-foreground">Authenticating customer...</p>
            </div>
          )}
        </div>
      </Card>
    </div>
  );
}
