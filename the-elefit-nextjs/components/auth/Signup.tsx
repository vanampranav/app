"use client";

import { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { useAuth } from '@/contexts/AuthContext';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Card } from '@/components/ui/card';
import { Alert, AlertDescription } from '@/components/ui/alert';
import { Eye, EyeOff, AlertCircle, CheckCircle2, ArrowLeft } from 'lucide-react';
import OTPVerification from './OTPVerification';
import { generateOTP, saveSignupOTP } from '@/shared/firebase';
import { sendSignupOTP } from '@/shared/emailService';

interface SignupProps {
    onSwitchToLogin?: () => void;
}

export default function Signup({ onSwitchToLogin }: SignupProps) {
    const router = useRouter();
    const { user, signup, error: authError, refreshProfile } = useAuth();

    // Form state
    const [firstName, setFirstName] = useState('');
    const [lastName, setLastName] = useState('');
    const [email, setEmail] = useState('');
    const [password, setPassword] = useState('');
    const [confirmPassword, setConfirmPassword] = useState('');
    const [showPassword, setShowPassword] = useState(false);
    const [showConfirmPassword, setShowConfirmPassword] = useState(false);
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState('');
    const [success, setSuccess] = useState('');
    const [signupStep, setSignupStep] = useState<'form' | 'otp'>('form');

    // Sync step with auth state and handle redirects
    useEffect(() => {
        if (user && !user.otpVerified && !user.emailVerified) {
            setSignupStep('otp');
        } else if (!user) {
            setSignupStep('form');
        }
    }, [user]);

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

    // Check password strength
    const checkPasswordStrength = (value: string) => {
        return {
            hasMinLength: value.length >= 8,
            hasUpperCase: /[A-Z]/.test(value),
            hasLowerCase: /[a-z]/.test(value),
            hasNumber: /[0-9]/.test(value),
            hasSpecialChar: /[!@#$%^&*(),.?":{}|<>]/.test(value),
        };
    };

    const passwordStrength = checkPasswordStrength(password);
    const strengthScore = Object.values(passwordStrength).filter(Boolean).length;

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        setError('');
        setSuccess('');

        // Validation
        if (!firstName.trim()) {
            setError('Please enter your first name');
            return;
        }

        if (!lastName.trim()) {
            setError('Please enter your last name');
            return;
        }

        if (!isValidEmail(email)) {
            setError('Please enter a valid email address');
            return;
        }

        if (!password || password.length < 8) {
            setError('Password must be at least 8 characters long');
            return;
        }

        if (password !== confirmPassword) {
            setError('Passwords do not match');
            return;
        }

        if (strengthScore < 3) {
            setError('Password is not strong enough. Use uppercase, lowercase, numbers, and special characters');
            return;
        }

        setLoading(true);

        try {
            // Fixed signature to match AuthContext
            const user = await signup(email, password, 'customer', firstName, lastName);

            if (user) {
                // 1. Generate OTP
                const code = generateOTP();

                // 2. Save OTP to Firestore
                await saveSignupOTP(user.uid, email, code);

                // 3. Send OTP via EmailJS
                await sendSignupOTP(email, code);

                setSignupStep('otp');
                setSuccess('Verification code sent to your email!');
            }
        } catch (err: any) {
            const code = err.code || '';
            const message = err.message || '';

            // Handle specific Firebase errors
            if (code === 'auth/email-already-in-use') {
                setError('An account with this email already exists. Please sign in instead.');
            } else if (code === 'auth/weak-password') {
                setError('Password is too weak. Please use a stronger password.');
            } else if (code === 'auth/invalid-email') {
                setError('Please enter a valid email address.');
            } else if (message.includes('network') || message.includes('Network')) {
                setError('Network error. Please check your internet connection and try again.');
            } else {
                setError(message || 'Account creation failed. Please try again.');
            }
        } finally {
            setLoading(false);
        }
    };

    const signupForm = (
        <div className="w-full">
            <form onSubmit={handleSubmit} className="space-y-5">
                {/* Header */}
                <div className="space-y-2">
                    <h1 className="text-3xl font-bold text-white tracking-tight">Create Account</h1>
                    <p className="text-sm text-[#AFAFAF]">Join our community of fitness enthusiasts</p>
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

                <div className="grid grid-cols-2 gap-4">
                    {/* First Name */}
                    <div className="space-y-1.5">
                        <label htmlFor="firstName" className="block text-xs font-medium text-white">
                            First Name <span className="text-red-500">*</span>
                        </label>
                        <Input
                            id="firstName"
                            placeholder="Enter your first name"
                            value={firstName}
                            onChange={(e) => setFirstName(e.target.value)}
                            disabled={loading}
                            required
                            className="bg-[#0D0D0D] border-[#212121] text-white h-10 focus:ring-primary focus:border-primary transition-all text-sm"
                        />
                    </div>

                    {/* Last Name */}
                    <div className="space-y-1.5">
                        <label htmlFor="lastName" className="block text-xs font-medium text-white">
                            Last Name <span className="text-red-500">*</span>
                        </label>
                        <Input
                            id="lastName"
                            placeholder="Enter your last name"
                            value={lastName}
                            onChange={(e) => setLastName(e.target.value)}
                            disabled={loading}
                            required
                            className="bg-[#0D0D0D] border-[#212121] text-white h-10 focus:ring-primary focus:border-primary transition-all text-sm"
                        />
                    </div>
                </div>

                {/* Email */}
                <div className="space-y-1.5">
                    <label htmlFor="email" className="block text-xs font-medium text-white">
                        Email Address <span className="text-red-500">*</span>
                    </label>
                    <Input
                        id="email"
                        type="email"
                        placeholder="Enter your email"
                        value={email}
                        onChange={(e) => setEmail(e.target.value)}
                        disabled={loading}
                        required
                        className="bg-[#0D0D0D] border-[#212121] text-white h-10 focus:ring-primary focus:border-primary transition-all text-sm"
                    />
                </div>

                {/* Password */}
                <div className="space-y-1.5">
                    <label htmlFor="password" className="block text-xs font-medium text-white">
                        Password <span className="text-red-500">*</span>
                    </label>
                    <div className="relative">
                        <Input
                            id="password"
                            type={showPassword ? 'text' : 'password'}
                            placeholder="Create a password"
                            value={password}
                            onChange={(e) => setPassword(e.target.value)}
                            disabled={loading}
                            required
                            className="bg-[#0D0D0D] border-[#212121] text-white h-10 pr-10 focus:ring-primary focus:border-primary transition-all text-sm"
                        />
                        <button
                            type="button"
                            onClick={() => setShowPassword(!showPassword)}
                            className="absolute right-3 top-1/2 -translate-y-1/2 text-[#454545] hover:text-white transition-colors"
                        >
                            {showPassword ? <EyeOff className="h-3.5 w-3.5" /> : <Eye className="h-3.5 w-3.5" />}
                        </button>
                    </div>
                </div>

                {/* Confirm Password */}
                <div className="space-y-1.5">
                    <label htmlFor="confirmPassword" className="block text-xs font-medium text-white">
                        Confirm Password <span className="text-red-500">*</span>
                    </label>
                    <div className="relative">
                        <Input
                            id="confirmPassword"
                            type={showConfirmPassword ? 'text' : 'password'}
                            placeholder="Confirm your password"
                            value={confirmPassword}
                            onChange={(e) => setConfirmPassword(e.target.value)}
                            disabled={loading}
                            required
                            className="bg-[#0D0D0D] border-[#212121] text-white h-10 pr-10 focus:ring-primary focus:border-primary transition-all text-sm"
                        />
                        <button
                            type="button"
                            onClick={() => setShowConfirmPassword(!showConfirmPassword)}
                            className="absolute right-3 top-1/2 -translate-y-1/2 text-[#454545] hover:text-white transition-colors"
                        >
                            {showConfirmPassword ? <EyeOff className="h-3.5 w-3.5" /> : <Eye className="h-3.5 w-3.5" />}
                        </button>
                    </div>
                </div>

                {/* Submit Button */}
                <Button
                    type="submit"
                    className="w-full bg-primary text-black font-bold h-12 rounded-xl hover:bg-primary/90 transition-all active:scale-[0.98] mt-2"
                    disabled={loading}
                >
                    {loading ? 'Creating account...' : 'Create Account'}
                </Button>

                {/* Switch to Login */}
                <div className="text-center text-xs pt-2">
                    <span className="text-[#666]">Already have an account? </span>
                    <button
                        type="button"
                        className="font-semibold text-primary hover:underline transition-all"
                        onClick={onSwitchToLogin}
                        disabled={loading}
                    >
                        Sign in
                    </button>
                </div>
            </form>
        </div>
    );

    if (signupStep === 'otp') {
        // Use either newUserInfo or the authenticated user from context
        const displayEmail = user?.email || email;
        const displayUid = user?.uid;

        if (!displayUid || !displayEmail) {
            return signupForm; // Fallback if we somehow lost user info
        }

        return (
            <div className="w-full">
                <button
                    onClick={() => setSignupStep('form')}
                    className="flex items-center gap-2 text-xs text-[#666] hover:text-white mb-8 transition-colors"
                >
                    <ArrowLeft className="w-3 h-3" /> Back to Signup
                </button>
                <OTPVerification
                    email={displayEmail}
                    uid={displayUid}
                    onVerified={async () => {
                        await refreshProfile();
                        setSuccess('Email verified! Welcome to EleFit.');
                        setTimeout(() => router.push('/ai-coach/welcome'), 1500);
                    }}
                />
            </div>
        );
    }

    return signupForm;
}
