import { CircleCheck, CircleDashed, Clapperboard, FileText, Hourglass, TriangleAlert } from 'lucide-react';
import type { ReactNode } from 'react';
import type { KpiRow, TaskKpi } from '../../hooks/useTaskKpi';
import { formatVietnameseMonth, monthValueToDate } from '../../utils/month';
import { Avatar } from '../common/Avatar';
import { MetricTile } from './MetricTile';
import { SectionCard } from './SectionCard';

interface TaskKpiViewProps {
  monthValue: string;
  kpi: TaskKpi;
  canCreateReport: boolean;
  onOpenReport: () => void;
  onOpenTasks: () => void;
  brandKpiCard?: ReactNode;
}

function Count({ value, tone }: { value: number; tone?: 'strong' | 'alert' }) {
  if (!value) return <td className="zero">–</td>;
  return <td className={tone ?? ''}>{value}</td>;
}

function RateBar({ value }: { value: number }) {
  return (
    <span className="dtable-share">
      <span className="dtable-share-bar" style={{ width: `${value}%` }} />
      <span className="dtable-share-value">{value}%</span>
    </span>
  );
}

function KpiTable({
  firstColumn,
  rows,
  total,
  showCategorySplit = true,
  renderLabel,
}: {
  firstColumn: string;
  rows: KpiRow[];
  total: KpiRow;
  showCategorySplit?: boolean;
  renderLabel?: (row: KpiRow) => ReactNode;
}) {
  return (
    <div className="dtable-wrap">
      <table className="dtable min-w-[640px]">
        <thead>
          <tr>
            <th>{firstColumn}</th>
            {showCategorySplit ? <th>Video dài</th> : null}
            {showCategorySplit ? <th>Motion</th> : null}
            <th>Tổng</th>
            <th>Đã xong</th>
            <th>Đang làm</th>
            <th>Chưa nhận</th>
            <th>Quá hạn</th>
            <th>Hoàn thành</th>
          </tr>
        </thead>
        <tbody>
          {rows.map((row) => (
            <tr key={row.key}>
              <td className="dtable-rowhead">{renderLabel ? renderLabel(row) : <span className="dtable-team">{row.label}</span>}</td>
              {showCategorySplit ? <Count value={row.longVideos} /> : null}
              {showCategorySplit ? <Count value={row.motion} /> : null}
              <Count value={row.total} tone="strong" />
              <Count value={row.done} />
              <Count value={row.doing} />
              <Count value={row.open} />
              <Count value={row.overdue} tone="alert" />
              <td className="strong"><RateBar value={row.rate} /></td>
            </tr>
          ))}
          <tr className="dtable-total">
            <td>Tổng cộng</td>
            {showCategorySplit ? <td>{total.longVideos}</td> : null}
            {showCategorySplit ? <td>{total.motion}</td> : null}
            <td>{total.total}</td>
            <td>{total.done}</td>
            <td>{total.doing}</td>
            <td>{total.open}</td>
            <td>{total.overdue}</td>
            <td>{total.rate}%</td>
          </tr>
        </tbody>
      </table>
    </div>
  );
}

export function TaskKpiView({ monthValue, kpi, canCreateReport, onOpenReport, onOpenTasks, brandKpiCard }: TaskKpiViewProps) {
  const { summary } = kpi;
  const monthDate = monthValueToDate(monthValue);
  const lastDay = new Date(monthDate.getFullYear(), monthDate.getMonth() + 1, 0).getDate();
  const month = String(monthDate.getMonth() + 1).padStart(2, '0');
  const totalRow: KpiRow = { key: 'total', label: 'Tổng cộng', share: 100, ...summary };

  return (
    <div className="dashboard" data-view="dashboard">
      <SectionCard
        title={`KPI ${formatVietnameseMonth(monthValue)}`}
        subtitle={`Task có ngày Air từ 01/${month} đến ${lastDay}/${month}. Chỉ task có link thành phẩm mới tính hoàn thành.`}
        action={canCreateReport ? (
          <button type="button" className="btn btn-sm" onClick={onOpenReport}>
            <FileText /> Tạo báo cáo
          </button>
        ) : undefined}
      >
        <div className="tile-grid">
          <MetricTile icon={Clapperboard} value={summary.total} label="Tổng video" hint={`${summary.longVideos} video dài · ${summary.motion} motion`} onClick={onOpenTasks} />
          <MetricTile icon={CircleCheck} value={`${summary.done} · ${summary.rate}%`} label="Hoàn thành (có link)" />
          <MetricTile icon={Hourglass} value={summary.doing} label="Đang làm" hint="Đã có editor, chưa có link thành phẩm" />
          <MetricTile icon={CircleDashed} value={summary.open} label="Chưa có người nhận" onClick={onOpenTasks} />
          <MetricTile icon={TriangleAlert} value={summary.overdue} label="Quá hạn" hint="Ngày Air đã qua nhưng chưa có link" />
        </div>
      </SectionCard>

      <SectionCard title="Theo thể loại" flush>
        <KpiTable firstColumn="Thể loại" rows={kpi.byCategory} total={totalRow} showCategorySplit={false} />
      </SectionCard>

      <SectionCard title="Theo order" subtitle="Số video của từng phòng ban order trong tháng." flush>
        {kpi.byOrder.length ? (
          <KpiTable firstColumn="Order" rows={kpi.byOrder} total={totalRow} />
        ) : <p className="dsection-empty">Chưa có task trong tháng.</p>}
      </SectionCard>

      <SectionCard title="Theo editor" subtitle="Hoàn thành chỉ tính task có link thành phẩm." flush>
        {kpi.byEditor.length ? (
          <KpiTable
            firstColumn="Editor"
            rows={kpi.byEditor}
            total={totalRow}
            renderLabel={(row) => (
              <span className="flex items-center gap-2">
                {row.editor ? <Avatar src={row.editor.avatarUrl} name={row.editor.short} color={row.editor.color} size="xs" /> : null}
                <span className={row.editor ? 'font-semibold' : 'text-sub'}>{row.label}</span>
              </span>
            )}
          />
        ) : <p className="dsection-empty">Chưa có task trong tháng.</p>}
      </SectionCard>

      {brandKpiCard}
    </div>
  );
}
