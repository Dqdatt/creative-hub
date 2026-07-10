import { useCallback, useEffect, useState } from 'react';
import type { User } from '@supabase/supabase-js';
import { ROLE_LABELS } from '../config/permissions';
import { useAuth } from '../context/authContext';
import {
  fetchProfile,
  updatePassword,
  updateProfile,
  uploadAvatar,
} from '../services/profileService';
import { logActivity } from '../services/activityLogService';
import type { EmployeeProfile, ProfileMessage } from '../types/profile';

const DEFAULT_DEPARTMENT = 'Team Marketing';

function readUserMeta(value: unknown) {
  return typeof value === 'string' ? value : '';
}

function getErrorMessage(error: unknown, fallback: string) {
  return error instanceof Error ? error.message : fallback;
}

function fallbackProfileFromAuth(
  user: User | null,
  authProfile: ReturnType<typeof useAuth>['profile'],
  roleLabel: string,
  defaultAvatar: string
): EmployeeProfile {
  if (!user) {
    return {
      fullName: 'Nhân sự',
      displayName: 'Nhân sự',
      email: '',
      phone: '',
      role: ROLE_LABELS.editor,
      department: DEFAULT_DEPARTMENT,
      avatarUrl: defaultAvatar,
    };
  }

  const fullName = authProfile?.fullName
    || readUserMeta(user.user_metadata.full_name)
    || readUserMeta(user.user_metadata.name)
    || user.email?.split('@')[0]
    || 'Nhân sự';
  const displayName = authProfile?.displayName
    || readUserMeta(user.user_metadata.display_name)
    || readUserMeta(user.user_metadata.name)
    || fullName;

  return {
    fullName,
    displayName,
    email: authProfile?.email || user.email || '',
    phone: readUserMeta(user.user_metadata.phone),
    role: roleLabel,
    department: authProfile?.department || readUserMeta(user.user_metadata.department) || DEFAULT_DEPARTMENT,
    avatarUrl: authProfile?.avatarUrl || readUserMeta(user.user_metadata.avatar_url) || defaultAvatar,
  };
}

function withDefaultAvatar(profile: EmployeeProfile, defaultAvatar: string): EmployeeProfile {
  return {
    ...profile,
    avatarUrl: profile.avatarUrl || defaultAvatar,
  };
}

function validateProfile(draft: EmployeeProfile) {
  if (!draft.fullName.trim()) return 'Vui lòng nhập họ tên.';
  if (!draft.displayName.trim()) return 'Vui lòng nhập tên hiển thị.';
  if (draft.phone && !/^[0-9+\s().-]{8,18}$/.test(draft.phone.trim())) {
    return 'Số điện thoại chưa đúng định dạng.';
  }
  return '';
}

function validatePassword(currentPassword: string, newPassword: string, confirmPassword: string) {
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
}

export function useProfile(defaultAvatar: string) {
  const { user, profile: authProfile, roleLabel, refreshProfile } = useAuth();
  const [profile, setProfile] = useState<EmployeeProfile>(() =>
    fallbackProfileFromAuth(user, authProfile, roleLabel, defaultAvatar)
  );
  const [draft, setDraft] = useState<EmployeeProfile>(() =>
    fallbackProfileFromAuth(user, authProfile, roleLabel, defaultAvatar)
  );
  const [avatarFile, setAvatarFile] = useState<File | null>(null);
  const [avatarRemoved, setAvatarRemoved] = useState(false);
  const [isLoading, setIsLoading] = useState(true);
  const [isSaving, setIsSaving] = useState(false);
  const [isPasswordSaving, setIsPasswordSaving] = useState(false);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [message, setMessage] = useState<ProfileMessage | null>(null);

  const loadProfile = useCallback(async () => {
    if (!user) {
      setIsLoading(false);
      setLoadError('Chưa có phiên đăng nhập.');
      return;
    }

    setIsLoading(true);
    setLoadError(null);

    try {
      const nextProfile = withDefaultAvatar(await fetchProfile(user), defaultAvatar);
      setProfile(nextProfile);
      setDraft(nextProfile);
      setAvatarFile(null);
      setAvatarRemoved(false);
    } catch (error) {
      const fallbackProfile = fallbackProfileFromAuth(user, authProfile, roleLabel, defaultAvatar);
      setProfile(fallbackProfile);
      setDraft(fallbackProfile);
      setLoadError(getErrorMessage(error, 'Không thể tải hồ sơ. Vui lòng thử lại.'));
    } finally {
      setIsLoading(false);
    }
  }, [authProfile, defaultAvatar, roleLabel, user]);

  useEffect(() => {
    void loadProfile();
  }, [loadProfile]);

  const updateDraft = useCallback((patch: Partial<EmployeeProfile>) => {
    setDraft((prev) => ({ ...prev, ...patch }));
    setMessage(null);
  }, []);

  const pickAvatar = useCallback((file: File, previewUrl: string) => {
    setAvatarFile(file);
    setAvatarRemoved(false);
    setDraft((prev) => ({ ...prev, avatarUrl: previewUrl }));
    setMessage({ type: 'success', text: 'Đã chọn ảnh mới. Bấm lưu thay đổi để áp dụng.' });
  }, []);

  const removeAvatar = useCallback(() => {
    setAvatarFile(null);
    setAvatarRemoved(true);
    setDraft((prev) => ({ ...prev, avatarUrl: defaultAvatar }));
    setMessage({ type: 'success', text: 'Đã xóa ảnh xem trước. Bấm lưu thay đổi để áp dụng.' });
  }, [defaultAvatar]);

  const resetDraft = useCallback(() => {
    setDraft(profile);
    setAvatarFile(null);
    setAvatarRemoved(false);
    setMessage({ type: 'success', text: 'Đã khôi phục thông tin về bản đã lưu gần nhất.' });
  }, [profile]);

  const saveProfile = useCallback(async () => {
    if (!user) return;

    const validationError = validateProfile(draft);
    if (validationError) {
      setMessage({ type: 'error', text: validationError });
      return;
    }

    setIsSaving(true);
    setMessage(null);

    try {
      let nextAvatarUrl: string | null | undefined;
      if (avatarFile) {
        nextAvatarUrl = await uploadAvatar(user.id, avatarFile);
      } else if (avatarRemoved) {
        nextAvatarUrl = null;
      }

      await updateProfile(user.id, {
        fullName: draft.fullName,
        displayName: draft.displayName,
        phone: draft.phone,
        department: draft.department,
        ...(nextAvatarUrl !== undefined ? { avatarUrl: nextAvatarUrl } : {}),
      });

      if (avatarFile) {
        void logActivity({
          actorId: user.id,
          entityType: 'profile',
          entityId: user.id,
          action: 'uploaded',
          title: 'Ảnh đại diện',
          description: 'Đã tải ảnh đại diện mới.',
          metadata: {
            file_name: avatarFile.name,
          },
        });
      } else if (avatarRemoved) {
        void logActivity({
          actorId: user.id,
          entityType: 'profile',
          entityId: user.id,
          action: 'updated',
          title: 'Ảnh đại diện',
          description: 'Đã xóa ảnh đại diện.',
          metadata: {
            avatar_removed: true,
          },
        });
      }

      await refreshProfile();
      const refreshedProfile = withDefaultAvatar(await fetchProfile(user), defaultAvatar);
      setProfile(refreshedProfile);
      setDraft(refreshedProfile);
      setAvatarFile(null);
      setAvatarRemoved(false);
      setMessage({ type: 'success', text: 'Đã lưu thay đổi hồ sơ.' });
    } catch (error) {
      setMessage({ type: 'error', text: getErrorMessage(error, 'Không thể lưu hồ sơ. Vui lòng thử lại.') });
    } finally {
      setIsSaving(false);
    }
  }, [avatarFile, avatarRemoved, defaultAvatar, draft, refreshProfile, user]);

  const changePassword = useCallback(async (
    currentPassword: string,
    newPassword: string,
    confirmPassword: string
  ) => {
    if (!user?.email) {
      const error = 'Không tìm thấy email tài khoản.';
      setMessage({ type: 'error', text: error });
      return { ok: false, error };
    }

    const validationError = validatePassword(currentPassword, newPassword, confirmPassword);
    if (validationError) {
      setMessage({ type: 'error', text: validationError });
      return { ok: false, error: validationError };
    }

    setIsPasswordSaving(true);
    setMessage(null);

    try {
      await updatePassword(user.email, currentPassword, newPassword);
      void logActivity({
        actorId: user.id,
        entityType: 'profile',
        entityId: user.id,
        action: 'password_changed',
        title: 'Mật khẩu',
        description: 'Đã cập nhật mật khẩu tài khoản.',
      });
      setMessage({ type: 'success', text: 'Đã cập nhật mật khẩu.' });
      return { ok: true, error: '' };
    } catch (error) {
      const messageText = getErrorMessage(error, 'Không thể cập nhật mật khẩu. Vui lòng thử lại.');
      setMessage({ type: 'error', text: messageText });
      return { ok: false, error: messageText };
    } finally {
      setIsPasswordSaving(false);
    }
  }, [user?.email, user?.id]);

  const showMessage = useCallback((nextMessage: ProfileMessage) => {
    setMessage(nextMessage);
  }, []);

  return {
    profile,
    draft,
    message,
    isLoading,
    isSaving,
    isPasswordSaving,
    loadError,
    refetch: loadProfile,
    updateDraft,
    pickAvatar,
    removeAvatar,
    resetDraft,
    saveProfile,
    changePassword,
    showMessage,
  };
}
