"use client";

import { useState, useEffect } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import { useAuth } from '@/contexts/AuthContext';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Card } from '@/components/ui/card';
import { Alert, AlertDescription } from '@/components/ui/alert';
import { Eye, EyeOff, AlertCircle, CheckCircle2 } from 'lucide-react';

interface LoginProps {
    onSwitchToSignup?: () => void;
    onUnverified?: (email: string, uid: string) => void;
}

export default function Login({ onSwitchToSignup, onUnverified }: LoginProps) {
    const router = useRouter();
    const searchParams = useSearchParams();
    const { user, login, error: authError } = useAuth();

    // Sync state if already logged in but not verified
    useEffect(() => {
        if (user && !user.otpVerified && !user.emailVerified && onUnverified) {
            onUnverified(user.email || '', user.uid);
        }
    }, [user, onUnverified]);

    // Form state
    const [email, setEmail] = useState(() => searchParams.get('email') || '');
    const [password, setPassword] = useState('');
    const [showPassword, setShowPassword] = useState(false);
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState('');
    const [success, setSuccess] = useState('');

    // Validate email format
    const isValidEmail = (value: string): boolean => {
        const emailPattern = /^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$/;
        const trimmedEmail = value.trim();

        if (!emailPattern.test(trimmedEmail)) return false;
        if (trimmedEmail.length > 254) return false;
        if (trimmedEmail.startsWith('.') || trimmedEmail.endsWith('.')) return false;
        if (trimmedEmail.includes('..')) return false;

        return true;
    };

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        setError('');
        setSuccess('');

        // Validation
        if (!isValidEmail(email)) {
            setError('Please enter a valid email address');
            return;
        }

        if (!password || password.length < 6) {
            setError('Password must be at least 6 characters long');
            return;
        }

        setLoading(true);

        try {
            const loggedInUser: any = await login(email, password);
            setSuccess('Login successful! Redirecting...');

            if (loggedInUser && !loggedInUser.otpVerified && !loggedInUser.emailVerified && onUnverified) {
                onUnverified(email, loggedInUser.uid);
                return;
            }

            // Redirect based on user type or search params
            const redirectPath = searchParams.get('redirect') || '/';
            router.push(redirectPath);
        } catch (err: any) {
            const code = err.code || '';
            const message = err.message || '';

            // Handle specific Firebase errors
            if (code === 'auth/user-not-found') {
                setError('No account found with this email address. Please check or create a new account.');
            } else if (code === 'auth/wrong-password' || code === 'auth/invalid-credential') {
                setError('Invalid email or password. Please check your credentials and try again.');
            } else if (code === 'auth/invalid-email') {
                setError('Please enter a valid email address.');
            } else if (code === 'auth/user-disabled') {
                setError('This account has been disabled. Please contact support.');
            } else if (code === 'auth/too-many-requests') {
                setError('Too many failed login attempts. Please try again later or reset your password.');
            } else if (message.includes('network') || message.includes('Network')) {
                setError('Network error. Please check your internet connection and try again.');
            } else {
                setError('Login failed. Please check your credentials and try again.');
            }
        } finally {
            setLoading(false);
        }
    };

    const handleForgotPassword = () => {
        router.push('/auth/forgot-password');
    };

    return (
        <div className="w-full">
            <form onSubmit={handleSubmit} className="space-y-6">
                {/* Header */}
                <div className="space-y-2">
                    <h1 className="text-3xl font-bold text-white tracking-tight">Welcome Back!</h1>
                    <p className="text-sm text-[#AFAFAF]">Sign in to access your account</p>
                </div>

                {/* Info Alert matching Design */}
                <div className="p-4 rounded-xl bg-[#213242]/40 border border-[#213242] text-[12px] leading-relaxed text-[#B0CCF0]">
                    <p className="font-bold text-white mb-1">Password Tips:</p>
                    <p>If you have a Shopify account, use your Shopify password. If you created an account directly here, use your account password.</p>
                </div>

                {/* Error Alert */}
                {(error || authError) && (
                    <Alert variant="destructive" className="bg-red-500/10 border-red-500/50">
                        <AlertCircle className="h-4 w-4" />
                        <AlertDescription>{error || authError}</AlertDescription>
                    </Alert>
                )}

                {/* Success Alert */}
                {success && (
                    <Alert className="border-green-500/50 bg-green-500/10 text-green-400">
                        <CheckCircle2 className="h-4 w-4" />
                        <AlertDescription>{success}</AlertDescription>
                    </Alert>
                )}

                {/* Email Input */}
                <div className="space-y-2">
                    <label htmlFor="email" className="block text-sm font-medium text-white">
                        Email Address
                    </label>
                    <Input
                        id="email"
                        type="email"
                        placeholder="Enter your email"
                        value={email}
                        onChange={(e) => setEmail(e.target.value)}
                        disabled={loading}
                        autoComplete="email"
                        required
                        className="bg-[#0D0D0D] border-[#212121] text-white h-11 focus:ring-primary focus:border-primary transition-all"
                    />
                </div>

                {/* Password Input */}
                <div className="space-y-2 relative">
                    <div className="flex items-center justify-between">
                        <label htmlFor="password" className="block text-sm font-medium text-white">
                            Password
                        </label>
                        <button
                            type="button"
                            onClick={handleForgotPassword}
                            className="text-xs text-primary hover:underline"
                            disabled={loading}
                        >
                            Forgot password?
                        </button>
                    </div>
                    <div className="relative">
                        <Input
                            id="password"
                            type={showPassword ? 'text' : 'password'}
                            placeholder="Enter your password"
                            value={password}
                            onChange={(e) => setPassword(e.target.value)}
                            disabled={loading}
                            autoComplete="current-password"
                            required
                            className="bg-[#0D0D0D] border-[#212121] text-white h-11 pr-10 focus:ring-primary focus:border-primary transition-all"
                        />
                        <button
                            type="button"
                            onClick={() => setShowPassword(!showPassword)}
                            className="absolute right-3 top-1/2 -translate-y-1/2 text-[#454545] hover:text-white transition-colors"
                            aria-label={showPassword ? 'Hide password' : 'Show password'}
                        >
                            {showPassword ? <EyeOff className="h-4 w-4" /> : <Eye className="h-4 w-4" />}
                        </button>
                    </div>
                </div>

                {/* Submit Button */}
                <Button
                    type="submit"
                    className="w-full bg-primary text-black font-bold h-12 rounded-xl hover:bg-primary/90 transition-all active:scale-[0.98]"
                    disabled={loading}
                >
                    {loading ? 'Signing in...' : 'Sign In'}
                </Button>

                {/* Switch to Signup */}
                <div className="text-center text-sm pt-2">
                    <span className="text-[#666]">Don't have an Account? </span>
                    <button
                        type="button"
                        className="font-semibold text-primary hover:underline transition-all"
                        onClick={onSwitchToSignup}
                        disabled={loading}
                    >
                        Sign up
                    </button>
                </div>
            </form>
        </div>
    );
}
