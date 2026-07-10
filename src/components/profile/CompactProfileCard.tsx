import { CircleCheck, ImageUp, KeyRound, RotateCcw, Trash2 } from 'lucide-react';
import type { ChangeEvent } from 'react';
import type { EmployeeProfile } from '../../types/profile';
import { Avatar } from '../common/Avatar';

interface CompactProfileCardProps {
  draft: EmployeeProfile;
  defaultAvatar: string;
  onChange: (patch: Partial<EmployeeProfile>) => void;
  onSave: () => void;
  onReset: () => void;
  onAvatarError: (text: string) => void;
  onAvatarPicked: (file: File, previewUrl: string) => void;
  onAvatarRemoved: () => void;
  onOpenPassword: () => void;
  isSaving?: boolean;
}

const MAX_AVATAR_SIZE = 2 * 1024 * 1024;

export function CompactProfileCard({
  draft,
  defaultAvatar,
  onChange,
  onSave,
  onReset,
  onAvatarError,
  onAvatarPicked,
  onAvatarRemoved,
  onOpenPassword,
  isSaving = false,
}: CompactProfileCardProps) {
  const handleAvatarChange = (event: ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    event.target.value = '';
    if (!file) return;

    if (!file.type.startsWith('image/')) {
      onAvatarError('Vui lòng chọn tệp hình ảnh.');
      return;
    }
    if (file.size > MAX_AVATAR_SIZE) {
      onAvatarError('Ảnh đại diện tối đa 2MB.');
      return;
    }

    const reader = new FileReader();
    reader.onload = () => {
      if (typeof reader.result !== 'string') {
        onAvatarError('Không thể đọc ảnh đã chọn.');
        return;
      }
      onChange({ avatarUrl: reader.result });
      onAvatarPicked(file, reader.result);
    };
    reader.onerror = () => onAvatarError('Không thể đọc ảnh đã chọn.');
    reader.readAsDataURL(file);
  };

  return (
    <section className="card profile-card-compact">
      <div className="profile-card-grid">
        <aside className="profile-summary-panel">
          <Avatar
            src={draft.avatarUrl}
            name={draft.displayName || draft.fullName}
            size="xl"
            shape="rounded"
            className="profile-avatar-xl"
            alt={draft.displayName || draft.fullName}
          />

          <div className="min-w-0">
            <h2 className="profile-summary-name">{draft.displayName || draft.fullName}</h2>
            <p className="profile-summary-email">{draft.email}</p>
          </div>

          <div className="profile-summary-tags">
            <span className="mini-chip">{draft.role}</span>
            <span className="mini-chip">{draft.department || 'Chưa có bộ phận'}</span>
          </div>

          <div className="profile-avatar-actions">
            <input
              id="avatarFileInput"
              className="sr-only"
              type="file"
              accept="image/*"
              disabled={isSaving}
              onChange={handleAvatarChange}
            />
            <label className="btn-ghost btn-sm cursor-pointer" htmlFor="avatarFileInput">
              <ImageUp /> Đổi ảnh
            </label>
            <button
              id="removeAvatarBtn"
              type="button"
              className="profile-text-btn"
              disabled={isSaving}
              onClick={() => {
                onChange({ avatarUrl: defaultAvatar });
                onAvatarRemoved();
              }}
            >
              <Trash2 /> Xóa ảnh
            </button>
          </div>

          <button id="openPasswordModalBtn" type="button" className="btn-ghost profile-password-link" onClick={onOpenPassword} disabled={isSaving}>
            <KeyRound /> Đổi mật khẩu
          </button>
        </aside>

        <form
          className="profile-form-compact"
          onSubmit={(event) => {
            event.preventDefault();
            onSave();
          }}
        >
          <div className="profile-form-head">
            <div>
              <h2>Thông tin cá nhân</h2>
            </div>
          </div>

          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
            <div>
              <label className="flabel" htmlFor="profileFullName">Họ tên</label>
              <input
                id="profileFullName"
                className="field"
                value={draft.fullName}
                disabled={isSaving}
                onChange={(event) => onChange({ fullName: event.target.value })}
                placeholder="Nhập họ tên"
              />
            </div>
            <div>
              <label className="flabel" htmlFor="profileDisplayName">Tên hiển thị</label>
              <input
                id="profileDisplayName"
                className="field"
                value={draft.displayName}
                disabled={isSaving}
                onChange={(event) => onChange({ displayName: event.target.value })}
                placeholder="Nhập tên hiển thị"
              />
            </div>
            <div>
              <label className="flabel" htmlFor="profileEmail">Email</label>
              <input id="profileEmail" className="field" value={draft.email} readOnly aria-readonly="true" />
            </div>
            <div>
              <label className="flabel" htmlFor="profilePhone">Số điện thoại</label>
              <input
                id="profilePhone"
                className="field"
                value={draft.phone}
                disabled={isSaving}
                onChange={(event) => onChange({ phone: event.target.value })}
                placeholder="VD: 0901 234 567"
              />
            </div>
            <div>
              <label className="flabel" htmlFor="profileRole">Vai trò</label>
              <input id="profileRole" className="field" value={draft.role} readOnly aria-readonly="true" />
            </div>
            <div>
              <label className="flabel" htmlFor="profileDepartment">Bộ phận</label>
              <input
                id="profileDepartment"
                className="field"
                value={draft.department}
                disabled={isSaving}
                onChange={(event) => onChange({ department: event.target.value })}
                placeholder="Nhập bộ phận"
              />
            </div>
          </div>

          <div className="profile-actions">
            <button type="button" className="btn-ghost" onClick={onReset} disabled={isSaving}>
              <RotateCcw /> Hoàn tác
            </button>
            <button type="submit" className="btn" disabled={isSaving}>
              <CircleCheck /> {isSaving ? 'Đang lưu...' : 'Lưu thay đổi'}
            </button>
          </div>
        </form>
      </div>
    </section>
  );
}
