import { Users } from 'lucide-react';
import type { Editor, VideoTask } from '../../types/task';
import type { ShootSchedule } from '../../types/shoot';
import { Avatar } from '../common/Avatar';

interface EditorWorkloadProps {
  editors: Editor[];
  tasks: VideoTask[];
  shoots: ShootSchedule[];
}

function resizeCount(r?: string) {
  if (!r) return 0;
  return r.split('&').filter((x) => x.trim()).length;
}

export function EditorWorkload({ editors, tasks, shoots }: EditorWorkloadProps) {
  return (
    <>
      <div className="section-eyebrow pt-2">
        <span className="icoc" style={{ background: 'var(--chip-2)', color: 'var(--accent)' }}><Users /></span>
        <div>
          <h2 className="text-[17px] font-extrabold leading-none tracking-tight">Task theo từng người</h2>
          <p className="text-[12.5px] text-sub mt-1.5">
            {editors.length > 0 ? editors.map((editor) => editor.name).join(' · ') : 'Chưa có thành viên team editor'}
          </p>
        </div>
      </div>
      
      <div className="grid gap-5 lg:grid-cols-3">
        {editors.map((editor) => {
          const editorTasks = tasks.filter((t) => t.editorId === editor.id);
          const dai = editorTasks.filter((t) => t.category === 'Video dài').length;
          const motion = editorTasks.filter((t) => t.category === 'Motion').length;
          const ads = editorTasks.filter((t) => t.category === 'Ads').length;
          const resize = editorTasks.reduce((acc, t) => acc + resizeCount(t.resize), 0);
          const editorShootKey = editor.profileId || editor.id;
          const editorShoots = shoots.filter((s) =>
            (s.editorProfileIds.includes(editorShootKey) || s.editorIds.includes(editor.id))
          );
          const totalTasks = editorTasks.length + editorShoots.length;

          return (
            <div key={editor.id} className="card card-h overflow-hidden flex flex-col">
              <div 
                className="p-5 flex items-center gap-3.5" 
                style={{ background: `linear-gradient(130deg, color-mix(in srgb, ${editor.color} 22%, transparent), transparent 75%)` }}
              >
                <Avatar
                  src={editor.avatarUrl}
                  name={editor.short || editor.name || editor.initial}
                  color={editor.color}
                  size="lg"
                  shape="rounded"
                  alt={editor.short}
                />
                <div className="min-w-0">
                  <div className="font-extrabold text-[15px] truncate">{editor.name}</div>
                  <div className="text-[12px] font-semibold" style={{ color: editor.color }}>{editor.role}</div>
                </div>
                <div className="ml-auto text-right shrink-0">
                  <div className="text-[30px] font-extrabold leading-none" style={{ color: editor.color }}>{totalTasks}</div>
                  <div className="text-[11px] text-sub mt-0.5">tổng task</div>
                </div>
              </div>

              <div className="px-5 pt-2 pb-4">
                <div className="stat-row">
                  <span className="text-sub font-medium">Video dài</span><span className="font-bold tabular-nums">{dai}</span>
                </div>
                <div className="stat-row">
                  <span className="text-sub font-medium">Motion</span><span className="font-bold tabular-nums">{motion}</span>
                </div>
                <div className="stat-row">
                  <span className="text-sub font-medium">Ads</span><span className="font-bold tabular-nums">{ads}</span>
                </div>
                <div className="stat-row hl">
                  <span className="text-sub font-medium">Resize</span><span className="font-bold tabular-nums">{resize}</span>
                </div>
                <div className="stat-row">
                  <span className="text-sub font-medium">Buổi quay</span><span className="font-bold tabular-nums">{editorShoots.length}</span>
                </div>
              </div>
            </div>
          );
        })}
      </div>
    </>
  );
}
