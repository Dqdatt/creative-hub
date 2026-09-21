import type { VideoTask } from '../../types/task';
import type { ShootSchedule } from '../../types/shoot';
import { SectionCard } from './SectionCard';

const MAX_ROWS = 5;

export function UrgentTasksCard({ tasks }: { tasks: VideoTask[] }) {
  const urgentTasks = tasks.filter((task) => task.priority === 'Gấp' && task.status !== 'Đã xong');

  return (
    <SectionCard
      title="Task gấp chưa xong"
      subtitle={urgentTasks.length ? `${urgentTasks.length} task đang đánh dấu Gấp.` : undefined}
    >
      <div className="dlist">
        {urgentTasks.length === 0 ? (
          <p className="dlist-empty">Không có task gấp nào đang chậm.</p>
        ) : (
          urgentTasks.slice(0, MAX_ROWS).map((task) => (
            <div key={task.dbId ?? task.id} className="dlist-item">
              <div className="dlist-copy">
                <b title={task.name}>{task.name}</b>
                <span>Air {task.airDate || 'chưa định'} · {task.status}</span>
              </div>
              <span className="dlist-flag">Gấp</span>
            </div>
          ))
        )}
        {urgentTasks.length > MAX_ROWS ? (
          <p className="dlist-empty">và {urgentTasks.length - MAX_ROWS} task gấp khác</p>
        ) : null}
      </div>
    </SectionCard>
  );
}

export function UpcomingShootsCard({ shoots }: { shoots: ShootSchedule[] }) {
  const today = new Date();
  const todayIso = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, '0')}-${String(today.getDate()).padStart(2, '0')}`;
  const upcoming = shoots
    .filter((shoot) => shoot.date >= todayIso)
    .sort((a, b) => a.date.localeCompare(b.date));

  return (
    <SectionCard
      title="Lịch quay sắp tới"
      subtitle={upcoming.length ? `${upcoming.length} buổi quay từ hôm nay trở đi.` : undefined}
    >
      <div className="dlist">
        {upcoming.length === 0 ? (
          <p className="dlist-empty">Không có lịch quay nào sắp tới.</p>
        ) : (
          upcoming.slice(0, MAX_ROWS).map((shoot) => (
            <div key={shoot.id} className="dlist-item">
              <span className="dlist-date">
                <b>{Number(shoot.date.split('-')[2])}</b>
                <span>Thg {Number(shoot.date.split('-')[1])}</span>
              </span>
              <div className="dlist-copy">
                <b title={shoot.place}>{shoot.place || shoot.content}</b>
                <span>{shoot.time || 'Cả ngày'} · {shoot.displayCrew || shoot.crew || 'Chưa có crew'}</span>
              </div>
            </div>
          ))
        )}
        {upcoming.length > MAX_ROWS ? (
          <p className="dlist-empty">và {upcoming.length - MAX_ROWS} buổi quay khác</p>
        ) : null}
      </div>
    </SectionCard>
  );
}
