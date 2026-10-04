import { Pencil } from 'lucide-react';
import type { BrandKpi } from '../../hooks/useDashboard';
import type { BrandKpiTarget } from '../../services/brandKpiService';
import { Avatar } from '../common/Avatar';
import { monthValueToDate } from '../../utils/month';
import { SectionCard } from './SectionCard';

interface BrandKpiCardProps {
  brandKpi: BrandKpi;
  monthValue: string;
  /** null nghĩa là tháng này chưa nhập chỉ tiêu; bảng chỉ hiện số đếm được. */
  target: BrandKpiTarget | null;
  onEditTarget: () => void;
}

function rate(done: number, target: number) {
  return target > 0 ? Math.round((done / target) * 100) : null;
}

function RateCell({ done, target }: { done: number; target: number }) {
  const value = rate(done, target);
  if (value === null) return <td className="zero">–</td>;
  return <td className={value >= 100 ? 'strong' : 'alert'}>{value}%</td>;
}

function CountCell({ value, tone }: { value: number; tone?: 'strong' }) {
  if (!value) return <td className="zero">–</td>;
  return <td className={tone ?? ''}>{value}</td>;
}

// KPI riêng của BRAND, tự đếm lại mỗi khi đổi tháng. Không có chỉ tiêu đặt
// trước nên cột cuối là tỉ trọng trong nội bộ BRAND, cộng lại bằng 100%.
export function BrandKpiCard({ brandKpi, monthValue, target, onEditTarget }: BrandKpiCardProps) {
  const { rows, longVideos, motion, total } = brandKpi;

  if (rows.length === 0) return null;

  const monthLabel = monthValueToDate(monthValue).getMonth() + 1;
  const targetTotal = target ? target.longVideos + target.motion : 0;
  const subtitle = total === 0
    ? 'Tháng này chưa có video nào thuộc BRAND.'
    : target
      ? undefined
      : 'Chưa nhập chỉ tiêu cho tháng này, bảng chỉ hiện số đếm được.';

  return (
    <SectionCard
      title={`KPI ${brandKpi.team} tháng ${monthLabel}`}
      subtitle={subtitle}
      action={(
        <button type="button" className="btn-ghost" onClick={onEditTarget}>
          <Pencil /> {target ? 'Sửa chỉ tiêu' : 'Nhập chỉ tiêu'}
        </button>
      )}
      flush
    >
      <div className="dtable-wrap">
        <table className="dtable min-w-[460px]">
          <thead>
            <tr>
              <th>Editor</th>
              <th>Video dài</th>
              <th>Motion</th>
              <th>Tổng</th>
              <th>Tỉ trọng</th>
            </tr>
          </thead>
          <tbody>
            {rows.map((row) => (
              <tr key={row.key}>
                <td className="dtable-rowhead">
                  <span className="dtable-name">
                    {row.editor ? (
                      <Avatar
                        src={row.editor.avatarUrl}
                        name={row.editor.short || row.editor.name || row.editor.initial}
                        color={row.editor.color}
                        size="xs"
                        shape="rounded"
                        alt={row.editor.short}
                      />
                    ) : null}
                    <b>{row.label}</b>
                  </span>
                </td>
                <CountCell value={row.longVideos} />
                <CountCell value={row.motion} />
                <CountCell value={row.total} tone="strong" />
                <td>{row.share}%</td>
              </tr>
            ))}
            <tr className="dtable-band">
              <td>Đạt cả {rows.length} editor</td>
              <td>{longVideos}</td>
              <td>{motion}</td>
              <td>{total}</td>
              <td>{total ? '100%' : '–'}</td>
            </tr>
            {target ? (
              <>
                <tr>
                  <td className="dtable-rowhead">Chỉ tiêu</td>
                  <td>{target.longVideos}</td>
                  <td>{target.motion}</td>
                  <td>{targetTotal}</td>
                  <td className="zero">–</td>
                </tr>
                <tr className="dtable-total">
                  <td>% hoàn thành KPI</td>
                  <RateCell done={longVideos} target={target.longVideos} />
                  <RateCell done={motion} target={target.motion} />
                  <RateCell done={total} target={targetTotal} />
                  <td>–</td>
                </tr>
              </>
            ) : null}
          </tbody>
        </table>
      </div>
    </SectionCard>
  );
}
