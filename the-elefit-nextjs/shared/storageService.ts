import { uploadProfileImage, deleteFile, getUserProfile } from "@/shared/firebase";

/**
 * Upload and save profile image
 */
export const updateProfileImage = async (
  uid: string,
  file: File,
  email?: string,
  userType: string = "users"
): Promise<string> => {
  try {
    // Validate file
    if (!file.type.startsWith("image/")) {
      throw new Error("File must be an image");
    }

    if (file.size > 5 * 1024 * 1024) {
      throw new Error("File size must be less than 5MB");
    }

    const downloadUrl = await uploadProfileImage(uid, file, email, userType);
    return downloadUrl;
  } catch (error) {
    throw new Error(
      error instanceof Error
        ? error.message
        : "Failed to update profile image"
    );
  }
};

/**
 * Delete profile image
 */
export const removeProfileImage = async (uid: string, imagePath: string) => {
  try {
    await deleteFile(imagePath);
  } catch (error) {
    throw new Error(
      error instanceof Error
        ? error.message
        : "Failed to delete profile image"
    );
  }
};

/**
 * Validate image file
 */
export const validateImageFile = (file: File): string | null => {
  const validTypes = ["image/jpeg", "image/png", "image/webp"];
  const maxSize = 5 * 1024 * 1024; // 5MB

  if (!validTypes.includes(file.type)) {
    return "Invalid file type. Please use JPEG, PNG, or WebP";
  }

  if (file.size > maxSize) {
    return "File size must be less than 5MB";
  }

  return null;
};

/**
 * Compress image before upload
 */
export const compressImage = async (file: File): Promise<Blob> => {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.readAsDataURL(file);
    reader.onload = (event) => {
      const img = new Image();
      img.src = event.target?.result as string;
      img.onload = () => {
        const canvas = document.createElement("canvas");
        const ctx = canvas.getContext("2d");
        if (!ctx) {
          reject(new Error("Failed to get canvas context"));
          return;
        }

        // Resize to max 1000x1000
        const maxDim = 1000;
        let width = img.width;
        let height = img.height;
        if (width > height) {
          if (width > maxDim) {
            height = (height * maxDim) / width;
            width = maxDim;
          }
        } else {
          if (height > maxDim) {
            width = (width * maxDim) / height;
            height = maxDim;
          }
        }

        canvas.width = width;
        canvas.height = height;
        ctx.drawImage(img, 0, 0, width, height);

        canvas.toBlob(
          (blob) => {
            if (blob) {
              resolve(blob);
            } else {
              reject(new Error("Failed to compress image"));
            }
          },
          "image/jpeg",
          0.8
        );
      };
      img.onerror = () => reject(new Error("Failed to load image"));
    };
    reader.onerror = () => reject(new Error("Failed to read file"));
  });
};

/**
 * Get profile image URL
 */
export const getProfileImageURL = async (uid: string): Promise<string | null> => {
  try {
    const profile = await getUserProfile(uid);
    // Check both field names for compatibility with reference logic
    return profile?.profileImageUrl || profile?.profileImageURL || null;
  } catch (error) {
    console.error("Error getting profile image URL:", error);
    return null;
  }
};
