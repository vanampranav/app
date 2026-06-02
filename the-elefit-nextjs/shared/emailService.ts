import emailjs from "@emailjs/browser";

// Initialize EmailJS
if (process.env.NEXT_PUBLIC_EMAILJS_PUBLIC_KEY) {
  emailjs.init(process.env.NEXT_PUBLIC_EMAILJS_PUBLIC_KEY);
}

interface EmailParams {
  to_email: string;
  user_name?: string;
  subject?: string;
  message?: string;
  booking_details?: string;
  expert_name?: string;
  [key: string]: string | undefined;
}

/**
 * Send email using EmailJS
 */
export const sendEmail = async (
  serviceId: string,
  templateId: string,
  params: EmailParams
) => {
  try {
    const response = await emailjs.send(
      serviceId,
      templateId,
      { ...params },
      process.env.NEXT_PUBLIC_EMAILJS_PUBLIC_KEY
    );
    return response;
  } catch (error) {
    throw new Error(
      error instanceof Error ? error.message : "Email sending failed"
    );
  }
};

/**
 * Send welcome email
 */
export const sendWelcomeEmail = async (email: string, firstName: string) => {
  try {
    await sendEmail(
      process.env.NEXT_PUBLIC_EMAILJS_SERVICE_ID as string,
      process.env.NEXT_PUBLIC_EMAILJS_TEMPLATE_ID as string,
      {
        to_email: email,
        user_name: firstName,
        subject: "Welcome to EleFit",
        message: `Hi ${firstName}, Welcome to EleFit! Your account has been created successfully.`,
      }
    );
  } catch (error) {
    console.error("Error sending welcome email:", error);
  }
};

/**
 * Send password reset email
 */
export const sendPasswordResetEmail = async (email: string, resetLink: string) => {
  try {
    await sendEmail(
      process.env.NEXT_PUBLIC_EMAILJS_SERVICE_ID as string,
      process.env.NEXT_PUBLIC_EMAILJS_TEMPLATE_ID as string,
      {
        to_email: email,
        subject: "Password Reset",
        message: `Click this link to reset your password: ${resetLink}`,
      }
    );
  } catch (error) {
    console.error("Error sending password reset email:", error);
  }
};

/**
 * Send booking confirmation email
 */
export const sendBookingConfirmation = async (
  customerEmail: string,
  customerName: string,
  expertName: string,
  bookingDetails: string
) => {
  try {
    await sendEmail(
      process.env.NEXT_PUBLIC_EMAILJS_SERVICE_ID as string,
      process.env.NEXT_PUBLIC_EMAILJS_TEMPLATE_ID as string,
      {
        to_email: customerEmail,
        user_name: customerName,
        expert_name: expertName,
        booking_details: bookingDetails,
        subject: "Booking Confirmed",
        message: `Your booking with ${expertName} has been confirmed.\n\nDetails:\n${bookingDetails}`,
      }
    );
  } catch (error) {
    console.error("Error sending booking confirmation:", error);
  }
};

/**
 * Send booking reminder email
 */
export const sendBookingReminder = async (
  customerEmail: string,
  customerName: string,
  expertName: string,
  bookingTime: string
) => {
  try {
    await sendEmail(
      process.env.NEXT_PUBLIC_EMAILJS_SERVICE_ID as string,
      process.env.NEXT_PUBLIC_EMAILJS_TEMPLATE_ID as string,
      {
        to_email: customerEmail,
        user_name: customerName,
        expert_name: expertName,
        subject: "Booking Reminder",
        message: `Reminder: You have a session with ${expertName} at ${bookingTime}`,
      }
    );
  } catch (error) {
    console.error("Error sending booking reminder:", error);
  }
};

/**
 * Send expert application notification
 */
export const sendExpertApplicationNotification = async (
  adminEmail: string,
  applicantName: string,
  applicantEmail: string
) => {
  try {
    await sendEmail(
      process.env.NEXT_PUBLIC_EMAILJS_SERVICE_ID as string,
      process.env.NEXT_PUBLIC_EMAILJS_TEMPLATE_ID as string,
      {
        to_email: adminEmail,
        subject: "New Expert Application",
        message: `New expert application from ${applicantName} (${applicantEmail})`,
      }
    );
  } catch (error) {
    console.error("Error sending expert application notification:", error);
  }
};

/**
 * Send contact form email
 */
export const sendContactFormEmail = async (
  senderEmail: string,
  senderName: string,
  message: string,
  adminEmail: string
) => {
  try {
    await sendEmail(
      process.env.NEXT_PUBLIC_EMAILJS_SERVICE_ID as string,
      process.env.NEXT_PUBLIC_EMAILJS_TEMPLATE_ID as string,
      {
        to_email: adminEmail,
        subject: `New Contact Form Submission from ${senderName}`,
        message: `From: ${senderName} (${senderEmail})\n\n${message}`,
      }
    );
  } catch (error) {
    console.error("Error sending contact form email:", error);
  }
};
/**
 * Send signup OTP email
 */
export const sendSignupOTP = async (email: string, otpCode: string) => {
  try {
    const response = await fetch('/api/send-otp', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ email, otpCode }),
    });

    if (!response.ok) {
      const text = await response.text();
      let errorMessage = `Server error (${response.status})`;
      try {
        const json = JSON.parse(text);
        errorMessage = json.error || errorMessage;
      } catch (e) {
        // Not JSON, use truncated text as error
        errorMessage = text.substring(0, 100) || errorMessage;
      }
      throw new Error(errorMessage);
    }

    console.log(`✅ Resend OTP triggered successfully for ${email}`);
    return await response.json();
  } catch (error) {
    console.error("❌ Resend Email Service Error:", error);
    throw error;
  }
};
