import { Search, Plus } from 'lucide-react';
import { StyledSelect } from '../common/StyledSelect';
import { ORDER_TEAMS } from '../../data/tasks';
import type { Editor, TaskCategory } from '../../types/task';

interface TaskFiltersProps {
  editors: Editor[];
  search: string;
  editorFilter: string;
  statusFilter: string;
  orderFilter: string;
  categoryFilter: TaskCategory | 'all';
  totalCount: number;
  filteredCount: number;
  onSearchChange: (val: string) => void;
  onEditorChange: (val: string) => void;
  onStatusChange: (val: string) => void;
  onOrderChange: (val: string) => void;
  onCategoryChange: (val: TaskCategory | 'all') => void;
  onAddTask: () => void;
  canAddTask?: boolean;
}

export function TaskFilters({
  editors,
  search,
  editorFilter,
  statusFilter,
  orderFilter,
  categoryFilter,
  totalCount,
  filteredCount,
  onSearchChange,
  onEditorChange,
  onStatusChange,
  onOrderChange,
  onCategoryChange,
  onAddTask,
  canAddTask = true,
}: TaskFiltersProps) {
  return (
    <div className="sticky-filter-bar flex flex-wrap items-center gap-3 p-3">
      <div className="relative">
        <Search className="text-sub absolute left-4 top-1/2 -translate-y-1/2" style={{ width: '17px', height: '17px' }} />
        <input
          placeholder="Tìm tên video..."
          className="field w-64"
          style={{ paddingLeft: '42px' }}
          value={search}
          onChange={(e) => onSearchChange(e.target.value)}
        />
      </div>
      <StyledSelect
        style={{ width: 'auto', minWidth: '160px' }}
        value={editorFilter}
        onChange={(e) => onEditorChange(e.target.value)}
      >
        <option value="all">Tất cả editor</option>
        {editors.map((e) => (
          <option key={e.id} value={e.id}>{e.short}</option>
        ))}
      </StyledSelect>
      <StyledSelect
        style={{ width: 'auto', minWidth: '170px' }}
        value={statusFilter}
        onChange={(e) => onStatusChange(e.target.value)}
      >
        <option value="all">Tất cả trạng thái</option>
        <option value="Đã xong">Đã xong</option>
        <option value="Đang làm">Đang làm</option>
        <option value="Chờ">Chờ</option>
      </StyledSelect>
      <StyledSelect
        style={{ width: 'auto', minWidth: '140px' }}
        value={orderFilter}
        onChange={(e) => onOrderChange(e.target.value)}
      >
        <option value="all">Tất cả order</option>
        {ORDER_TEAMS.map((team) => (
          <option key={team} value={team}>{team}</option>
        ))}
      </StyledSelect>
      <StyledSelect
        style={{ width: 'auto', minWidth: '150px' }}
        value={categoryFilter}
        onChange={(e) => onCategoryChange(e.target.value as TaskCategory | 'all')}
      >
        <option value="all">Tất cả thể loại</option>
        <option value="Video dài">Video dài</option>
        <option value="Motion">Motion</option>
        <option value="Ads">Ads</option>
      </StyledSelect>
      <div className="ml-auto text-[13px] text-sub font-semibold flex items-center mr-1">
        {filteredCount} video {filteredCount !== totalCount ? `(trên tổng ${totalCount})` : ''}
      </div>
      {canAddTask ? (
        <button onClick={onAddTask} className="btn btn-sm">
          <Plus style={{ width: '17px', height: '17px' }} /> Thêm Task
        </button>
      ) : null}
    </div>
  );
}
