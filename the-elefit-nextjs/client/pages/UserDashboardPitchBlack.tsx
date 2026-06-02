import { useState, useEffect } from 'react';
import { useAuth } from '@/contexts/AuthContext';
import { getUserProfile, updateUserProfile } from '@shared/firebase';
import { User, ChevronDown, Download, Pencil } from 'lucide-react';
import ProfileImageUploader from '@/components/ProfileImageUploader';
import BottomNav from '@/components/BottomNavNew';

type TabType = 'profile' | 'schedules';

interface UserData {
  firstName: string;
  lastName: string;
  email: string;
  phone: string;
  age: string;
  gender: string;
  height: string;
  weight: string;
  activityLevel: string;
  targetWeight: string;
  allergies: string;
  healthGoals: string;
  dietaryRestrictions: string;
}

const UserDashboardPitchBlack = () => {
  const { user: currentUser } = useAuth();
  const [activeTab, setActiveTab] = useState<TabType>('profile');
  const [userData, setUserData] = useState<UserData>({
    firstName: '',
    lastName: '',
    email: '',
    phone: '',
    age: '',
    gender: '',
    height: '',
    weight: '',
    activityLevel: '',
    targetWeight: '',
    allergies: '',
    healthGoals: '',
    dietaryRestrictions: '',
  });
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [message, setMessage] = useState<{ text: string; type: 'success' | 'error' | '' }>({
    text: '',
    type: '',
  });

  // Load user data from Firebase
  useEffect(() => {
    const loadUserData = async () => {
      if (!currentUser?.uid) return;

      try {
        setLoading(true);
        const profileData = await getUserProfile(currentUser.uid);
        console.log('Firebase profile data:', profileData); // Debug log

        if (profileData) {
          // Parse name if it's a single string
          let firstName = '';
          let lastName = '';
          if (profileData.name) {
            const nameParts = profileData.name.split(' ');
            firstName = nameParts[0] || '';
            lastName = nameParts.slice(1).join(' ') || '';
          }

          setUserData({
            firstName:
              profileData.firstName || firstName || currentUser.displayName?.split(' ')[0] || '',
            lastName:
              profileData.lastName || lastName || currentUser.displayName?.split(' ')[1] || '',
            email: profileData.email || currentUser.email || '',
            phone: profileData.phone || '',
            age: profileData.age?.toString() || '',
            gender: profileData.gender || '',
            height: profileData.height?.toString() || '',
            weight: profileData.weight?.toString() || '',
            activityLevel: profileData.activityLevel || '',
            targetWeight: profileData.targetWeight?.toString() || '',
            allergies: profileData.allergies || '',
            healthGoals: profileData.healthGoals || '',
            dietaryRestrictions: profileData.dietaryRestrictions || '',
          });
        } else {
          // Set defaults from auth if no profile exists
          setUserData({
            firstName: currentUser.displayName?.split(' ')[0] || '',
            lastName: currentUser.displayName?.split(' ')[1] || '',
            email: currentUser.email || '',
            phone: '',
            age: '',
            gender: '',
            height: '',
            weight: '',
            activityLevel: '',
            targetWeight: '',
            allergies: '',
            healthGoals: '',
            dietaryRestrictions: '',
          });
        }
      } catch (error) {
        console.error('Error loading user data:', error);
        setMessage({ text: 'Failed to load profile data', type: 'error' });
      } finally {
        setLoading(false);
      }
    };

    loadUserData();
  }, [currentUser]);

  const handleInputChange = (field: keyof UserData, value: string) => {
    setUserData(prev => ({
      ...prev,
      [field]: value,
    }));
  };

  const handleSave = async () => {
    if (!currentUser?.uid) return;

    setSaving(true);
    setMessage({ text: '', type: '' });

    try {
      // Prepare data for saving
      const dataToSave = {
        firstName: userData.firstName,
        lastName: userData.lastName,
        name: `${userData.firstName} ${userData.lastName}`.trim(),
        email: userData.email,
        phone: userData.phone,
        age: userData.age ? parseInt(userData.age) : null,
        gender: userData.gender,
        height: userData.height ? parseInt(userData.height) : null,
        weight: userData.weight ? parseInt(userData.weight) : null,
        activityLevel: userData.activityLevel,
        targetWeight: userData.targetWeight ? parseInt(userData.targetWeight) : null,
        allergies: userData.allergies,
        healthGoals: userData.healthGoals,
        dietaryRestrictions: userData.dietaryRestrictions,
      };

      console.log('Saving data to Firebase:', dataToSave); // Debug log
      await updateUserProfile(currentUser.uid, dataToSave);

      setMessage({ text: 'Profile updated successfully!', type: 'success' });
      setTimeout(() => setMessage({ text: '', type: '' }), 3000);
    } catch (error) {
      console.error('Error updating profile:', error);
      setMessage({ text: 'Failed to update profile. Please try again.', type: 'error' });
    } finally {
      setSaving(false);
    }
  };

  const handleCancel = () => {
    // Reload data from Firebase
    window.location.reload();
  };

  if (loading) {
    return (
      <div className="min-h-screen bg-black flex items-center justify-center">
        <div className="text-white">Loading profile...</div>
      </div>
    );
  }

  const statsData = [
    { value: `${userData.height || '172'} cm`, label: 'Height' },
    { value: `${userData.weight || '73'} kg`, label: 'Weight' },
    { value: `${userData.age || '27'} y`, label: 'Age' },
  ];

  const personalInfoFields = [
    { name: 'firstName' as keyof UserData, label: 'First Name', type: 'text' },
    { name: 'lastName' as keyof UserData, label: 'Last Name', type: 'text' },
    { name: 'email' as keyof UserData, label: 'Email', type: 'email' },
    { name: 'phone' as keyof UserData, label: 'Phone', type: 'tel' },
    { name: 'age' as keyof UserData, label: 'Age', type: 'number' },
    { name: 'gender' as keyof UserData, label: 'Gender', type: 'select' },
  ];

  const healthInfoFields = [
    { name: 'height' as keyof UserData, label: 'Height', type: 'number', unit: 'cm' },
    { name: 'weight' as keyof UserData, label: 'Weight', type: 'number', unit: 'kg' },
    { name: 'activityLevel' as keyof UserData, label: 'Activity Level', type: 'select' },
    { name: 'targetWeight' as keyof UserData, label: 'Target Weight', type: 'number', unit: 'kg' },
  ];

  const textareaFields = [
    { name: 'allergies' as keyof UserData, label: 'Allergies' },
    { name: 'healthGoals' as keyof UserData, label: 'Health Goals' },
    { name: 'dietaryRestrictions' as keyof UserData, label: 'Dietary Restrictions' },
  ];

  return (
    <div className="min-h-screen bg-black">
      {/* Top Navigation Bar */}
      <header className="h-[86px] flex items-center justify-between bg-[#111111] border-b border-[#212121] px-16">
        <div className="flex items-center gap-4">
          <button className="w-9 h-9 flex items-center justify-center bg-[#ccd853] rounded-[18px] rotate-180">
            <svg
              width="24"
              height="24"
              viewBox="0 0 24 24"
              fill="none"
              xmlns="http://www.w3.org/2000/svg"
            >
              <path
                d="M15 18L9 12L15 6"
                stroke="#111111"
                strokeWidth="2"
                strokeLinecap="round"
                strokeLinejoin="round"
              />
            </svg>
          </button>

          <div className="flex items-center gap-3">
            <User className="w-6 h-6 text-[#e1e1e1]" />
            <h1 className="text-[#e1e1e1] text-2xl font-bold">Profile Section</h1>
          </div>
        </div>
      </header>

      {/* Main Content */}
      <main className="flex justify-center py-8 px-4">
        <div className="w-full max-w-6xl bg-[#0c0c0c] rounded-2xl">
          {/* Profile Header Section */}
          <section className="flex flex-col items-center gap-5 pt-6 pb-8">
            <div className="flex flex-col items-center gap-2">
              <div className="relative">
                <ProfileImageUploader
                  size="large"
                  onImageUploaded={url => console.log('Profile image updated:', url)}
                />
              </div>

              <div className="flex flex-col items-center gap-2">
                <div className="text-white text-base font-medium">
                  {userData.firstName} {userData.lastName}
                </div>
                <div className="text-[#828282] text-sm font-medium">{userData.email}</div>
              </div>
            </div>

            {/* Stats Cards */}
            <div className="flex items-center justify-center gap-6 w-full">
              {statsData.map((stat, index) => (
                <div
                  key={index}
                  className="flex flex-col items-center justify-center gap-2 px-4 py-3.5 flex-1 bg-[#0c0c0c] rounded-lg border border-[#212121]"
                >
                  <div className="text-white text-lg font-medium">{stat.value}</div>
                  <div className="text-[#ababab] text-xs font-normal">{stat.label}</div>
                </div>
              ))}
            </div>
          </section>

          {/* Tab Navigation */}
          <nav className="flex border-b border-[#212121] px-8">
            <button
              className={`flex-1 py-4 border-b-4 ${activeTab === 'profile' ? 'border-[#ccd853]' : 'border-transparent'}`}
              onClick={() => setActiveTab('profile')}
            >
              <div className="flex items-center justify-center gap-2">
                <User
                  className={`w-[18px] h-[18px] ${activeTab === 'profile' ? 'text-[#ccd853]' : 'text-[#999999]'}`}
                />
                <span
                  className={`text-xs font-semibold ${activeTab === 'profile' ? 'text-[#ccd853]' : 'text-[#999999]'}`}
                >
                  Profile Info
                </span>
              </div>
            </button>

            <button
              className={`flex-1 py-4 border-b-4 ${activeTab === 'schedules' ? 'border-[#ccd853]' : 'border-transparent'}`}
              onClick={() => setActiveTab('schedules')}
            >
              <div className="flex items-center justify-center gap-2">
                <Download
                  className={`w-[18px] h-[18px] ${activeTab === 'schedules' ? 'text-[#ccd853]' : 'text-[#999999]'}`}
                />
                <span
                  className={`text-xs font-semibold ${activeTab === 'schedules' ? 'text-[#ccd853]' : 'text-[#999999]'}`}
                >
                  Saved Schedules
                </span>
              </div>
            </button>
          </nav>

          {/* Tab Content */}
          <div className="p-8">
            {activeTab === 'profile' && (
              <div className="space-y-12">
                {/* Personal Info Section */}
                <div className="space-y-5">
                  <h2 className="text-white text-base font-semibold">Personal info</h2>

                  <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-3">
                    {personalInfoFields.map(field => (
                      <div key={field.name} className="space-y-2">
                        <label className="text-white text-sm font-normal block">
                          {field.label}
                        </label>

                        {field.type === 'select' ? (
                          <div className="relative">
                            <select
                              value={userData[field.name]}
                              onChange={e => handleInputChange(field.name, e.target.value)}
                              className="w-full h-[39px] bg-[#212121] rounded-lg border border-[#454545] px-3 text-white text-sm font-normal appearance-none focus:outline-none focus:ring-2 focus:ring-[#ccd853]"
                            >
                              <option value="">Select {field.label}</option>
                              <option value="male">Male</option>
                              <option value="female">Female</option>
                              <option value="other">Other</option>
                              <option value="prefer-not-to-say">Prefer not to say</option>
                            </select>
                            <ChevronDown className="absolute right-3 top-1/2 transform -translate-y-1/2 w-[18px] h-[18px] text-white pointer-events-none" />
                          </div>
                        ) : (
                          <input
                            type={field.type}
                            value={userData[field.name]}
                            onChange={e => handleInputChange(field.name, e.target.value)}
                            className="w-full h-[39px] bg-[#212121] rounded-lg border border-[#454545] px-3 text-white text-sm font-normal focus:outline-none focus:ring-2 focus:ring-[#ccd853]"
                          />
                        )}
                      </div>
                    ))}
                  </div>
                </div>

                {/* Health Information Section */}
                <div className="space-y-5">
                  <h2 className="text-white text-base font-semibold">Health Information</h2>

                  <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-3 mb-6">
                    {healthInfoFields.map(field => (
                      <div key={field.name} className="space-y-2">
                        <label className="text-white text-sm font-normal block">
                          {field.label}
                        </label>

                        {field.type === 'select' ? (
                          <div className="relative">
                            <select
                              value={userData[field.name]}
                              onChange={e => handleInputChange(field.name, e.target.value)}
                              className="w-full h-[39px] bg-[#212121] rounded-lg border border-[#454545] px-3 text-white text-sm font-normal appearance-none focus:outline-none focus:ring-2 focus:ring-[#ccd853]"
                            >
                              <option value="">Select {field.label}</option>
                              <option value="sedentary">Sedentary</option>
                              <option value="light">Light Exercise</option>
                              <option value="moderate">Moderate Exercise</option>
                              <option value="active">Active</option>
                              <option value="very-active">Very Active</option>
                            </select>
                            <ChevronDown className="absolute right-3 top-1/2 transform -translate-y-1/2 w-[18px] h-[18px] text-white pointer-events-none" />
                          </div>
                        ) : (
                          <div className="relative">
                            <input
                              type={field.type}
                              value={userData[field.name]}
                              onChange={e => handleInputChange(field.name, e.target.value)}
                              className="w-full h-[39px] bg-[#212121] rounded-lg border border-[#454545] px-3 text-white text-sm font-normal focus:outline-none focus:ring-2 focus:ring-[#ccd853]"
                            />
                            <span className="absolute right-3 top-1/2 transform -translate-y-1/2 text-white text-sm font-normal pointer-events-none">
                              {field.unit}
                            </span>
                          </div>
                        )}
                      </div>
                    ))}
                  </div>

                  <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
                    {textareaFields.map(field => (
                      <div key={field.name} className="space-y-2">
                        <label className="text-white text-sm font-normal block">
                          {field.label}
                        </label>
                        <textarea
                          value={userData[field.name]}
                          onChange={e => handleInputChange(field.name, e.target.value)}
                          className="h-[123px] w-full bg-[#212121] rounded-lg border border-[#454545] p-3 text-white text-sm font-normal resize-none focus:outline-none focus:ring-2 focus:ring-[#ccd853]"
                        />
                      </div>
                    ))}
                  </div>
                </div>

                {/* Messages */}
                {message.text && (
                  <div
                    className={`px-6 py-3 rounded-lg text-center ${
                      message.type === 'success'
                        ? 'bg-green-900/30 text-green-400 border border-green-800'
                        : 'bg-red-900/30 text-red-400 border border-red-800'
                    }`}
                  >
                    {message.text}
                  </div>
                )}

                {/* Action Buttons */}
                <div className="flex justify-end gap-4 pt-6">
                  <button
                    onClick={handleCancel}
                    disabled={saving}
                    className="h-8 px-4 py-2 rounded bg-transparent border border-[#454545] text-[#dddddd] text-sm font-medium hover:bg-[#212121] transition-colors disabled:opacity-50"
                  >
                    Cancel
                  </button>
                  <button
                    onClick={handleSave}
                    disabled={saving}
                    className="h-8 px-4 py-2 bg-[#ccd853] rounded text-[#1e1e1e] text-sm font-medium hover:bg-[#b8c24a] transition-colors disabled:opacity-50 flex items-center gap-2"
                  >
                    {saving && (
                      <svg
                        className="animate-spin h-4 w-4"
                        xmlns="http://www.w3.org/2000/svg"
                        fill="none"
                        viewBox="0 0 24 24"
                      >
                        <circle
                          className="opacity-25"
                          cx="12"
                          cy="12"
                          r="10"
                          stroke="currentColor"
                          strokeWidth="4"
                        ></circle>
                        <path
                          className="opacity-75"
                          fill="currentColor"
                          d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
                        ></path>
                      </svg>
                    )}
                    {saving ? 'Saving...' : 'Save'}
                  </button>
                </div>
              </div>
            )}

            {/* Saved Schedules Content */}
            {activeTab === 'schedules' && (
              <div className="flex flex-col items-center justify-center py-16 text-center">
                <div className="text-gray-500">
                  <Download className="w-16 h-16 mx-auto mb-4" />
                  <h3 className="text-white text-lg font-medium mb-2">No saved schedules yet</h3>
                  <p className="text-gray-500">Your saved schedules will appear here</p>
                </div>
              </div>
            )}
          </div>
        </div>
      </main>

      {/* Bottom Navigation */}
      <BottomNav />
    </div>
  );
};

export default UserDashboardPitchBlack;
