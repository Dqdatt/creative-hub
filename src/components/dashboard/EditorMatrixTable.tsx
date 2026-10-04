import { Fragment, type ReactNode } from 'react';
import type { EditorMatrix, MatrixCell } from '../../hooks/useDashboard';
import { Avatar } from '../common/Avatar';
import { monthValueToDate } from '../../utils/month';
import { isCompletedAtColumnAvailable } from '../../services/tasksService';
import { SectionCard } from './SectionCard';

interface EditorMatrixTableProps {
  matrix: EditorMatrix;
  monthValue: string;
  showLateDeadline: boolean;
  action?: ReactNode;
}

type CellValue = (cell: MatrixCell) => number | string;

interface MetricRow {
  label: string;
  value: CellValue;
  /** Buổi quay không thuộc team order nào, chỉ điền ở cột Tổng. */
  editorOnly?: (group: { shoots: number }) => number;
  grandOnly?: number;
  tone?: 'band' | 'alert';
  /** Mở đầu khối chỉ số thứ hai (kết quả), kẻ một đường tách. */
  startsBlock?: boolean;
}

const NOT_APPLICABLE = '–';

function formatValue(value: number | string) {
  if (value === 0 || value === NOT_APPLICABLE) return <span className="zero">{NOT_APPLICABLE}</span>;
  return value;
}

// Bảng chéo của admin: mỗi editor là một nhóm cột, bên dưới tách theo team
// order; mỗi hàng là một chỉ số. Đọc dọc một nhóm cột là trọn việc của một người.
export function EditorMatrixTable({ matrix, monthValue, showLateDeadline, action }: EditorMatrixTableProps) {
  const { teams, editors } = matrix;

  if (editors.length === 0) return null;

  const teamColumns = teams.length;
  const minWidth = 150 + editors.length * (teamColumns + 1) * 68 + 84;

  // Khối trên là khối lượng, khối dưới là tỉ lệ.
  const rows: MetricRow[] = [
    { label: 'Video dài', value: (cell) => cell.longVideos },
    { label: 'Motion', value: (cell) => cell.motion },
    { label: 'Tổng theo order', value: (cell) => cell.total, tone: 'band' },
    {
      label: 'Buổi quay',
      value: () => NOT_APPLICABLE,
      editorOnly: (group) => group.shoots,
      grandOnly: matrix.shoots,
    },
    ...(showLateDeadline
      ? [{ label: 'Trễ deadline', value: (cell: MatrixCell) => cell.late, startsBlock: true, tone: 'alert' } as MetricRow]
      : []),
    // Khi tắt Trễ deadline thì Hoàn thành là hàng mở đầu khối tỉ lệ.
    { label: 'Hoàn thành', value: (cell) => `${cell.completionRate}%`, startsBlock: !showLateDeadline },
    { label: 'Tỉ trọng', value: (cell) => `${cell.share}%` },
  ];

  return (
    <SectionCard
      title={`Tổng task tháng ${monthValueToDate(monthValue).getMonth() + 1}`}
      subtitle={isCompletedAtColumnAvailable()
        ? undefined
        : 'Chưa chạy supabase/video_task_completion_deadline_patch.sql nên chưa có mốc hoàn thành để tính trễ deadline.'}
      action={action}
      flush
    >
      <div className="dtable-wrap">
        <table className="dtable dtable-matrix" style={{ minWidth: `${minWidth}px` }}>
          <thead>
            <tr>
              <th rowSpan={2}>Chỉ số</th>
              {editors.map((group) => (
                <th key={group.key} colSpan={teamColumns + 1} className="dtable-grouphead">
                  <span className="dtable-colhead">
                    {group.editor ? (
                      <Avatar
                        src={group.editor.avatarUrl}
                        name={group.editor.short || group.editor.name || group.editor.initial}
                        color={group.editor.color}
                        size="xs"
                        shape="rounded"
                        alt={group.editor.short}
                      />
                    ) : null}
                    {group.label}
                  </span>
                </th>
              ))}
              <th rowSpan={2}>Tổng cộng</th>
            </tr>
            <tr>
              {editors.map((group) => (
                <Fragment key={group.key}>
                  {teams.map((team) => (
                    <th key={`${group.key}-${team}`} className="dtable-teamhead">{team}</th>
                  ))}
                  <th key={`${group.key}-total`} className="dtable-teamhead dtable-groupedge">Tổng</th>
                </Fragment>
              ))}
            </tr>
          </thead>
          <tbody>
            {rows.map((row) => (
              <tr
                key={row.label}
                className={[
                  row.tone ? `dtable-${row.tone}` : '',
                  row.startsBlock ? 'dtable-blockstart' : '',
                ].filter(Boolean).join(' ') || undefined}
              >
                <td className="dtable-rowhead">{row.label}</td>
                {editors.map((group) => (
                  <Fragment key={group.key}>
                    {group.cells.map((cell, index) => (
                      <td key={`${group.key}-${teams[index]}`}>{formatValue(row.value(cell))}</td>
                    ))}
                    <td className="dtable-groupedge strong">
                      {formatValue(row.editorOnly ? row.editorOnly(group) : row.value(group.totals))}
                    </td>
                  </Fragment>
                ))}
                <td className="strong">
                  {formatValue(row.grandOnly ?? row.value(matrix.grand))}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </SectionCard>
  );
}
