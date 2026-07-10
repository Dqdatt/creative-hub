import type { AppRole } from '../config/permissions';

export interface ManagedUserProfile {
  id: string;
  email: string;
  fullName: string;
  displayName: string;
  phone: string;
  role: AppRole;
  roleLabel: string;
  department: string;
  avatarUrl: string;
  editorCode: string;
  crewKey: string;
  isEditorMember: boolean;
  isActive: boolean;
  createdAt: string;
  updatedAt: string;
}

export interface UserProfileFormData {
  fullName: string;
  displayName: string;
  email: string;
  phone: string;
  role: AppRole;
  department: string;
  editorCode: string;
  crewKey: string;
  isEditorMember: boolean;
  isActive: boolean;
}

export interface CreateMemberFormData extends UserProfileFormData {
  password: string;
}
