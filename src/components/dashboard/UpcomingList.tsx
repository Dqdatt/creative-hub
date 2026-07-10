import { BellRing, CalendarRange, Clock } from 'lucide-react';
import type { VideoTask } from '../../types/task';
import type { ShootSchedule } from '../../types/shoot';

interface UpcomingListProps {
  tasks: VideoTask[];
  shoots: ShootSchedule[];
}

export function UpcomingList({ tasks, shoots }: UpcomingListProps) {
  const urgentTasks = tasks.filter((t) => t.priority === 'Gấp' && t.status !== 'Đã xong');
  const today = new Date();
  const todayStr = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, '0')}-${String(today.getDate()).padStart(2, '0')}`;
  const upcomingShoots = shoots.filter((s) => s.date >= todayStr).slice(0, 3);

  return (
    <>
      <div className="section-eyebrow pt-2">
        <span className="icoc" style={{ background: 'var(--chip-2)', color: 'var(--accent)' }}><BellRing /></span>
        <div>
          <h2 className="text-[17px] font-extrabold leading-none tracking-tight">Cần lưu ý</h2>
          <p className="text-[12.5px] text-sub mt-1.5">Việc gấp và lịch quay sắp tới</p>
        </div>
      </div>
      
      <div className="grid md:grid-cols-2 gap-5">
        <div className="card p-5">
          <h3 className="text-[13px] font-bold text-sub uppercase tracking-wider mb-4 flex items-center gap-2">
            <span style={{ color: 'var(--danger)' }}><Clock className="w-4 h-4" /></span>
            Task Gấp ({urgentTasks.length})
          </h3>
          <div className="space-y-3">
            {urgentTasks.length === 0 ? (
              <p className="text-[13px] text-sub">Tuyệt vời, không có task nào đang bị chậm tiến độ.</p>
            ) : (
              urgentTasks.map((t) => (
                <div key={t.id} className="flex items-start justify-between p-3 rounded-xl bg-canvas border border-line">
                  <div>
                    <div className="font-semibold text-[13.5px] mb-1">{t.name}</div>
                    <div className="text-[12px] text-sub">Air: <span className="font-bold" style={{ color: 'var(--danger)' }}>{t.airDate || 'Chưa định'}</span></div>
                  </div>
                  <span className="urgent shrink-0">{t.priority}</span>
                </div>
              ))
            )}
          </div>
        </div>

        <div className="card p-5">
          <h3 className="text-[13px] font-bold text-sub uppercase tracking-wider mb-4 flex items-center gap-2">
            <span style={{ color: 'var(--accent)' }}><CalendarRange className="w-4 h-4" /></span>
            Lịch quay sắp diễn ra
          </h3>
          <div className="space-y-3">
            {upcomingShoots.length === 0 ? (
              <p className="text-[13px] text-sub">Không có lịch quay nào sắp tới.</p>
            ) : (
              upcomingShoots.map((s) => (
                <div key={s.id} className="flex items-start justify-between p-3 rounded-xl bg-canvas border border-line">
                  <div>
                    <div className="font-semibold text-[13.5px] mb-1">{s.place}</div>
                    <div className="text-[12px] text-sub">{s.time || 'Cả ngày'} • {s.displayCrew || s.crew}</div>
                  </div>
                  <div className="text-[12px] font-bold bg-white border border-line rounded-lg px-2 py-1 shadow-sm shrink-0 text-center leading-tight">
                    {s.date.split('-')[2]} <br/> <span className="text-[10px] text-sub uppercase font-medium">Thg {s.date.split('-')[1]}</span>
                  </div>
                </div>
              ))
            )}
          </div>
        </div>
      </div>
    </>
  );
}
