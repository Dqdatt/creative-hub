import { useCallback, useEffect, useState } from 'react';
import { useAuth } from '../context/authContext';
import {
  createManagedUser,
  deleteManagedUserAccount,
  fetchUserProfiles,
  updateManagedUserProfile,
} from '../services/userManagementService';
import type { CreateMemberFormData, ManagedUserProfile, UserProfileFormData } from '../types/userManagement';

function getErrorMessage(error: unknown, fallback: string) {
  return error instanceof Error ? error.message : fallback;
}

export function useUsers() {
  const { user } = useAuth();
  const [users, setUsers] = useState<ManagedUserProfile[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [isSaving, setIsSaving] = useState(false);
  const [isDeleting, setIsDeleting] = useState(false);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [saveError, setSaveError] = useState<string | null>(null);
  const [message, setMessage] = useState<string | null>(null);

  const loadUsers = useCallback(async () => {
    setIsLoading(true);
    setLoadError(null);

    try {
      const nextUsers = await fetchUserProfiles();
      setUsers(nextUsers);
    } catch (error) {
      setLoadError(getErrorMessage(error, 'Không thể tải danh sách thành viên. Vui lòng thử lại.'));
      setUsers([]);
    } finally {
      setIsLoading(false);
    }
  }, []);

  useEffect(() => {
    void loadUsers();
  }, [loadUsers]);

  const updateUser = useCallback(async (targetUser: ManagedUserProfile, data: UserProfileFormData) => {
    setIsSaving(true);
    setSaveError(null);
    setMessage(null);

    try {
      const emailChanged = data.email.trim().toLowerCase() !== targetUser.email.trim().toLowerCase();
      await updateManagedUserProfile(targetUser.id, data, user?.id, targetUser);
      await loadUsers();
      setMessage(emailChanged ? 'Đã cập nhật email đăng nhập.' : 'Đã lưu thông tin thành viên.');
      return true;
    } catch (error) {
      setSaveError(getErrorMessage(error, 'Không thể lưu thông tin thành viên. Vui lòng thử lại.'));
      return false;
    } finally {
      setIsSaving(false);
    }
  }, [loadUsers, user?.id]);

  const deleteUser = useCallback(async (targetUser: ManagedUserProfile) => {
    setIsDeleting(true);
    setSaveError(null);
    setMessage(null);

    try {
      await deleteManagedUserAccount(targetUser);
      await loadUsers();
      setMessage('Đã xóa tài khoản.');
      return true;
    } catch (error) {
      setSaveError(getErrorMessage(error, 'Không thể xóa tài khoản. Vui lòng thử lại.'));
      return false;
    } finally {
      setIsDeleting(false);
    }
  }, [loadUsers]);

  const createUser = useCallback(async (data: CreateMemberFormData) => {
    setIsSaving(true);
    setSaveError(null);
    setMessage(null);

    try {
      await createManagedUser(data, user?.id);
      await loadUsers();
      setMessage('Đã tạo thành viên mới.');
      return true;
    } catch (error) {
      setSaveError(getErrorMessage(error, 'Không thể tạo thành viên. Vui lòng thử lại.'));
      return false;
    } finally {
      setIsSaving(false);
    }
  }, [loadUsers, user?.id]);

  const clearSaveError = useCallback(() => {
    setSaveError(null);
  }, []);

  const clearMessage = useCallback(() => {
    setMessage(null);
  }, []);

  return {
    users,
    isLoading,
    isSaving,
    isDeleting,
    loadError,
    saveError,
    message,
    refetch: loadUsers,
    updateUser,
    createUser,
    deleteUser,
    clearSaveError,
    clearMessage,
  };
}
