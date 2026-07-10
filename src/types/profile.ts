export interface EmployeeProfile {
  fullName: string;
  displayName: string;
  email: string;
  phone: string;
  role: string;
  department: string;
  avatarUrl: string;
}

export interface ProfileMessage {
  type: 'success' | 'error';
  text: string;
}

export type PasswordField = 'current' | 'next' | 'confirm';
