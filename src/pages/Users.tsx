import { useEffect, useMemo, useState } from 'react';
import { EmptyState } from '../components/common/EmptyState';
import { ErrorState } from '../components/common/ErrorState';
import { LoadingState } from '../components/common/LoadingState';
import { UserFilters } from '../components/users/UserFilters';
import { UserModal } from '../components/users/UserModal';
import { UserTable } from '../components/users/UserTable';
import type { AppRole } from '../config/permissions';
import { useUsers } from '../hooks/useUsers';
import type { CreateMemberFormData, ManagedUserProfile, UserProfileFormData } from '../types/userManagement';
import { useToast } from '../components/common/toastContext';
import { useConfirmDialog } from '../components/common/confirmDialogContext';

const DEFAULT_MEMBER_DRAFT: CreateMemberFormData = {
  fullName: '',
  displayName: '',
  email: '',
  password: '',
  phone: '',
  role: 'editor',
  department: 'Team Marketing',
  editorCode: '',
  crewKey: '',
  isEditorMember: false,
  isActive: true,
};

function toFormData(user: ManagedUserProfile): UserProfileFormData {
  return {
    fullName: user.fullName,
    displayName: user.displayName,
    email: user.email,
    phone: user.phone,
    role: user.role,
    department: user.department,
    editorCode: user.editorCode,
    crewKey: user.crewKey,
    isEditorMember: user.isEditorMember,
    isActive: user.isActive,
  };
}

function validateDraft(draft: UserProfileFormData | CreateMemberFormData, mode: 'create' | 'edit') {
  if (!draft.fullName.trim()) return 'Vui lòng nhập họ tên.';
  if (!draft.displayName.trim()) return 'Vui lòng nhập tên hiển thị.';
  if (!draft.email.trim()) return 'Vui lòng nhập email.';
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(draft.email.trim())) return 'Email chưa đúng định dạng.';
  if (draft.phone && !/^[0-9+\s().-]{8,18}$/.test(draft.phone.trim())) return 'Số điện thoại chưa đúng định dạng.';
  if (mode === 'create' && 'password' in draft && draft.password.length < 8) {
    return 'Mật khẩu tạm cần tối thiểu 8 ký tự.';
  }
  if (draft.isEditorMember && !draft.editorCode.trim()) {
    return 'Vui lòng nhập Editor Code cho thành viên team editor.';
  }
  return '';
}

export default function Users() {
  const { showToast } = useToast();
  const { requestConfirm } = useConfirmDialog();
  const {
    users,
    isLoading,
    isSaving,
    isDeleting,
    loadError,
    saveError,
    message,
    refetch,
    updateUser,
    createUser,
    deleteUser,
    clearSaveError,
    clearMessage,
  } = useUsers();
  const [search, setSearch] = useState('');
  const [roleFilter, setRoleFilter] = useState<AppRole | 'all'>('all');
  const [statusFilter, setStatusFilter] = useState<'all' | 'active' | 'inactive'>('all');
  const [modalMode, setModalMode] = useState<'create' | 'edit'>('edit');
  const [selectedUser, setSelectedUser] = useState<ManagedUserProfile | null>(null);
  const [draft, setDraft] = useState<UserProfileFormData | CreateMemberFormData | null>(null);
  const [formError, setFormError] = useState<string | null>(null);

  useEffect(() => {
    if (!message) return;
    showToast({ type: 'success', message });
  }, [message, showToast]);

  const filteredUsers = useMemo(() => {
    const searchValue = search.trim().toLowerCase();

    return users
      .filter((user) => {
        if (roleFilter !== 'all' && user.role !== roleFilter) return false;
        if (statusFilter === 'active' && !user.isActive) return false;
        if (statusFilter === 'inactive' && user.isActive) return false;
        if (!searchValue) return true;
        return [
          user.fullName,
          user.displayName,
          user.email,
          user.department,
          user.editorCode,
          user.crewKey,
        ].some((value) => value.toLowerCase().includes(searchValue));
      })
      .sort((a, b) => a.fullName.localeCompare(b.fullName, 'vi'));
  }, [roleFilter, search, statusFilter, users]);

  const openCreateModal = () => {
    clearSaveError();
    clearMessage();
    setModalMode('create');
    setSelectedUser(null);
    setDraft(DEFAULT_MEMBER_DRAFT);
    setFormError(null);
  };

  const openEditModal = (user: ManagedUserProfile) => {
    clearSaveError();
    clearMessage();
    setModalMode('edit');
    setSelectedUser(user);
    setDraft(toFormData(user));
    setFormError(null);
  };

  const closeModal = () => {
    if (isSaving || isDeleting) return;
    setSelectedUser(null);
    setDraft(null);
    setFormError(null);
    clearSaveError();
  };

  const updateDraft = (patch: Partial<CreateMemberFormData>) => {
    setDraft((current) => {
      if (!current) return current;
      const nextDraft = { ...current, ...patch };
      if (patch.isEditorMember === false) {
        nextDraft.editorCode = '';
      }
      return nextDraft;
    });
    setFormError(null);
    clearSaveError();
  };

  const handleSave = async () => {
    if (!draft) return;
    setFormError(null);

    const validationError = validateDraft(draft, modalMode);
    if (validationError) {
      setFormError(validationError);
      return;
    }

    if (modalMode === 'edit' && selectedUser) {
      const emailChanged = draft.email.trim().toLowerCase() !== selectedUser.email.trim().toLowerCase();
      if (emailChanged) {
        const confirmed = await requestConfirm({
          title: 'Đổi email đăng nhập?',
          description: 'Thành viên sẽ sử dụng email mới để đăng nhập vào CreativeHub.',
          confirmLabel: 'Đổi email',
        });

        if (!confirmed) return;
      }
    }

    const saved = modalMode === 'create'
      ? await createUser(draft as CreateMemberFormData)
      : selectedUser
        ? await updateUser(selectedUser, draft)
        : false;

    if (saved) {
      closeModal();
    }
  };

  const handleDeleteUser = async () => {
    if (!selectedUser || modalMode !== 'edit') return;
    const deleted = await deleteUser(selectedUser);

    if (deleted) {
      closeModal();
    }
  };

  return (
    <div className="space-y-4" data-view="users">
      <UserFilters
        search={search}
        roleFilter={roleFilter}
        statusFilter={statusFilter}
        totalCount={users.length}
        filteredCount={filteredUsers.length}
        onSearchChange={setSearch}
        onRoleChange={setRoleFilter}
        onStatusChange={setStatusFilter}
        onCreateUser={openCreateModal}
      />

      {loadError ? (
        <ErrorState title="Không thể tải thành viên" message={loadError} onRetry={() => void refetch()} />
      ) : null}

      {!isLoading && !loadError && users.length === 0 ? (
        <EmptyState
          title="Chưa có thành viên"
          message="Tạo tài khoản đầu tiên cho team."
          actionLabel="Thêm thành viên"
          onAction={openCreateModal}
        />
      ) : null}

      <div className="card p-3 overflow-x-auto">
        {isLoading ? (
          <LoadingState
            variant="table"
            message="Đang tải danh sách thành viên..."
            colSpan={7}
            minWidthClass="min-w-[1080px]"
            rows={7}
          />
        ) : (
          <UserTable users={filteredUsers} onEditUser={openEditModal} />
        )}
      </div>

      <UserModal
        isOpen={Boolean(draft)}
        mode={modalMode}
        draft={draft}
        isSaving={isSaving}
        isDeleting={isDeleting}
        errorMessage={formError ?? saveError}
        onClose={closeModal}
        onChange={updateDraft}
        onSave={() => void handleSave()}
        selectedUser={selectedUser}
        onDelete={() => void handleDeleteUser()}
      />
    </div>
  );
}
