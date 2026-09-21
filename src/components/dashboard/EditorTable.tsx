import type { EditorStat } from '../../hooks/useDashboard';
import { Avatar } from '../common/Avatar';
import { SectionCard } from './SectionCard';

interface EditorTableProps {
  editorStats: EditorStat[];
}

function Cell({ value, tone }: { value: number; tone?: 'alert' | 'strong' }) {
  if (!value) return <td className="zero">–</td>;
  return <td className={tone ?? ''}>{value}</td>;
}

// Bảng trung tâm của dashboard. Bốn cột trạng thái cộng lại đúng bằng cột Tổng,
// nên đọc ngang là kiểm được số, không phải nhẩm chéo giữa các thẻ.
export function EditorTable({ editorStats }: EditorTableProps) {
  const totals = editorStats.reduce(
    (sum, stat) => ({
      waiting: sum.waiting + stat.waiting,
      doing: sum.doing + stat.doing,
      done: sum.done + stat.done,
      hold: sum.hold + stat.hold,
      total: sum.total + stat.total,
      overdue: sum.overdue + stat.overdue,
      longVideos: sum.longVideos + stat.longVideos,
      motionVideos: sum.motionVideos + stat.motionVideos,
      shoots: sum.shoots + stat.shoots,
    }),
    { waiting: 0, doing: 0, done: 0, hold: 0, total: 0, overdue: 0, longVideos: 0, motionVideos: 0, shoots: 0 },
  );
  const totalRate = totals.total ? Math.round((totals.done / totals.total) * 100) : 0;

  return (
    <SectionCard
      title="Khối lượng theo editor"
      subtitle="Bốn cột trạng thái cộng lại đúng bằng cột Tổng."
      flush
    >
      <div className="dtable-wrap">
        <table className="dtable min-w-[720px]">
          <thead>
            <tr>
              <th>Editor</th>
              <th>Chờ</th>
              <th>Đang làm</th>
              <th>Đã xong</th>
              <th>Hoãn</th>
              <th>Tổng</th>
              <th>Trễ hạn</th>
              <th>Video dài</th>
              <th>Motion</th>
              <th>Buổi quay</th>
              <th>Hoàn thành</th>
            </tr>
          </thead>
          <tbody>
            {editorStats.map((stat) => (
              <tr key={stat.editor.id}>
                <td>
                  <span className="dtable-name">
                    <Avatar
                      src={stat.editor.avatarUrl}
                      name={stat.editor.short || stat.editor.name || stat.editor.initial}
                      color={stat.editor.color}
                      size="xs"
                      shape="rounded"
                      alt={stat.editor.short}
                    />
                    <b>{stat.editor.name}</b>
                  </span>
                </td>
                <Cell value={stat.waiting} />
                <Cell value={stat.doing} />
                <Cell value={stat.done} />
                <Cell value={stat.hold} />
                <Cell value={stat.total} tone="strong" />
                <Cell value={stat.overdue} tone="alert" />
                <Cell value={stat.longVideos} />
                <Cell value={stat.motionVideos} />
                <Cell value={stat.shoots} />
                <td className="strong">{stat.completionRate}%</td>
              </tr>
            ))}
            {editorStats.length === 0 ? (
              <tr><td colSpan={11} className="zero">Chưa có thành viên team editor.</td></tr>
            ) : (
              <tr className="dtable-total">
                <td>Tổng cộng</td>
                <td>{totals.waiting}</td>
                <td>{totals.doing}</td>
                <td>{totals.done}</td>
                <td>{totals.hold}</td>
                <td>{totals.total}</td>
                <td className={totals.overdue ? 'alert' : ''}>{totals.overdue}</td>
                <td>{totals.longVideos}</td>
                <td>{totals.motionVideos}</td>
                <td>{totals.shoots}</td>
                <td>{totalRate}%</td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </SectionCard>
  );
}
