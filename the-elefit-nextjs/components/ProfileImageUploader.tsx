import { useState, useEffect, useRef } from 'react';
import { getProfileImageURL, updateProfileImage } from '@/shared/storageService';
import { useAuth } from '@/contexts/AuthContext';

const DEFAULT_PROFILE_IMAGE =
  'https://cdn.pixabay.com/photo/2015/10/05/22/37/blank-profile-picture-973460_1280.png';

interface ProfileImageUploaderProps {
  currentImageUrl?: string;
  size?: 'small' | 'medium' | 'large';
  onImageUploaded?: (url: string) => void;
  className?: string;
  isEditable?: boolean;
}

const ProfileImageUploader = ({
  currentImageUrl,
  size = 'medium',
  onImageUploaded,
  className = '',
  isEditable = true,
}: ProfileImageUploaderProps) => {
  const { user: currentUser } = useAuth();
  const [imageUrl, setImageUrl] = useState(currentImageUrl || DEFAULT_PROFILE_IMAGE);
  const [previewUrl, setPreviewUrl] = useState<string | null>(null);
  const [selectedFile, setSelectedFile] = useState<File | null>(null);
  const [isUploading, setIsUploading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);

  // Load profile image from Firebase
  useEffect(() => {
    const loadProfileImage = async () => {
      if (!(currentUser as any)?.uid) return;

      try {
        // Try to get image from cache first, then from Firebase
        const cachedImageUrl = getImageFromCache((currentUser as any).uid);
        if (cachedImageUrl) {
          setImageUrl(cachedImageUrl);
          if (onImageUploaded) {
            onImageUploaded(cachedImageUrl);
          }
          return;
        }

        // If not in cache, fetch from Firebase Storage
        const firebaseImageUrl = await getProfileImageURL((currentUser as any).uid);
        if (firebaseImageUrl) {
          setImageUrl(firebaseImageUrl);
          saveImageToCache((currentUser as any).uid, firebaseImageUrl);
          if (onImageUploaded) {
            onImageUploaded(firebaseImageUrl);
          }
        }
      } catch (error) {
        console.error('Error loading profile image:', error);
        // Fall back to default image
        setImageUrl(DEFAULT_PROFILE_IMAGE);
      }
    };

    loadProfileImage();
  }, [(currentUser as any)?.uid, onImageUploaded]);

  const getImageFromCache = (userId: string): string | null => {
    try {
      const cachedData = localStorage.getItem(`profileImage_${userId}`);
      if (cachedData) {
        const { url, timestamp } = JSON.parse(cachedData);
        // Check if cache is less than 24 hours old
        const now = new Date().getTime();
        if (now - timestamp < 86400000) {
          return url;
        } else {
          // Cache expired, remove it
          localStorage.removeItem(`profileImage_${userId}`);
        }
      }
    } catch (error) {
      console.error('Error reading from cache:', error);
    }
    return null;
  };

  const saveImageToCache = (userId: string, url: string) => {
    try {
      const cacheData = {
        url,
        timestamp: new Date().getTime(),
      };
      localStorage.setItem(`profileImage_${userId}`, JSON.stringify(cacheData));
    } catch (error) {
      console.error('Error saving to cache:', error);
    }
  };

  const triggerFileUpload = () => {
    if (!isEditable || isUploading || previewUrl) return;
    fileInputRef.current?.click();
  };

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    // Validate file type
    if (!file.type.match('image.*')) {
      setError('Please select an image file (png, jpg, jpeg)');
      return;
    }

    // Validate file size (max 5MB)
    if (file.size > 5 * 1024 * 1024) {
      setError('Image size should be less than 5MB');
      return;
    }

    // Create a temporary URL for preview
    const tempPreviewUrl = URL.createObjectURL(file);
    setPreviewUrl(tempPreviewUrl);
    setSelectedFile(file);
    setError(null);
  };

  const handleSaveImage = async () => {
    if (!selectedFile || !currentUser?.uid) return;

    try {
      setIsUploading(true);
      setError(null);

      // Map AuthContext user to the parameters needed
      const email = currentUser.email || "";
      const userTypeMap = {
        'customer': 'users',
        'expert': 'experts',
        'admin': 'users' // Default admin to users collection
      };
      const userType = userTypeMap[(currentUser as any).userType as keyof typeof userTypeMap] || 'users';

      // Use the service that now handles all fields/collections
      const downloadUrl = await updateProfileImage(currentUser.uid, selectedFile, email, userType);

      // Save the new URL to cache
      saveImageToCache(currentUser.uid, downloadUrl);

      // Call the callback with the new image URL
      if (onImageUploaded) {
        onImageUploaded(downloadUrl);
      }

      // Clean up the temporary URL
      if (previewUrl) {
        URL.revokeObjectURL(previewUrl);
      }

      // Set the final image URL
      setImageUrl(downloadUrl);
      setPreviewUrl(null);
      setSelectedFile(null);
    } catch (error) {
      console.error('Error uploading image:', error);
      setError('Failed to upload image. Please try again.');
    } finally {
      setIsUploading(false);
    }
  };

  const handleCancelUpload = () => {
    if (previewUrl) {
      URL.revokeObjectURL(previewUrl);
    }
    setPreviewUrl(null);
    setSelectedFile(null);
    setError(null);
    // Reset file input
    if (fileInputRef.current) {
      fileInputRef.current.value = '';
    }
  };

  const getSizeClasses = () => {
    switch (size) {
      case 'small':
        return 'w-20 h-20';
      case 'large':
        return 'w-48 h-48 border-4';
      default:
        return 'w-32 h-32';
    }
  };

  return (
    <div className={`profile-image-uploader ${size} ${className}`}>
      <div className="image-container relative">
        <img
          src={previewUrl || imageUrl}
          alt="Profile"
          className={`${getSizeClasses()} rounded-full object-cover border-4 border-white shadow-lg ${isEditable ? 'cursor-pointer hover:shadow-xl' : 'cursor-default'} transition-all duration-300`}
          onClick={isEditable ? triggerFileUpload : undefined}
        />

        {/* Upload Overlay */}
        {previewUrl && (
          <div className="absolute inset-0 bg-white bg-opacity-70 flex flex-col justify-center items-center gap-2 rounded-full">
            {isUploading ? (
              <>
                <div className="w-12 h-12 border-4 border-[#ccd853] border-t-transparent rounded-full animate-spin"></div>
                <span className="text-[#ccd853] font-medium">Uploading...</span>
              </>
            ) : (
              <>
                <span className="text-[#ccd853] font-medium text-sm text-center px-2">
                  Preview
                </span>
              </>
            )}
          </div>
        )}

        {/* Error Message */}
        {error && (
          <div className="absolute -bottom-8 left-0 right-0 text-red-500 text-xs text-center bg-red-50 px-2 py-1 rounded">
            {error}
          </div>
        )}
      </div>

      {/* Hidden File Input */}
      <input
        ref={fileInputRef}
        type="file"
        accept="image/*"
        onChange={handleFileChange}
        className="hidden"
      />

      {/* Upload Button */}
      {isEditable && (
        <button
          onClick={triggerFileUpload}
          disabled={isUploading}
          className="mt-4 px-6 py-2 bg-[#ccd853] text-black rounded-full font-bold hover:bg-[#b8c54a] transition-all shadow-md hover:shadow-lg disabled:opacity-50 disabled:cursor-not-allowed text-sm uppercase tracking-wider"
        >
          {isUploading ? 'Uploading...' : 'Upload Photo'}
        </button>
      )}

      {/* Action Buttons (when in preview mode) */}
      {previewUrl && (
        <div className="mt-4 flex gap-3">
          <button
            onClick={handleSaveImage}
            disabled={isUploading}
            className="px-6 py-2 bg-[#ccd853] text-black rounded-full text-xs font-bold hover:bg-[#b8c54a] transition-all disabled:opacity-50 uppercase tracking-tight"
          >
            {isUploading ? 'Saving...' : 'Save'}
          </button>
          <button
            onClick={handleCancelUpload}
            disabled={isUploading}
            className="px-6 py-2 bg-[#212121] text-white border border-[#454545] rounded-full text-xs font-bold hover:bg-[#333333] transition-all disabled:opacity-50 uppercase tracking-tight"
          >
            Cancel
          </button>
        </div>
      )}
    </div>
  );
};

export default ProfileImageUploader;
