import { AlertCircle, CircleCheck } from 'lucide-react';
import type { ProfileMessage } from '../../types/profile';

interface ProfileNoticeProps {
  message: ProfileMessage | null;
}

export function ProfileNotice({ message }: ProfileNoticeProps) {
  if (!message) return null;

  const isSuccess = message.type === 'success';

  return (
    <div
      id="profileNotice"
      className={`profile-notice ${isSuccess ? 'profile-notice--success' : 'profile-notice--error'}`}
      role="status"
    >
      {isSuccess ? <CircleCheck /> : <AlertCircle />}
      <span>{message.text}</span>
    </div>
  );
}
