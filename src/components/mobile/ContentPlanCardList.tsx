import { Link2 } from 'lucide-react';
import type { ContentPlanEditorOption, ContentPlanItem } from '../../types/contentPlan';
import { Avatar } from '../common/Avatar';
import { StatusBadge } from '../tasks/TaskBadges';
import { isSafeHttpUrl } from '../../utils/url';

const WEEKDAY = ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7'];

function airLabel(value: string) {
  const [year, month, day] = value.split('-').map(Number);
  if (!year || !month || !day) return value;
  const date = new Date(year, month - 1, day);
  return `${WEEKDAY[date.getDay()]} ${String(day).padStart(2, '0')}/${String(month).padStart(2, '0')}`;
}

interface ContentPlanCardListProps {
  items: ContentPlanItem[];
  editorOptions: ContentPlanEditorOption[];
  canEdit: boolean;
  onEdit: (item: ContentPlanItem) => void;
  highlightedId?: string | null;
}

export function ContentPlanCardList({ items, editorOptions, canEdit, onEdit, highlightedId = null }: ContentPlanCardListProps) {
  if (items.length === 0) {
    return (
      <div className="m-card m-empty" data-tour="content-plan-table">
        <b>Không có lịch air phù hợp</b>
        <span>Thử đổi tháng, editor hoặc thể loại.</span>
      </div>
    );
  }

  const groups = new Map<string, ContentPlanItem[]>();
  items.forEach((item) => groups.set(item.air_date, [...(groups.get(item.air_date) ?? []), item]));

  return (
    <div className="m-stack" data-tour="content-plan-table">
      {Array.from(groups.entries()).map(([air, rows]) => (
        <section key={air} className="m-section">
          <h2 className="m-section-label">Air {airLabel(air)} <span>{rows.length} dòng</span></h2>
          <div className="m-card m-list">
            {rows.map((item) => {
              const editor = editorOptions.find((entry) => entry.id === item.editor_id) ?? null;
              const hasLink = isSafeHttpUrl(item.link);
              const highlighted = highlightedId === item.id;
              return (
                <article
                  key={item.id}
                  className={`m-plan ${hasLink ? 'is-done' : ''} ${highlighted ? 'route-highlight' : ''}`}
                  data-content-plan-id={item.id}
                  aria-current={highlighted ? 'true' : undefined}
                >
                  <button type="button" className="m-task-open" onClick={() => onEdit(item)} disabled={!canEdit} aria-label={`Mở ${item.video_name}`} />
                  <div className="m-plan-head">
                    <h3>{item.video_name}</h3>
                    {hasLink ? (
                      <a href={item.link} target="_blank" rel="noopener noreferrer" className="m-link-btn" aria-label={`Mở link thành phẩm của ${item.video_name}`}>
                        <Link2 aria-hidden="true" />
                      </a>
                    ) : null}
                  </div>
                  {item.note ? <p className="m-task-note">{item.note}</p> : null}
                  <div className="m-plan-foot">
                    <span className="m-tag">{item.category}</span>
                    {item.linkedTaskStatus ? <StatusBadge status={item.linkedTaskStatus} /> : <span className="m-muted">Chưa giao</span>}
                    <span className="m-flex" />
                    {editor ? (
                      <span className="m-task-editor" data-tour="content-plan-editor">
                        <Avatar src={editor.avatarUrl} name={editor.short} color={editor.color} size="xs" />
                        {editor.short}
                      </span>
                    ) : <span className="m-pill-warn">Chưa phân công</span>}
                  </div>
                </article>
              );
            })}
          </div>
        </section>
      ))}
    </div>
  );
}
