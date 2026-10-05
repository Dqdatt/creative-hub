import { ChevronRight } from 'lucide-react';
import type { ManagedUserProfile } from '../../types/userManagement';
import { Avatar } from '../common/Avatar';

interface UserCardListProps {
  users: ManagedUserProfile[];
  onEditUser: (user: ManagedUserProfile) => void;
}

export function UserCardList({ users, onEditUser }: UserCardListProps) {
  if (users.length === 0) {
    return (
      <div className="m-card m-empty">
        <b>Không có thành viên phù hợp</b>
        <span>Thử đổi bộ lọc hoặc từ khóa tìm kiếm.</span>
      </div>
    );
  }

  return (
    <div className="m-card m-list">
      {users.map((user) => (
        <button key={user.id} type="button" className="m-user" onClick={() => onEditUser(user)} aria-label={`Sửa thành viên ${user.fullName}`}>
          <Avatar src={user.avatarUrl} name={user.displayName || user.fullName || user.email} size="md" />
          <span className="m-user-copy">
            <span className="m-user-name">
              <b>{user.fullName || user.displayName || user.email}</b>
              {!user.isActive ? <span className="m-pill-danger">Tạm khóa</span> : null}
            </span>
            <span className="m-user-email">{user.email}</span>
            <span className="m-user-tags">
              <span className="m-tag m-tag--accent">{user.roleLabel}</span>
              {user.isEditorMember ? <span className="m-tag">Team editor{user.editorCode ? ` · ${user.editorCode}` : ''}</span> : null}
              {user.department ? <span className="m-tag">{user.department}</span> : null}
            </span>
          </span>
          <ChevronRight className="m-row-chevron" aria-hidden="true" />
        </button>
      ))}
    </div>
  );
}
