import { Building2 } from 'lucide-react';
import type { Editor, VideoTask } from '../../types/task';
import { ORDER_TEAMS } from '../../data/tasks';

interface TeamOrderTableProps {
  editors: Editor[];
  tasks: VideoTask[];
}

export function TeamOrderTable({ editors, tasks }: TeamOrderTableProps) {
  const activeTeams = ORDER_TEAMS.map((t) => {
    const perEditor = editors.map((e) => tasks.filter((v) => v.orderTeam === t && v.editorId === e.id).length);
    const n = tasks.filter((v) => v.orderTeam === t).length;
    return { t, n, perEditor };
  })
    .filter((o) => o.n > 0)
    .sort((a, b) => b.n - a.n);

  const maxN = Math.max(1, ...activeTeams.map((o) => o.n));
  const totalTasks = tasks.length;

  return (
    <>
      <div className="section-eyebrow pt-2">
        <span className="icoc" style={{ background: 'var(--chip-2)', color: 'var(--accent)' }}><Building2 /></span>
        <div>
          <h2 className="text-[17px] font-extrabold leading-none tracking-tight">Tổng theo team order</h2>
          <p className="text-[12.5px] text-sub mt-1.5">Số video mỗi bên order, chia theo editor phụ trách</p>
        </div>
      </div>
      
      <div className="card p-3 overflow-x-auto">
        <table className="ctable min-w-[620px]">
          <thead>
            <tr>
              <th>Team Order</th>
              {editors.map((e) => (
                <th key={e.id} className="text-center" style={{ width: '96px' }}>{e.short}</th>
              ))}
              <th className="text-center" style={{ width: '88px' }}>Tổng</th>
              <th style={{ width: '190px' }}>Tỉ trọng</th>
            </tr>
          </thead>
          <tbody>
            {activeTeams.map((o) => (
              <tr key={o.t}>
                <td><span className="mini-chip" style={{ fontWeight: 800, color: 'var(--text)' }}>{o.t}</span></td>
                {o.perEditor.map((n, idx) => (
                  <td 
                    key={idx} 
                    className={`text-center ${n ? 'font-bold' : ''}`} 
                    style={{ color: n ? editors[idx].color : 'var(--muted)' }}
                  >
                    {n || '-'}
                  </td>
                ))}
                <td className="text-center font-extrabold th-total">{o.n}</td>
                <td>
                  <div className="bar-track">
                    <div className="bar-fill" style={{ width: `${Math.round((o.n / maxN) * 100)}%` }}></div>
                  </div>
                </td>
              </tr>
            ))}
            <tr className="total">
              <td className="font-extrabold">Tổng cộng</td>
              {editors.map((e) => (
                <td key={e.id} className="text-center font-extrabold" style={{ color: e.color }}>
                  {tasks.filter((v) => v.editorId === e.id).length}
                </td>
              ))}
              <td className="text-center font-extrabold th-total">{totalTasks}</td>
              <td></td>
            </tr>
          </tbody>
        </table>
      </div>
    </>
  );
}
