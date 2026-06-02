import { useState, useEffect, useRef } from 'react';
import { getProfileImageURL } from '@shared/storageService';
import { uploadProfileImage } from '@shared/firebase';
import { useAuth } from '@/contexts/AuthContext';

const DEFAULT_PROFILE_IMAGE =
  'https://cdn.pixabay.com/photo/2015/10/05/22/37/blank-profile-picture-973460_1280.png';

interface ProfileImageUploaderProps {
  currentImageUrl?: string;
  size?: 'small' | 'medium' | 'large';
  onImageUploaded?: (url: string) => void;
  className?: string;
}

const ProfileImageUploader = ({
  currentImageUrl,
  size = 'medium',
  onImageUploaded,
  className = '',
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
      if (!currentUser?.uid) return;

      try {
        // Try to get image from cache first, then from Firebase
        const cachedImageUrl = getImageFromCache(currentUser.uid);
        if (cachedImageUrl) {
          setImageUrl(cachedImageUrl);
          if (onImageUploaded) {
            onImageUploaded(cachedImageUrl);
          }
          return;
        }

        // If not in cache, fetch from Firebase Storage
        const firebaseImageUrl = await getProfileImageURL(currentUser.uid);
        if (firebaseImageUrl) {
          setImageUrl(firebaseImageUrl);
          saveImageToCache(currentUser.uid, firebaseImageUrl);
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
  }, [currentUser?.uid, onImageUploaded]);

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
    if (isUploading || previewUrl) return;
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

      // Upload the image to Firebase Storage
      const downloadUrl = await uploadProfileImage(currentUser.uid, selectedFile);

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
          className={`${getSizeClasses()} rounded-full object-cover border-4 border-white shadow-lg cursor-pointer transition-all duration-300 hover:shadow-xl`}
          onClick={triggerFileUpload}
        />

        {/* Upload Overlay */}
        {previewUrl && (
          <div className="absolute inset-0 bg-white bg-opacity-70 flex flex-col justify-center items-center gap-2 rounded-full">
            {isUploading ? (
              <>
                <div className="w-12 h-12 border-4 border-purple-600 border-t-transparent rounded-full animate-spin"></div>
                <span className="text-purple-800 font-medium">Uploading...</span>
              </>
            ) : (
              <>
                <span className="text-purple-800 font-medium text-sm text-center px-2">
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
      <button
        onClick={triggerFileUpload}
        disabled={isUploading}
        className="mt-4 px-4 py-2 bg-purple-600 text-white rounded-full font-medium hover:bg-purple-700 transition-colors shadow-md hover:shadow-lg disabled:opacity-50 disabled:cursor-not-allowed"
      >
        {isUploading ? 'Uploading...' : 'Upload Photo'}
      </button>

      {/* Action Buttons (when in preview mode) */}
      {previewUrl && (
        <div className="absolute bottom-[-50px] left-1/2 transform -translate-x-1/2 flex gap-2">
          <button
            onClick={handleSaveImage}
            disabled={isUploading}
            className="px-3 py-1 bg-purple-600 text-white rounded-full text-sm font-medium hover:bg-purple-700 transition-colors disabled:opacity-50"
          >
            {isUploading ? 'Saving...' : 'Save'}
          </button>
          <button
            onClick={handleCancelUpload}
            disabled={isUploading}
            className="px-3 py-1 bg-gray-200 text-gray-700 rounded-full text-sm font-medium hover:bg-gray-300 transition-colors disabled:opacity-50"
          >
            Cancel
          </button>
        </div>
      )}
    </div>
  );
};

export default ProfileImageUploader;
