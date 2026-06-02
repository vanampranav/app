"use client";

import { useState, useEffect } from "react";
import {
  InputOTP,
  InputOTPGroup,
  InputOTPSlot,
} from "@/components/ui/input-otp";
import { Button } from "@/components/ui/button";
import { toast } from "sonner";
import { verifySignupOTP, saveSignupOTP, generateOTP } from "@/shared/firebase";
import { sendSignupOTP } from "@/shared/emailService";
import { Loader2, RefreshCw, Mail } from "lucide-react";

interface OTPVerificationProps {
  email: string;
  uid: string;
  onVerified: () => void;
}

export default function OTPVerification({
  email,
  uid,
  onVerified,
}: OTPVerificationProps) {
  const [otp, setOtp] = useState("");
  const [isVerifying, setIsVerifying] = useState(false);
  const [isResending, setIsResending] = useState(false);
  const [timer, setTimer] = useState(60);

  useEffect(() => {
    let interval: NodeJS.Timeout;
    if (timer > 0) {
      interval = setInterval(() => {
        setTimer((prev) => prev - 1);
      }, 1000);
    }
    return () => clearInterval(interval);
  }, [timer]);

  const handleVerify = async () => {
    if (otp.length !== 6) {
      toast.error("Please enter a valid 6-digit code");
      return;
    }

    setIsVerifying(true);
    try {
      await verifySignupOTP(uid, otp);
      toast.success("Email verified successfully!");
      onVerified();
    } catch (error: any) {
      toast.error(error.message || "Verification failed");
      setOtp("");
    } finally {
      setIsVerifying(false);
    }
  };

  const handleResend = async () => {
    if (timer > 0) return;

    setIsResending(true);
    try {
      const code = generateOTP();
      await saveSignupOTP(uid, email, code);
      await sendSignupOTP(email, code);
      toast.success("New verification code sent!");
      setTimer(60);
    } catch (error: any) {
      toast.error(error.message || "Failed to resend code");
    } finally {
      setIsResending(false);
    }
  };

  return (
    <div className="flex flex-col items-center justify-center space-y-8 animate-in fade-in slide-in-from-bottom-4 duration-500">
      <div className="flex flex-col items-center text-center space-y-2">
        <div className="w-16 h-16 bg-primary/10 rounded-full flex items-center justify-center mb-2">
          <Mail className="w-8 h-8 text-primary" />
        </div>
        <h2 className="text-2xl font-bold text-white tracking-tight">Verify your email</h2>
        <p className="text-sm text-[#AFAFAF] max-w-xs">
          We've sent a 6-digit verification code to <span className="text-white font-medium">{email}</span>
        </p>
      </div>

      <div className="space-y-4">
        <InputOTP
          maxLength={6}
          value={otp}
          onChange={setOtp}
          disabled={isVerifying}
          autoFocus
        >
          <InputOTPGroup className="gap-2">
            {[...Array(6)].map((_, i) => (
              <InputOTPSlot
                key={i}
                index={i}
                className="w-12 h-14 bg-[#0D0D0D] border-[#212121] text-lg font-bold text-primary focus:ring-primary rounded-xl"
              />
            ))}
          </InputOTPGroup>
        </InputOTP>

        <Button
          onClick={handleVerify}
          disabled={isVerifying || otp.length !== 6}
          className="w-full bg-primary text-black font-bold h-12 rounded-xl hover:bg-primary/90 transition-all active:scale-[0.98]"
        >
          {isVerifying ? (
            <div className="flex items-center gap-2">
              <Loader2 className="w-4 h-4 animate-spin" />
              VERIFYING...
            </div>
          ) : (
            "VERIFY CODE"
          )}
        </Button>
      </div>

      <div className="flex flex-col items-center space-y-4">
        <p className="text-xs text-[#666]">
          Didn't receive the code?
        </p>
        <button
          onClick={handleResend}
          disabled={timer > 0 || isResending}
          className="flex items-center gap-2 text-xs font-bold text-primary hover:underline disabled:opacity-50 disabled:no-underline transition-all"
        >
          {isResending ? (
            <Loader2 className="w-3 h-3 animate-spin" />
          ) : (
            <RefreshCw className="w-3 h-3" />
          )}
          {timer > 0 ? `RESEND CODE IN ${timer}S` : "RESEND CODE"}
        </button>
      </div>
    </div>
  );
}
