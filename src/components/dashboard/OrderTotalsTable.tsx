import type { EditorMatrix } from '../../hooks/useDashboard';
import { SectionCard } from './SectionCard';

interface OrderTotalsTableProps {
  matrix: EditorMatrix;
  showLateDeadline: boolean;
}

function CountCell({ value, tone }: { value: number; tone?: 'strong' }) {
  if (!value) return <td className="zero">–</td>;
  return <td className={tone ?? ''}>{value}</td>;
}

// Gộp mọi editor lại để trả lời riêng một câu: bên nào đặt nhiều việc nhất.
export function OrderTotalsTable({ matrix, showLateDeadline }: OrderTotalsTableProps) {
  const { teams, teamTotals, grand } = matrix;

  if (teams.length === 0) return null;

  // Cột tỉ trọng là thanh nền, đọc nhanh hơn con số phần trăm đứng một mình.
  const maxShare = Math.max(...teamTotals.map((cell) => cell.share), 1);

  return (
    <SectionCard
      title="Tổng theo order"
      flush
    >
      <div className="dtable-wrap">
        <table className="dtable min-w-[640px]">
          <thead>
            <tr>
              <th>Team order</th>
              <th>Video dài</th>
              <th>Motion</th>
              <th>Tổng</th>
              <th>Đã xong</th>
              {showLateDeadline ? <th>Trễ deadline</th> : null}
              <th>Hoàn thành</th>
              <th>Tỉ trọng</th>
            </tr>
          </thead>
          <tbody>
            {teams.map((team, index) => {
              const cell = teamTotals[index];

              return (
                <tr key={team}>
                  <td className="dtable-rowhead"><span className="dtable-team">{team}</span></td>
                  <CountCell value={cell.longVideos} />
                  <CountCell value={cell.motion} />
                  <CountCell value={cell.total} tone="strong" />
                  <CountCell value={cell.done} />
                  {showLateDeadline
                    ? (cell.late ? <td className="alert">{cell.late}</td> : <td className="zero">–</td>)
                    : null}
                  <td>{cell.completionRate}%</td>
                  <td className="strong">
                    <span className="dtable-share">
                      <span className="dtable-share-bar" style={{ width: `${(cell.share / maxShare) * 100}%` }} />
                      <span className="dtable-share-value">{cell.share}%</span>
                    </span>
                  </td>
                </tr>
              );
            })}
            <tr className="dtable-total">
              <td>Tổng cộng</td>
              <td>{grand.longVideos}</td>
              <td>{grand.motion}</td>
              <td>{grand.total}</td>
              <td>{grand.done}</td>
              {showLateDeadline ? <td>{grand.late}</td> : null}
              <td>{grand.completionRate}%</td>
              <td>{grand.share}%</td>
            </tr>
          </tbody>
        </table>
      </div>
    </SectionCard>
  );
}
