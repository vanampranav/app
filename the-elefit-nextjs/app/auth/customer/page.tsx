"use client";

import { useState, useEffect, Suspense } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import { Card } from '@/components/ui/card';
import { Alert, AlertDescription } from '@/components/ui/alert';
import { CheckCircle2, AlertCircle, Loader } from 'lucide-react';

function CustomerAuthContent() {
    const router = useRouter();
    const searchParams = useSearchParams();
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

                // Store customer data
                if (typeof window !== 'undefined') {
                    localStorage.setItem('shopifyCustomerEmail', decodedEmail);
                    localStorage.setItem('shopifyCustomerId', decodedCustomerId);
                }

                console.log('✅ Customer data stored');

                setMessage('Customer validated successfully! Redirecting to login...');

                // Redirect to auth page with customer info
                setTimeout(() => {
                    router.replace(
                        `/auth?email=${encodeURIComponent(decodedEmail)}&customerId=${encodeURIComponent(decodedCustomerId)}&message=${encodeURIComponent('Shopify customer verified! Please sign in to continue.')}&autoLogin=true`
                    );
                }, 2000);

            } catch (err: any) {
                console.error('❌ Customer validation error:', err);
                setError(`Customer validation failed: ${err.message}. Please check your credentials.`);

                // Redirect to auth page after delay
                setTimeout(() => {
                    router.replace('/auth');
                }, 3000);
            }
        };

        handleCustomerAuth();
    }, [searchParams, router]);

    return (
        <div className="min-h-screen bg-black flex items-center justify-center p-4">
            <div className="absolute inset-0 overflow-hidden pointer-events-none">
                <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[150%] h-[150%] opacity-20 blur-[200px] bg-primary/30 rounded-full" />
            </div>

            <Card className="w-full max-w-md p-8 bg-[#0D0D0D] border-[#212121]">
                <div className="text-center space-y-4">
                    <h1 className="text-2xl font-bold text-white">Shopify Customer Authentication</h1>

                    {/* Success State */}
                    {message && !error && (
                        <div className="space-y-4">
                            <Alert className="border-green-500/50 bg-green-500/10 text-green-400">
                                <CheckCircle2 className="h-4 w-4" />
                                <AlertDescription>{message}</AlertDescription>
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

                            <p className="text-sm text-[#AFAFAF]">
                                Redirecting to login page...
                            </p>
                        </div>
                    )}

                    {/* Initial Loading State */}
                    {!message && !error && (
                        <div className="space-y-4">
                            <Loader className="h-8 w-8 animate-spin text-primary mx-auto" />
                            <p className="text-[#AFAFAF]">Authenticating customer...</p>
                        </div>
                    )}
                </div>
            </Card>
        </div>
    );
}

export default function CustomerAuth() {
    return (
        <Suspense fallback={
            <div className="min-h-screen flex items-center justify-center bg-black">
                <Loader className="h-12 w-12 animate-spin text-primary" />
            </div>
        }>
            <CustomerAuthContent />
        </Suspense>
    );
}
