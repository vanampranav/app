import { Resend } from 'resend';
import { NextResponse } from 'next/server';

export async function POST(req: Request) {
    try {
        const resendKey = process.env.NEXT_PUBLIC_RESEND_KEY || process.env.RESEND_API_KEY;

        if (!resendKey) {
            console.error('❌ Resend Error: NEXT_PUBLIC_RESEND_KEY or RESEND_API_KEY is missing in .env.local');
            return NextResponse.json(
                { error: 'Email configuration missing on server' },
                { status: 500 }
            );
        }

        const resend = new Resend(resendKey);
        const { email, otpCode } = await req.json();

        if (!email || !otpCode) {
            return NextResponse.json(
                { error: 'Email and OTP code are required' },
                { status: 400 }
            );
        }

        const { data, error } = await resend.emails.send({
            from: 'EleFit <verify@mail.theelefit.com>', // You can change this to your verified domain later
            to: [email],
            subject: `${otpCode} is your EleFit verification code`,
            html: `
        <div style="font-family: sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; color: #333;">
          <h2 style="color: #000;">Verify your email</h2>
          <p>Your verification code for EleFit is:</p>
          <div style="background: #f4f4f4; padding: 20px; border-radius: 8px; text-align: center; margin: 20px 0;">
            <span style="font-size: 32px; font-weight: bold; letter-spacing: 5px; color: #000;">${otpCode}</span>
          </div>
          <p style="font-size: 14px; color: #666;">This code will expire in 10 minutes.</p>
          <hr style="border: none; border-top: 1px solid #eee; margin: 30px 0;" />
          <p style="font-size: 12px; color: #999;">If you didn't request this code, you can safely ignore this email.</p>
        </div>
      `,
        });

        if (error) {
            console.error('❌ Resend API Error:', error);
            return NextResponse.json({ error }, { status: 400 });
        }

        return NextResponse.json({ success: true, data });
    } catch (err: any) {
        console.error('❌ API Route Error:', err);
        return NextResponse.json(
            { error: err.message || 'Internal server error' },
            { status: 500 }
        );
    }
}
