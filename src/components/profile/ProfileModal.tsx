import { useEffect, useState } from 'react';
import { X } from 'lucide-react';
import { CompactProfileCard } from './CompactProfileCard';
import { PasswordModal } from './PasswordModal';
import { ErrorState } from '../common/ErrorState';
import { LoadingState } from '../common/LoadingState';
import { useProfile } from '../../hooks/useProfile';
import { useToast } from '../common/toastContext';

const DEFAULT_AVATAR = 'https://i.pravatar.cc/160?img=13';

interface ProfileModalProps {
  isOpen: boolean;
  onClose: () => void;
}

export function ProfileModal({ isOpen, onClose }: ProfileModalProps) {
  const [isPasswordOpen, setIsPasswordOpen] = useState(false);
  const { showToast } = useToast();
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

  useEffect(() => {
    if (!isOpen) return;

    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape' && !isSaving && !isPasswordSaving) onClose();
    };

    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [isOpen, isPasswordSaving, isSaving, onClose]);

  if (!isOpen) return null;

  const handleClose = () => {
    if (isSaving || isPasswordSaving) return;
    onClose();
  };

  return (
    <>
      <div
        className="modal-overlay fixed inset-0 z-50 flex items-center justify-center"
        role="presentation"
        onMouseDown={(event) => {
          if (event.target === event.currentTarget) handleClose();
        }}
      >
        <section className="modal-card profile-modal-card" role="dialog" aria-modal="true" aria-labelledby="profileModalTitle">
          <div className="profile-modal-head">
            <div>
              <h2 id="profileModalTitle">Hồ sơ cá nhân</h2>
            </div>
            <button type="button" className="icon-btn" onClick={handleClose} aria-label="Đóng">
              <X />
            </button>
          </div>

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
          ) : (
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
            />
          )}
        </section>
      </div>

      <PasswordModal
        isOpen={isPasswordOpen}
        onClose={() => {
          if (!isPasswordSaving) setIsPasswordOpen(false);
        }}
        onMessage={showMessage}
        onChangePassword={changePassword}
        isSaving={isPasswordSaving}
      />
    </>
  );
}
