import { CompactProfileCard } from '../components/profile/CompactProfileCard';
import { PasswordModal } from '../components/profile/PasswordModal';
import { ErrorState } from '../components/common/ErrorState';
import { LoadingState } from '../components/common/LoadingState';
import { useProfile } from '../hooks/useProfile';
import { useEffect, useState } from 'react';
import { useToast } from '../components/common/toastContext';
import { useAuth } from '../context/authContext';

const DEFAULT_AVATAR = 'https://i.pravatar.cc/160?img=13';

export default function Profile() {
  const [isPasswordOpen, setIsPasswordOpen] = useState(false);
  const { showToast } = useToast();
  const { can } = useAuth();
  const canEditProfile = can('profile:edit_self');
  const {
    draft,
    message,
    isLoading,
    isSaving,
    isPasswordSaving,
    loadError,
    refetch,
    updateDraft,
    pickAvatar,
    removeAvatar,
    resetDraft,
    saveProfile,
    changePassword,
    showMessage,
  } = useProfile(DEFAULT_AVATAR);

  useEffect(() => {
    if (!message) return;
    showToast({ type: message.type, message: message.text });
  }, [message, showToast]);

  return (
    <div className="profile-page space-y-4 pt-2" data-view="profile">
      {loadError ? (
        <ErrorState title="Không thể tải hồ sơ" message={loadError} onRetry={() => void refetch()} />
      ) : null}

      {isLoading ? (
        <LoadingState
          variant="block"
          message="Đang tải hồ sơ..."
          shape="profile"
          className=""
        />
      ) : null}

      {!isLoading ? (
        <CompactProfileCard
          draft={draft}
          defaultAvatar={DEFAULT_AVATAR}
          onChange={updateDraft}
          onSave={() => void saveProfile()}
          onReset={resetDraft}
          onAvatarError={(text) => showMessage({ type: 'error', text })}
          onAvatarPicked={pickAvatar}
          onAvatarRemoved={removeAvatar}
          onOpenPassword={() => setIsPasswordOpen(true)}
          isSaving={isSaving}
          canEdit={canEditProfile}
        />
      ) : null}

      <PasswordModal
        isOpen={isPasswordOpen}
        onClose={() => {
          if (!isPasswordSaving) setIsPasswordOpen(false);
        }}
        onMessage={showMessage}
        onChangePassword={changePassword}
        isSaving={isPasswordSaving}
      />
    </div>
  );
}
