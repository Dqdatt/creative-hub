import { Eye, EyeOff, ShieldCheck, X } from 'lucide-react';
import { useEffect, useState } from 'react';
import type { FormEvent } from 'react';
import type { PasswordField, ProfileMessage } from '../../types/profile';

interface PasswordModalProps {
  isOpen: boolean;
  onClose: () => void;
  onMessage: (message: ProfileMessage) => void;
  onChangePassword: (currentPassword: string, newPassword: string, confirmPassword: string) => Promise<{ ok: boolean; error: string }>;
  isSaving?: boolean;
}

export function PasswordModal({ isOpen, onClose, onMessage, onChangePassword, isSaving = false }: PasswordModalProps) {
  const [currentPassword, setCurrentPassword] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [visible, setVisible] = useState<Record<PasswordField, boolean>>({
    current: false,
    next: false,
    confirm: false,
  });
  const [localError, setLocalError] = useState('');

  useEffect(() => {
    if (!isOpen) return;

    setCurrentPassword('');
    setNewPassword('');
    setConfirmPassword('');
    setLocalError('');
    setVisible({ current: false, next: false, confirm: false });
  }, [isOpen]);

  useEffect(() => {
    if (!isOpen) return;
    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape') onClose();
    };
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [isOpen, onClose]);

  if (!isOpen) return null;

  const validate = () => {
    if (!currentPassword || !newPassword || !confirmPassword) {
      return 'Vui lòng nhập đầy đủ thông tin mật khẩu.';
    }
    if (newPassword.length < 8) {
      return 'Mật khẩu mới cần tối thiểu 8 ký tự.';
    }
    if (newPassword === currentPassword) {
      return 'Mật khẩu mới cần khác mật khẩu hiện tại.';
    }
    if (newPassword !== confirmPassword) {
      return 'Xác nhận mật khẩu mới chưa khớp.';
    }
    return '';
  };

  const toggleVisible = (field: PasswordField) => {
    setVisible((prev) => ({ ...prev, [field]: !prev[field] }));
  };

  const handleSubmit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    const error = validate();
    if (error) {
      setLocalError(error);
      onMessage({ type: 'error', text: error });
      return;
    }

    setLocalError('');
    const result = await onChangePassword(currentPassword, newPassword, confirmPassword);
    if (!result.ok) {
      setLocalError(result.error);
      return;
    }
    onMessage({ type: 'success', text: 'Đã cập nhật mật khẩu.' });
    onClose();
  };

  const renderPasswordInput = (
    id: string,
    label: string,
    value: string,
    field: PasswordField,
    onChange: (value: string) => void,
  ) => (
    <div>
      <label className="flabel" htmlFor={id}>{label}</label>
      <div className="relative">
        <input
          id={id}
          className="field pr-12"
          type={visible[field] ? 'text' : 'password'}
          value={value}
          disabled={isSaving}
          onChange={(event) => {
            setLocalError('');
            onChange(event.target.value);
          }}
          autoComplete="new-password"
        />
        <button
          type="button"
          className="profile-eye-btn"
          disabled={isSaving}
          onClick={() => toggleVisible(field)}
          aria-label={visible[field] ? 'Ẩn mật khẩu' : 'Hiện mật khẩu'}
        >
          {visible[field] ? <EyeOff /> : <Eye />}
        </button>
      </div>
    </div>
  );

  return (
    <div
      className="modal-overlay fixed inset-0 z-50 flex items-center justify-center p-4"
      role="presentation"
      onMouseDown={(event) => {
        if (event.target === event.currentTarget) onClose();
      }}
    >
      <section className="modal-card profile-password-modal" role="dialog" aria-modal="true" aria-labelledby="passwordModalTitle">
        <div className="profile-modal-head">
          <div>
            <h2 id="passwordModalTitle">Đổi mật khẩu</h2>
          </div>
          <button type="button" className="icon-btn" onClick={onClose} aria-label="Đóng">
            <X />
          </button>
        </div>

        <form className="space-y-4" onSubmit={handleSubmit}>
          {renderPasswordInput('currentPassword', 'Mật khẩu hiện tại', currentPassword, 'current', setCurrentPassword)}
          {renderPasswordInput('newPassword', 'Mật khẩu mới', newPassword, 'next', setNewPassword)}
          {renderPasswordInput('confirmPassword', 'Xác nhận mật khẩu mới', confirmPassword, 'confirm', setConfirmPassword)}

          {localError && (
            <div id="passwordError" className="profile-inline-error">
              {localError}
            </div>
          )}

          <div className="flex flex-wrap items-center justify-end gap-3 pt-1">
            <button type="button" className="btn-ghost" onClick={onClose} disabled={isSaving}>Hủy</button>
            <button id="savePasswordBtn" type="submit" className="btn" disabled={isSaving}>
              <ShieldCheck /> {isSaving ? 'Đang cập nhật...' : 'Cập nhật mật khẩu'}
            </button>
          </div>
        </form>
      </section>
    </div>
  );
}
