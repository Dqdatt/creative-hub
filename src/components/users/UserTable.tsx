import { PencilLine } from 'lucide-react';
import type { ManagedUserProfile } from '../../types/userManagement';
import { Avatar } from '../common/Avatar';

interface UserTableProps {
  users: ManagedUserProfile[];
  onEditUser: (user: ManagedUserProfile) => void;
}

export function UserTable({ users, onEditUser }: UserTableProps) {
  if (users.length === 0) {
    return (
      <table className="ctable min-w-[1080px]">
        <tbody>
          <tr>
            <td colSpan={7} className="px-3 py-12 text-center text-sub">
              <div className="table-empty-state">
                <strong>Không có thành viên phù hợp</strong>
                <span>Thử đổi bộ lọc hoặc từ khóa tìm kiếm.</span>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    );
  }

  return (
    <table className="ctable min-w-[1080px]">
      <thead>
        <tr>
          <th style={{ width: '300px' }}>Thành viên</th>
          <th style={{ width: '180px' }}>Vai trò</th>
          <th style={{ width: '180px' }}>Bộ phận</th>
          <th style={{ width: '140px' }}>Team editor</th>
          <th style={{ width: '120px' }}>Editor Code</th>
          <th style={{ width: '130px' }}>Trạng thái</th>
          <th className="text-center" style={{ width: '70px' }}>Sửa</th>
        </tr>
      </thead>
      <tbody>
        {users.map((user) => (
          <tr key={user.id} className="cursor-pointer" onDoubleClick={() => onEditUser(user)}>
            <td>
              <div className="flex min-w-0 items-center gap-3">
                <Avatar
                  src={user.avatarUrl}
                  name={user.displayName || user.fullName || user.email}
                  size="md"
                  alt={user.displayName || user.fullName}
                />
                <span className="min-w-0">
                  <span className="block truncate font-bold">{user.fullName}</span>
                  <span className="block truncate text-[12px] font-semibold text-sub">{user.email}</span>
                </span>
              </div>
            </td>
            <td>
              <span className="mini-chip" style={{ color: 'var(--text)' }}>
                {user.roleLabel}
              </span>
            </td>
            <td className="font-semibold text-sub">{user.department || 'Team Marketing'}</td>
            <td>
              <span className={`badge ${user.isEditorMember ? 'badge--done' : 'badge--wait'}`}>
                <span className="dot" />
                {user.isEditorMember ? 'Có tham gia' : 'Không'}
              </span>
            </td>
            <td>
              {user.editorCode ? (
                <span className="mini-chip">{user.editorCode}</span>
              ) : (
                <span className="text-sub/40">-</span>
              )}
            </td>
            <td>
              <span className={`badge ${user.isActive ? 'badge--done' : 'badge--wait'}`}>
                <span className="dot" />
                {user.isActive ? 'Đang hoạt động' : 'Tạm khóa'}
              </span>
            </td>
            <td className="text-center">
              <button
                type="button"
                className="icon-btn"
                style={{ width: '34px', height: '34px' }}
                aria-label="Sửa thành viên"
                title="Sửa thành viên"
                onClick={(event) => {
                  event.stopPropagation();
                  onEditUser(user);
                }}
              >
                <PencilLine />
              </button>
            </td>
          </tr>
        ))}
      </tbody>
    </table>
  );
}
