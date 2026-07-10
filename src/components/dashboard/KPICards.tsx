import { Clapperboard, CircleCheck, Video } from 'lucide-react';
import { monthValueToDate } from '../../utils/month';

interface KPICardsProps {
  monthValue: string;
  totalVideos: number;
  doneVideos: number;
  totalShoots: number;
}

export function KPICards({ monthValue, totalVideos, doneVideos, totalShoots }: KPICardsProps) {
  const pct = totalVideos ? Math.round((doneVideos / totalVideos) * 100) : 0;
  const monthDate = monthValueToDate(monthValue);
  const monthNumber = monthDate.getMonth() + 1;
  const monthYear = monthDate.getFullYear();
  const monthSummary = `Tổng hợp tháng ${monthNumber} · ${monthYear}`;
  
  return (
    <div className="grid gap-5 md:grid-cols-3">
      {/* Total Videos */}
      <div className="card card-h relative p-6 overflow-hidden">
        <div className="absolute -top-12 -right-12 w-32 h-32 rounded-full" style={{ background: '#2563EB', opacity: 0.16, filter: 'blur(10px)' }}></div>
        <div className="flex items-center justify-between mb-6 relative">
          <span className="kpi-ic" style={{ background: '#2563EB' }}><Clapperboard /></span>
          <span className="text-[11px] font-bold text-sub uppercase tracking-wider">Tổng video</span>
        </div>
        <div className="text-[40px] font-extrabold leading-none tracking-tight relative">{totalVideos}</div>
        <div className="text-[12.5px] text-sub mt-2.5 truncate relative">{monthSummary}</div>
      </div>

      {/* Done Videos */}
      <div className="card card-h relative p-6 overflow-hidden">
        <div className="absolute -top-12 -right-12 w-32 h-32 rounded-full" style={{ background: '#22C55E', opacity: 0.16, filter: 'blur(10px)' }}></div>
        <div className="flex items-center justify-between mb-6 relative">
          <span className="kpi-ic" style={{ background: '#22C55E' }}><CircleCheck /></span>
          <span className="text-[11px] font-bold text-sub uppercase tracking-wider">Đã hoàn thành</span>
        </div>
        <div className="text-[40px] font-extrabold leading-none tracking-tight relative">{doneVideos}</div>
        <div className="text-[12.5px] text-sub mt-2.5 truncate relative">{pct}% khối lượng công việc</div>
      </div>

      {/* Total Shoots */}
      <div className="card card-h relative p-6 overflow-hidden">
        <div className="absolute -top-12 -right-12 w-32 h-32 rounded-full" style={{ background: '#A855F7', opacity: 0.16, filter: 'blur(10px)' }}></div>
        <div className="flex items-center justify-between mb-6 relative">
          <span className="kpi-ic" style={{ background: '#A855F7' }}><Video /></span>
          <span className="text-[11px] font-bold text-sub uppercase tracking-wider">BUỔI QUAY THÁNG {monthNumber}</span>
        </div>
        <div className="text-[40px] font-extrabold leading-none tracking-tight relative">{totalShoots}</div>
        <div className="text-[12.5px] text-sub mt-2.5 truncate relative">Lịch quay & sự kiện</div>
      </div>
    </div>
  );
}
