import {
  createBooking,
  getUserBookings,
  updateBooking,
  getUserProfile,
} from "@/shared/firebase";
import { sendBookingConfirmation, sendBookingReminder } from "@/shared/emailService";

export interface BookingData {
  customerId: string;
  expertId: string;
  date: Date;
  time: string;
  duration: number;
  notes?: string;
  status?: "pending" | "confirmed" | "completed" | "cancelled";
}

export interface Booking extends BookingData {
  id: string;
  createdAt: Date;
  updatedAt?: Date;
}

/**
 * Create a new booking
 */
export const createNewBooking = async (bookingData: BookingData) => {
  try {
    const bookingId = await createBooking({
      ...bookingData,
      date: bookingData.date.toISOString(),
    });

    // Get customer and expert details for email
    const [customerProfile, expertProfile] = await Promise.all([
      getUserProfile(bookingData.customerId),
      getUserProfile(bookingData.expertId),
    ]);

    // Send confirmation emails
    if (customerProfile?.email) {
      await sendBookingConfirmation(
        customerProfile.email,
        `${customerProfile.firstName} ${customerProfile.lastName}`,
        `${expertProfile?.firstName} ${expertProfile?.lastName}`,
        `Date: ${bookingData.date.toLocaleDateString()}\nTime: ${bookingData.time}\nDuration: ${bookingData.duration} minutes`
      );
    }

    return bookingId;
  } catch (error) {
    throw new Error(
      error instanceof Error ? error.message : "Failed to create booking"
    );
  }
};

/**
 * Get all bookings for a customer
 */
export const fetchCustomerBookings = async (customerId: string) => {
  try {
    return await getUserBookings(customerId);
  } catch (error) {
    throw new Error(
      error instanceof Error ? error.message : "Failed to fetch bookings"
    );
  }
};

/**
 * Update booking status
 */
export const updateBookingStatus = async (
  bookingId: string,
  status: "pending" | "confirmed" | "completed" | "cancelled"
) => {
  try {
    await updateBooking(bookingId, { status });
  } catch (error) {
    throw new Error(
      error instanceof Error ? error.message : "Failed to update booking"
    );
  }
};

/**
 * Cancel booking
 */
export const cancelBooking = async (bookingId: string) => {
  try {
    await updateBookingStatus(bookingId, "cancelled");
  } catch (error) {
    throw new Error(
      error instanceof Error ? error.message : "Failed to cancel booking"
    );
  }
};

/**
 * Confirm booking
 */
export const confirmBooking = async (bookingId: string) => {
  try {
    await updateBookingStatus(bookingId, "confirmed");
  } catch (error) {
    throw new Error(
      error instanceof Error ? error.message : "Failed to confirm booking"
    );
  }
};

/**
 * Get expert's bookings
 */
export const fetchExpertBookings = async (expertId: string) => {
  try {
    const bookings = await getUserBookings(expertId);
    return bookings.filter((b: any) => b.expertId === expertId);
  } catch (error) {
    throw new Error(
      error instanceof Error ? error.message : "Failed to fetch expert bookings"
    );
  }
};

/**
 * Check expert availability for a time slot
 */
export const checkExpertAvailability = async (
  expertId: string,
  date: Date,
  time: string,
  duration: number
): Promise<boolean> => {
  try {
    const bookings = await fetchExpertBookings(expertId);
    const requestedStart = new Date(`${date.toISOString().split('T')[0]}T${time}`);
    const requestedEnd = new Date(requestedStart.getTime() + duration * 60000);

    return !bookings.some((booking: any) => {
      const bookingStart = new Date(booking.date);
      const bookingEnd = new Date(bookingStart.getTime() + booking.duration * 60000);

      return (
        (requestedStart >= bookingStart && requestedStart < bookingEnd) ||
        (requestedEnd > bookingStart && requestedEnd <= bookingEnd) ||
        (requestedStart <= bookingStart && requestedEnd >= bookingEnd)
      );
    });
  } catch (error) {
    throw new Error(
      error instanceof Error ? error.message : "Failed to check availability"
    );
  }
};

/**
 * Get available time slots for expert
 */
export const getAvailableSlots = async (
  expertId: string,
  date: Date,
  slotDuration: number = 60
): Promise<string[]> => {
  try {
    const bookings = await fetchExpertBookings(expertId);
    const bookedTimes = bookings
      .filter((b: any) => new Date(b.date).toDateString() === date.toDateString())
      .map((b: any) => ({
        start: new Date(b.date),
        end: new Date(new Date(b.date).getTime() + b.duration * 60000),
      }));

    // Generate 24-hour time slots
    const slots: string[] = [];
    for (let hour = 9; hour < 18; hour++) {
      for (let minute = 0; minute < 60; minute += 30) {
        const timeStr = `${hour.toString().padStart(2, '0')}:${minute.toString().padStart(2, '0')}`;
        const slotStart = new Date(date);
        slotStart.setHours(hour, minute, 0, 0);
        const slotEnd = new Date(slotStart.getTime() + slotDuration * 60000);

        const isAvailable = !bookedTimes.some(
          (booked) =>
            (slotStart >= booked.start && slotStart < booked.end) ||
            (slotEnd > booked.start && slotEnd <= booked.end)
        );

        if (isAvailable) {
          slots.push(timeStr);
        }
      }
    }

    return slots;
  } catch (error) {
    throw new Error(
      error instanceof Error ? error.message : "Failed to fetch available slots"
    );
  }
};
