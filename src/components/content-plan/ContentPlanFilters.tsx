import { Plus, Search } from 'lucide-react';
import { StyledSelect } from '../common/StyledSelect';
import { CONTENT_PLAN_CATEGORIES } from '../../data/contentPlan';
import type { ContentPlanCategory, ContentPlanEditorOption } from '../../types/contentPlan';

interface ContentPlanFiltersProps {
  search: string;
  editorFilter: string | 'all';
  categoryFilter: ContentPlanCategory | 'all';
  editorOptions: ContentPlanEditorOption[];
  totalCount: number;
  filteredCount: number;
  canCreate: boolean;
  onSearchChange: (value: string) => void;
  onEditorChange: (value: string | 'all') => void;
  onCategoryChange: (value: ContentPlanCategory | 'all') => void;
  onCreate: () => void;
}

export function ContentPlanFilters({
  search,
  editorFilter,
  categoryFilter,
  editorOptions,
  totalCount,
  filteredCount,
  canCreate,
  onSearchChange,
  onEditorChange,
  onCategoryChange,
  onCreate,
}: ContentPlanFiltersProps) {
  return (
    <div className="card p-3">
      <div className="flex flex-wrap items-center gap-3">
        <div className="relative">
          <Search className="text-sub absolute left-4 top-1/2 -translate-y-1/2" style={{ width: '17px', height: '17px' }} />
          <input
            placeholder="Tìm tên video..."
            className="field w-72"
            style={{ paddingLeft: '42px' }}
            value={search}
            onChange={(event) => onSearchChange(event.target.value)}
          />
        </div>

        <StyledSelect
          style={{ width: 'auto', minWidth: '150px' }}
          value={editorFilter}
          onChange={(event) => onEditorChange(event.target.value)}
        >
          <option value="all">Tất cả editor</option>
          {editorOptions.map((editor) => (
            <option key={editor.id} value={editor.id}>{editor.short}</option>
          ))}
        </StyledSelect>

        <StyledSelect
          style={{ width: 'auto', minWidth: '150px' }}
          value={categoryFilter}
          onChange={(event) => onCategoryChange(event.target.value as ContentPlanCategory | 'all')}
        >
          <option value="all">Tất cả thể loại</option>
          {CONTENT_PLAN_CATEGORIES.map((category) => (
            <option key={category} value={category}>{category}</option>
          ))}
        </StyledSelect>

        <div className="ml-auto text-[13px] text-sub font-semibold flex items-center mr-1">
          {filteredCount} dòng {filteredCount !== totalCount ? `(trên tổng ${totalCount})` : ''}
        </div>

        {canCreate ? (
          <button type="button" onClick={onCreate} className="btn btn-sm">
            <Plus style={{ width: '17px', height: '17px' }} /> Thêm dòng
          </button>
        ) : null}
      </div>
    </div>
  );
}
