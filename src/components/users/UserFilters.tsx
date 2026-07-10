import { Plus, Search } from 'lucide-react';
import { StyledSelect } from '../common/StyledSelect';
import { ROLE_LABELS } from '../../config/permissions';
import type { AppRole } from '../../config/permissions';

interface UserFiltersProps {
  search: string;
  roleFilter: AppRole | 'all';
  statusFilter: 'all' | 'active' | 'inactive';
  totalCount: number;
  filteredCount: number;
  onSearchChange: (value: string) => void;
  onRoleChange: (value: AppRole | 'all') => void;
  onStatusChange: (value: 'all' | 'active' | 'inactive') => void;
  onCreateUser: () => void;
}

const ROLE_OPTIONS: AppRole[] = ['admin', 'creative_manager', 'content_creator', 'editor'];

export function UserFilters({
  search,
  roleFilter,
  statusFilter,
  totalCount,
  filteredCount,
  onSearchChange,
  onRoleChange,
  onStatusChange,
  onCreateUser,
}: UserFiltersProps) {
  return (
    <section className="card user-filter-card sticky-filter-bar">
      <div className="user-filter-row flex flex-col gap-2 lg:flex-row lg:items-center">
        <div className="min-w-[240px] flex-1">
          <div className="relative">
            <Search
              className="pointer-events-none absolute left-4 top-1/2 -translate-y-1/2 text-sub"
              style={{ width: '17px', height: '17px' }}
            />
            <input
              id="userSearch"
              className="field"
              style={{ paddingLeft: '42px' }}
              value={search}
              onChange={(event) => onSearchChange(event.target.value)}
              placeholder="Tìm theo tên hoặc email"
            />
          </div>
        </div>

        <div className="min-w-[170px]">
          <StyledSelect
            id="userRoleFilter"
            value={roleFilter}
            onChange={(event) => onRoleChange(event.target.value as AppRole | 'all')}
          >
            <option value="all">Tất cả vai trò</option>
            {ROLE_OPTIONS.map((role) => (
              <option key={role} value={role}>{ROLE_LABELS[role]}</option>
            ))}
          </StyledSelect>
        </div>

        <div className="min-w-[160px]">
          <StyledSelect
            id="userStatusFilter"
            value={statusFilter}
            onChange={(event) => onStatusChange(event.target.value as 'all' | 'active' | 'inactive')}
          >
            <option value="all">Tất cả trạng thái</option>
            <option value="active">Đang hoạt động</option>
            <option value="inactive">Tạm khóa</option>
          </StyledSelect>
        </div>

        <div className="flex items-center justify-between gap-3 lg:ml-auto">
          <div className="text-[12.5px] font-semibold text-sub">
            {filteredCount}/{totalCount} thành viên
          </div>
          <button type="button" className="btn btn-sm" onClick={onCreateUser}>
            <Plus /> Thêm thành viên
          </button>
        </div>
      </div>
    </section>
  );
}
