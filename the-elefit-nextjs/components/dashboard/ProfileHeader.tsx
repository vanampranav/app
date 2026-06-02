import { useAuth } from '@/contexts/AuthContext';
import ProfileImageUploader from '@/components/ProfileImageUploader';

interface ProfileHeaderProps {
  formData: {
    height: string;
    weight: string;
    age: string;
  };
}

const ProfileHeader = ({ formData }: ProfileHeaderProps) => {
  const { user: currentUser } = useAuth();

  return (
    <div className="flex flex-col items-center gap-5 w-full max-w-md mx-auto">
      {/* Profile Image Section */}
      <div className="flex flex-col items-center gap-4">
        <ProfileImageUploader
          size="large"
          onImageUploaded={url => console.log('Profile image updated:', url)}
        />

        {/* User Info */}
        <div className="flex flex-col items-center gap-2">
          <h2 className="text-white font-inter text-xl font-semibold">
            {currentUser?.displayName || 'User'}
          </h2>
          <p className="text-gray-400 font-inter text-sm">
            {currentUser?.email || 'user@example.com'}
          </p>
        </div>
      </div>

      {/* Metrics Cards */}
      <div className="flex justify-center gap-4 w-full">
        <MetricCard value={`${formData.height || '172'} cm`} label="Height" />
        <MetricCard value={`${formData.weight || '73'} kg`} label="Weight" />
        <MetricCard value={`${formData.age || '27'} y`} label="Age" />
      </div>
    </div>
  );
};

interface MetricCardProps {
  value: string;
  label: string;
}

const MetricCard = ({ value, label }: MetricCardProps) => (
  <div className="flex flex-col items-center gap-2 px-4 py-3 rounded-lg border border-gray-800 bg-gray-900 flex-1">
    <span className="text-white font-inter text-lg font-medium">{value}</span>
    <span className="text-gray-500 font-inter text-xs">{label}</span>
  </div>
);

export default ProfileHeader;
