import { useEffect, useId, useState } from 'react';
import { createPortal } from 'react-dom';
import { AlertTriangle, CircleCheck, Trash2, X } from 'lucide-react';
import { StyledSelect } from '../common/StyledSelect';
import { ROLE_LABELS, getPermissionOverrideSummary } from '../../config/permissions';
import type { AppRole, PermissionOverrideFlags, PermissionOverrideKey } from '../../config/permissions';
import type { CreateMemberFormData, ManagedUserProfile, UserProfileFormData } from '../../types/userManagement';
import { useDocumentScrollLock } from '../common/useDocumentScrollLock';

type UserModalDraft = UserProfileFormData | CreateMemberFormData;

interface UserModalProps {
  isOpen: boolean;
  mode: 'create' | 'edit';
  draft: UserModalDraft | null;
  selectedUser?: ManagedUserProfile | null;
  isSaving: boolean;
  isDeleting?: boolean;
  errorMessage?: string | null;
  onClose: () => void;
  onChange: (patch: Partial<CreateMemberFormData>) => void;
  onSave: () => void;
  onDelete?: () => void;
}

const ROLE_OPTIONS: AppRole[] = ['admin', 'creative_manager', 'content_creator', 'editor'];

function isCreateDraft(mode: UserModalProps['mode'], draft: UserModalDraft): draft is CreateMemberFormData {
  return mode === 'create' && 'password' in draft;
}

function UserModalSection({
  title,
  children,
}: {
  title: string;
  children: React.ReactNode;
}) {
  return (
    <section className="member-modal-section rounded-[18px] border" style={{ borderColor: 'var(--border)', background: 'var(--bg2)' }}>
      <h3 className="member-modal-section-title text-ink">{title}</h3>
      <div className="member-form-grid grid grid-cols-1 sm:grid-cols-2">
        {children}
      </div>
    </section>
  );
}

function updateFlag(flags: PermissionOverrideFlags, key: PermissionOverrideKey, value: boolean): PermissionOverrideFlags {
  return {
    ...flags,
    [key]: value,
  };
}

function PermissionCheck({
  label,
  checked,
  disabled,
  onChange,
}: {
  label: string;
  checked: boolean;
  disabled?: boolean;
  onChange: (checked: boolean) => void;
}) {
  return (
    <label className="permission-check">
      <input
        type="checkbox"
        checked={checked}
        disabled={disabled}
        onChange={(event) => onChange(event.target.checked)}
      />
      <span>{label}</span>
    </label>
  );
}

export function UserModal({
  isOpen,
  mode,
  draft,
  selectedUser = null,
  isSaving,
  isDeleting = false,
  errorMessage = null,
  onClose,
  onChange,
  onSave,
  onDelete,
}: UserModalProps) {
  const titleId = useId();
  const [deleteOpen, setDeleteOpen] = useState(false);
  const [deleteEmail, setDeleteEmail] = useState('');

  useDocumentScrollLock(isOpen);

  useEffect(() => {
    setDeleteOpen(false);
    setDeleteEmail('');
  }, [selectedUser?.id, isOpen]);

  useEffect(() => {
    if (!isOpen) return;

    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape' && !isSaving && !isDeleting) {
        onClose();
      }
    };

    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [isDeleting, isOpen, isSaving, onClose]);

  if (!isOpen || !draft) return null;

  const isCreate = isCreateDraft(mode, draft);
  const title = mode === 'create' ? 'Thêm thành viên' : 'Sửa thành viên';
  const canDelete = mode === 'edit' && Boolean(selectedUser) && Boolean(onDelete);
  const permissionMode = draft.permissionMode;
  const permissionFlags = draft.permissionFlags ?? {};
  const usersManageLocked = true;
  const usersManageChecked = draft.role === 'admin';
  const deleteConfirmed = selectedUser
    ? deleteEmail.trim().toLowerCase() === selectedUser.email.trim().toLowerCase()
    : false;

  return createPortal(
    <div
      className="member-modal-overlay modal-overlay fixed inset-0 z-50 flex items-center justify-center"
      role="presentation"
      onMouseDown={(event) => {
        if (event.target === event.currentTarget && !isSaving && !isDeleting) onClose();
      }}
    >
      <section className="modal-card member-modal-card" role="dialog" aria-modal="true" aria-labelledby={titleId}>
        <div className="member-modal-head">
          <div>
            <h2 id={titleId} className="member-modal-title">{title}</h2>
          </div>
          <button type="button" className="icon-btn" onClick={onClose} disabled={isSaving || isDeleting} aria-label="Đóng">
            <X />
          </button>
        </div>

        <div className="member-modal-body">
          <div className="member-modal-stack">
          <UserModalSection title="Tài khoản">
            <div>
              <label className="flabel" htmlFor="memberFullName">Họ tên</label>
              <input
                id="memberFullName"
                className="field"
                value={draft.fullName}
                disabled={isSaving}
                onChange={(event) => onChange({ fullName: event.target.value })}
                placeholder="Nhập họ tên"
              />
            </div>

            <div>
              <label className="flabel" htmlFor="memberDisplayName">Tên hiển thị</label>
              <input
                id="memberDisplayName"
                className="field"
                value={draft.displayName}
                disabled={isSaving}
                onChange={(event) => onChange({ displayName: event.target.value })}
                placeholder="VD: Đạt Đoàn"
              />
            </div>

            <div>
              <label className="flabel" htmlFor="memberEmail">Email</label>
              <input
                id="memberEmail"
                className="field"
                type="email"
                value={draft.email}
                disabled={isSaving}
                onChange={(event) => onChange({ email: event.target.value })}
                placeholder="email@company.com"
              />
            </div>

            {isCreate ? (
              <div>
                <label className="flabel" htmlFor="memberPassword">Mật khẩu tạm</label>
                <input
                  id="memberPassword"
                  className="field"
                  type="password"
                  value={draft.password}
                  disabled={isSaving}
                  onChange={(event) => onChange({ password: event.target.value })}
                  placeholder="Tối thiểu 8 ký tự"
                />
              </div>
            ) : (
              <div>
                <label className="flabel" htmlFor="memberPhone">Số điện thoại</label>
                <input
                  id="memberPhone"
                  className="field"
                  value={draft.phone}
                  disabled={isSaving}
                  onChange={(event) => onChange({ phone: event.target.value })}
                  placeholder="VD: 0901 234 567"
                />
              </div>
            )}
          </UserModalSection>

          <UserModalSection title="Vai trò & bộ phận">
            <div>
              <label className="flabel" htmlFor="memberRole">Vai trò</label>
              <StyledSelect
                id="memberRole"
                value={draft.role}
                disabled={isSaving}
                onChange={(event) => onChange({ role: event.target.value as AppRole })}
              >
                {ROLE_OPTIONS.map((role) => (
                  <option key={role} value={role}>{ROLE_LABELS[role]}</option>
                ))}
              </StyledSelect>
            </div>

            <div>
              <label className="flabel" htmlFor="memberDepartment">Bộ phận</label>
              <input
                id="memberDepartment"
                className="field"
                value={draft.department}
                disabled={isSaving}
                onChange={(event) => onChange({ department: event.target.value })}
                placeholder="Team Marketing"
              />
            </div>

            <label className="user-check-row sm:col-span-2">
              <input
                type="checkbox"
                checked={draft.isActive}
                disabled={isSaving}
                onChange={(event) => onChange({ isActive: event.target.checked })}
              />
              <span>
                <strong>Đang hoạt động</strong>
              </span>
            </label>
          </UserModalSection>

          <UserModalSection title="Thành viên editor">
            <label className="user-check-row sm:col-span-2">
              <input
                type="checkbox"
                checked={draft.isEditorMember}
                disabled={isSaving}
                onChange={(event) => onChange({ isEditorMember: event.target.checked })}
              />
              <span>
                <strong>Tham gia team editor</strong>
              </span>
            </label>

            {draft.isEditorMember ? (
              <div className="sm:col-span-2">
                <label className="flabel" htmlFor="memberEditorCode">Editor Code</label>
                <input
                  id="memberEditorCode"
                  className="field"
                  value={draft.editorCode}
                  disabled={isSaving}
                  onChange={(event) => onChange({ editorCode: event.target.value })}
                  placeholder="dat, hai, minh..."
                />
              </div>
            ) : null}
          </UserModalSection>

          <UserModalSection title="Quyền sử dụng">
            <div className="sm:col-span-2">
              <StyledSelect
                value={permissionMode}
                disabled={isSaving}
                onChange={(event) => onChange({ permissionMode: event.target.value as UserModalDraft['permissionMode'] })}
              >
                <option value="role_default">Theo vai trò</option>
                <option value="view_only">Chỉ xem</option>
                <option value="custom">Tùy chỉnh</option>
              </StyledSelect>
              <p className="mt-2 text-[12px] font-semibold text-sub">
                {getPermissionOverrideSummary(permissionMode)} · Mặc định quyền được xác định theo vai trò.
              </p>
            </div>

            {permissionMode === 'custom' ? (
              <div className="permission-grid sm:col-span-2">
                <div className="permission-group">
                  <strong>Lịch quay</strong>
                  <PermissionCheck
                    label="Xem"
                    checked={permissionFlags.calendar_view === true}
                    onChange={(checked) => onChange({ permissionFlags: updateFlag(permissionFlags, 'calendar_view', checked) })}
                    disabled={isSaving}
                  />
                  <PermissionCheck
                    label="Tạo và chỉnh sửa"
                    checked={permissionFlags.calendar_edit === true}
                    onChange={(checked) => onChange({ permissionFlags: updateFlag(permissionFlags, 'calendar_edit', checked) })}
                    disabled={isSaving}
                  />
                </div>

                <div className="permission-group">
                  <strong>Video tháng</strong>
                  <PermissionCheck
                    label="Xem"
                    checked={permissionFlags.tasks_view === true}
                    onChange={(checked) => onChange({ permissionFlags: updateFlag(permissionFlags, 'tasks_view', checked) })}
                    disabled={isSaving}
                  />
                  <PermissionCheck
                    label="Tạo và chỉnh sửa"
                    checked={permissionFlags.tasks_edit === true}
                    onChange={(checked) => onChange({ permissionFlags: updateFlag(permissionFlags, 'tasks_edit', checked) })}
                    disabled={isSaving}
                  />
                </div>

                <div className="permission-group">
                  <strong>Content Plan</strong>
                  <PermissionCheck
                    label="Xem"
                    checked={permissionFlags.content_plan_view === true}
                    onChange={(checked) => onChange({ permissionFlags: updateFlag(permissionFlags, 'content_plan_view', checked) })}
                    disabled={isSaving}
                  />
                  <PermissionCheck
                    label="Chỉnh nội dung"
                    checked={permissionFlags.content_plan_edit_content === true}
                    onChange={(checked) => onChange({ permissionFlags: updateFlag(permissionFlags, 'content_plan_edit_content', checked) })}
                    disabled={isSaving}
                  />
                  <PermissionCheck
                    label="Phân công editor"
                    checked={permissionFlags.content_plan_assign_editor === true}
                    onChange={(checked) => onChange({ permissionFlags: updateFlag(permissionFlags, 'content_plan_assign_editor', checked) })}
                    disabled={isSaving}
                  />
                </div>

                <div className="permission-group">
                  <strong>Khác</strong>
                  <PermissionCheck
                    label="Xem Dashboard"
                    checked={permissionFlags.dashboard_view === true}
                    onChange={(checked) => onChange({ permissionFlags: updateFlag(permissionFlags, 'dashboard_view', checked) })}
                    disabled={isSaving}
                  />
                  <PermissionCheck
                    label="Sửa hồ sơ cá nhân"
                    checked={permissionFlags.profile_edit_self !== false}
                    onChange={(checked) => onChange({ permissionFlags: updateFlag(permissionFlags, 'profile_edit_self', checked) })}
                    disabled={isSaving}
                  />
                  <PermissionCheck
                    label="Quản lý thành viên"
                    checked={usersManageChecked}
                    onChange={() => undefined}
                    disabled={isSaving || usersManageLocked}
                  />
                </div>
              </div>
            ) : null}
          </UserModalSection>

          {mode === 'edit' ? (
            <details className="member-modal-advanced rounded-[16px] border text-[12.5px]" style={{ borderColor: 'var(--border)', background: 'var(--bg2)' }}>
              <summary className="cursor-pointer font-bold text-sub">Nâng cao</summary>
              <div className="mt-3">
                <label className="flabel" htmlFor="memberCrewKey">Crew Key cũ</label>
                <input
                  id="memberCrewKey"
                  className="field"
                  value={draft.crewKey}
                  disabled={isSaving}
                  onChange={(event) => onChange({ crewKey: event.target.value })}
                  placeholder="ĐẠT, HẢI, MINH..."
                />
              </div>
            </details>
          ) : null}

          {canDelete ? (
            <section className="member-modal-section rounded-[18px] border" style={{ borderColor: 'color-mix(in srgb,var(--danger) 24%,var(--border))', background: 'color-mix(in srgb,var(--danger) 6%,var(--bg2))' }}>
              {!deleteOpen ? (
                <div className="flex flex-wrap items-center justify-between gap-3">
                  <div className="min-w-0">
                    <h3 className="text-[13px] font-extrabold text-ink">Xóa tài khoản</h3>
                    <p className="mt-1 text-[12.5px] font-semibold text-sub">Dành cho tài khoản thử nghiệm không còn dùng.</p>
                  </div>
                  <button
                    type="button"
                    className="btn-ghost text-danger"
                    onClick={() => setDeleteOpen(true)}
                    disabled={isSaving || isDeleting}
                  >
                    <Trash2 /> Xóa tài khoản
                  </button>
                </div>
              ) : (
                <div className="space-y-3">
                  <div className="flex items-start gap-3">
                    <span className="confirm-icon confirm-icon--danger">
                      <AlertTriangle />
                    </span>
                    <div className="min-w-0">
                      <h3 className="text-[15px] font-extrabold text-ink">Xóa vĩnh viễn tài khoản?</h3>
                      <p className="mt-1 text-[12.5px] font-semibold leading-5 text-sub">
                        Tài khoản và dữ liệu thử nghiệm liên quan sẽ bị xóa. Thao tác này không thể hoàn tác.
                      </p>
                    </div>
                  </div>

                  <div>
                    <label className="flabel" htmlFor="memberDeleteEmail">Nhập email để xác nhận</label>
                    <input
                      id="memberDeleteEmail"
                      className="field"
                      value={deleteEmail}
                      disabled={isSaving || isDeleting}
                      onChange={(event) => setDeleteEmail(event.target.value)}
                      placeholder={selectedUser?.email}
                    />
                  </div>

                  <div className="flex flex-wrap justify-end gap-2">
                    <button
                      type="button"
                      className="btn-ghost"
                      onClick={() => {
                        setDeleteOpen(false);
                        setDeleteEmail('');
                      }}
                      disabled={isDeleting}
                    >
                      Hủy
                    </button>
                    <button
                      type="button"
                      className="btn btn-danger"
                      onClick={onDelete}
                      disabled={!deleteConfirmed || isSaving || isDeleting}
                    >
                      <Trash2 /> {isDeleting ? 'Đang xóa...' : 'Xóa vĩnh viễn'}
                    </button>
                  </div>
                </div>
              )}
            </section>
          ) : null}
          </div>
        </div>

        <div className="member-modal-footer">
          {errorMessage ? (
            <div className="profile-inline-error member-modal-error">{errorMessage}</div>
          ) : null}

          <div className="member-modal-actions">
            <button type="button" className="btn-ghost" onClick={onClose} disabled={isSaving || isDeleting}>
              Hủy
            </button>
            <button type="button" className="btn" onClick={onSave} disabled={isSaving || isDeleting}>
              <CircleCheck /> {isSaving ? 'Đang lưu...' : 'Lưu'}
            </button>
          </div>
        </div>
      </section>
    </div>,
    document.body
  );
}
