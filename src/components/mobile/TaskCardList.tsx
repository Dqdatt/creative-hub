import { Clock3, Link2, Zap } from 'lucide-react';
import type { Editor, VideoTask } from '../../types/task';
import { Avatar } from '../common/Avatar';
import { StatusBadge } from '../tasks/TaskBadges';
import { getTaskDeadlineState, getTaskLinkDeadline } from '../../utils/taskDeadline';
import { isSafeHttpUrl } from '../../utils/url';

const WEEKDAY = ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7'];

function shortDate(date: Date) {
  return `${WEEKDAY[date.getDay()]} ${String(date.getDate()).padStart(2, '0')}/${String(date.getMonth() + 1).padStart(2, '0')}`;
}

type DeadlineTone = 'late' | 'ok' | 'warn' | 'info';

// Nhãn hạn thêm link, dựa đúng vào rule tính trễ deadline (Ngày Air + 1 ngày làm việc).
function deadlineChip(task: VideoTask, monthValue: string): { text: string; tone: DeadlineTone } | null {
  if (task.status === 'Hoãn') return null;
  const deadline = getTaskLinkDeadline(task, monthValue);
  const state = getTaskDeadlineState(task, monthValue);
  const due = deadline ? shortDate(deadline) : '';

  if (task.status === 'Đã xong' && !isSafeHttpUrl(task.link)) return { text: 'Thiếu Link thành phẩm', tone: 'warn' };
  if (state === 'late' || state === 'running-late') return { text: `Trễ deadline · hạn ${due}`, tone: 'late' };
  if (state === 'on-time') return { text: 'Đúng hạn', tone: 'ok' };
  if (state === 'in-progress' && due) return { text: `Hạn link ${due}`, tone: 'info' };
  return null;
}

interface TaskCardListProps {
  tasks: VideoTask[];
  editors: Editor[];
  monthValue: string;
  canOpen: boolean;
  onOpen: (task: VideoTask) => void;
  highlightedId?: string | null;
}

export function TaskCardList({ tasks, editors, monthValue, canOpen, onOpen, highlightedId = null }: TaskCardListProps) {
  if (tasks.length === 0) {
    return (
      <div className="m-card m-empty" data-tour="video-task-table">
        <b>Không có video phù hợp</b>
        <span>Thử đổi bộ lọc hoặc từ khóa tìm kiếm.</span>
      </div>
    );
  }

  return (
    <div className="m-cards" data-tour="video-task-table">
      {tasks.map((task) => {
        const editor = editors.find((entry) => entry.id === task.editorId);
        const chip = deadlineChip(task, monthValue);
        const hasLink = isSafeHttpUrl(task.link);
        const highlighted = Boolean(task.dbId && highlightedId === task.dbId);
        const tour = task.contentPlanId && task.status === 'Chờ'
          ? 'video-task-waiting-row'
          : task.contentPlanId && task.status === 'Đang làm' ? 'video-task-complete' : undefined;

        return (
          <article
            key={task.dbId ?? task.id}
            className={`m-card m-task ${highlighted ? 'route-highlight' : ''} ${task.status === 'Đã xong' ? 'is-done' : ''}`}
            data-video-task-id={task.dbId}
            data-tour={tour}
            aria-current={highlighted ? 'true' : undefined}
          >
            <button type="button" className="m-task-open" onClick={() => onOpen(task)} disabled={!canOpen} aria-label={`Mở task ${task.name}`} />
            <div className="m-task-top">
              <span className="m-task-stt">#{task.id}</span>
              <StatusBadge status={task.status} />
              {task.priority === 'Gấp' ? <span className="m-urgent"><Zap aria-hidden="true" />Gấp</span> : null}
              <span className="m-flex" />
              {hasLink ? (
                <a
                  href={task.link}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="m-link-btn"
                  aria-label={`Mở link thành phẩm của ${task.name}`}
                >
                  <Link2 aria-hidden="true" />
                </a>
              ) : null}
            </div>
            <h3 className="m-task-name">{task.name}</h3>
            <div className="m-task-meta">
              {editor ? (
                <span className="m-task-editor">
                  <Avatar src={editor.avatarUrl} name={editor.short || editor.name} color={editor.color} size="xs" />
                  {editor.short}
                </span>
              ) : <span className="m-muted">Chưa phân công</span>}
              {task.orderTeam ? <><i aria-hidden="true">·</i><span>{task.orderTeam}</span></> : null}
              <i aria-hidden="true">·</i><span>{task.category}</span>
              {task.resize ? <><i aria-hidden="true">·</i><span>{task.resize}</span></> : null}
            </div>
            <dl className="m-task-dates">
              <div><dt>Nhận</dt><dd>{task.receiveDate || '—'}</dd></div>
              <div><dt>Trả</dt><dd>{task.returnDate || '—'}</dd></div>
              <div><dt>Air</dt><dd>{task.airDate || '—'}</dd></div>
            </dl>
            {chip ? (
              <span className={`m-deadline m-deadline--${chip.tone}`}>
                <Clock3 aria-hidden="true" />{chip.text}
              </span>
            ) : null}
            {task.note ? <p className="m-task-note">{task.note}</p> : null}
          </article>
        );
      })}
    </div>
  );
}
