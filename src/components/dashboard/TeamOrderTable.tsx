import type { Editor } from '../../types/task';
import type { TeamStat } from '../../hooks/useDashboard';
import { SectionCard } from './SectionCard';

interface TeamOrderTableProps {
  editors: Editor[];
  teamStats: TeamStat[];
  totalVideos: number;
}

export function TeamOrderTable({ editors, teamStats, totalVideos }: TeamOrderTableProps) {
  const grandTotal = teamStats.reduce((sum, entry) => sum + entry.total, 0);
  const grandDone = teamStats.reduce((sum, entry) => sum + entry.done, 0);
  // Video chưa điền team order không nằm trong bảng, nói rõ ra để số liệu báo cáo khớp nhau.
  const withoutTeam = Math.max(0, totalVideos - grandTotal);

  if (teamStats.length === 0) return null;

  return (
    <SectionCard
      title="Khối lượng theo team order"
      subtitle={withoutTeam
        ? `${withoutTeam} video chưa gắn team order nên không có trong bảng.`
        : 'Bên nào đặt nhiều video nhất, và ai đang nhận.'}
      flush
    >
      <div className="dtable-wrap">
        <table className="dtable min-w-[520px]">
          <thead>
            <tr>
              <th>Team order</th>
              {editors.map((editor) => (
                <th key={editor.id}>{editor.short}</th>
              ))}
              <th>Đã xong</th>
              <th>Tổng</th>
              <th>Tỉ trọng</th>
            </tr>
          </thead>
          <tbody>
            {teamStats.map((entry) => (
              <tr key={entry.team}>
                <td><span className="dtable-team">{entry.team}</span></td>
                {entry.perEditor.map((count, index) => (
                  count
                    ? <td key={editors[index]?.id ?? index}>{count}</td>
                    : <td key={editors[index]?.id ?? index} className="zero">–</td>
                ))}
                <td>{entry.done}/{entry.total}</td>
                <td className="strong">{entry.total}</td>
                <td className="strong">{entry.share}%</td>
              </tr>
            ))}
            <tr className="dtable-total">
              <td>Tổng cộng</td>
              {editors.map((editor, index) => (
                <td key={editor.id}>
                  {teamStats.reduce((sum, entry) => sum + (entry.perEditor[index] ?? 0), 0)}
                </td>
              ))}
              <td>{grandDone}/{grandTotal}</td>
              <td>{grandTotal}</td>
              <td>100%</td>
            </tr>
          </tbody>
        </table>
      </div>
    </SectionCard>
  );
}
