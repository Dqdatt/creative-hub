import { CheckCircle2, Save } from 'lucide-react';
import type { IOSStateReturn } from '../hooks/useIOSState';
import { MOCK_TASKS, EDITORS, ORDER_TEAMS } from '../../data/tasks';
import { MOCK_SHOOTS } from '../../data/shoots';
import { MOCK_CONTENT_PLAN } from '../../data/contentPlan';

interface IOSSheetRendererProps {
  state: IOSStateReturn;
}

export function IOSSheetRenderer({ state }: IOSSheetRendererProps) {
  const { activeSheet, closeSheet, selectedTaskId, selectedShootId, selectedContentPlanId } = state;

  if (!activeSheet) return null;

  if (activeSheet === 'task_detail' || activeSheet === 'task_create') {
    const isCreate = activeSheet === 'task_create';
    const task = !isCreate ? MOCK_TASKS.find((t) => t.id === selectedTaskId) || MOCK_TASKS[0] : null;

    return {
      title: isCreate ? 'Thêm Video Task Mới' : `Chi tiết Task #${task?.id}`,
      content: (
        <form
          onSubmit={(e) => {
            e.preventDefault();
            closeSheet();
          }}
          className="space-y-4"
        >
          <div className="space-y-1">
            <label className="text-[11px] font-bold text-[var(--text)]">Tên Video / Tiêu đề Task</label>
            <input
              type="text"
              defaultValue={task ? task.name : 'Video Motion Shopee Sale'}
              className="w-full p-2.5 bg-[var(--chip)] text-xs font-semibold rounded-xl text-[var(--text)] border border-[var(--border)]"
              required
            />
          </div>

          <div className="grid grid-cols-2 gap-2">
            <div className="space-y-1">
              <label className="text-[11px] font-bold text-[var(--text)]">Editor phụ trách</label>
              <select
                defaultValue={task ? task.editorId : 'minh'}
                className="w-full p-2.5 bg-[var(--chip)] text-xs font-semibold rounded-xl text-[var(--text)] border border-[var(--border)]"
              >
                {EDITORS.map((e) => (
                  <option key={e.id} value={e.id}>
                    {e.shortName}
                  </option>
                ))}
              </select>
            </div>

            <div className="space-y-1">
              <label className="text-[11px] font-bold text-[var(--text)]">Trạng thái</label>
              <select
                defaultValue={task ? task.status : 'Đang làm'}
                className="w-full p-2.5 bg-[var(--chip)] text-xs font-semibold rounded-xl text-[var(--text)] border border-[var(--border)]"
              >
                <option value="Đang làm">Đang làm</option>
                <option value="Đã xong">Đã xong</option>
                <option value="Chờ">Chờ</option>
              </select>
            </div>
          </div>

          <div className="grid grid-cols-2 gap-2">
            <div className="space-y-1">
              <label className="text-[11px] font-bold text-[var(--text)]">Phòng ban (Order)</label>
              <select
                defaultValue={task ? task.orderTeam : 'ECOM'}
                className="w-full p-2.5 bg-[var(--chip)] text-xs font-semibold rounded-xl text-[var(--text)] border border-[var(--border)]"
              >
                {ORDER_TEAMS.map((t) => (
                  <option key={t} value={t}>
                    {t}
                  </option>
                ))}
              </select>
            </div>

            <div className="space-y-1">
              <label className="text-[11px] font-bold text-[var(--text)]">Thể loại</label>
              <input
                type="text"
                defaultValue={task ? task.category : 'Motion'}
                className="w-full p-2.5 bg-[var(--chip)] text-xs font-semibold rounded-xl text-[var(--text)] border border-[var(--border)]"
              />
            </div>
          </div>

          <div className="grid grid-cols-3 gap-2">
            <div className="space-y-1">
              <label className="text-[10px] font-bold text-[var(--text-2)]">Ngày nhận</label>
              <input
                type="text"
                defaultValue={task?.receiveDate || '01/07'}
                className="w-full p-2 bg-[var(--chip)] text-[11px] font-mono rounded-lg text-[var(--text)] border border-[var(--border)]"
              />
            </div>
            <div className="space-y-1">
              <label className="text-[10px] font-bold text-[var(--text-2)]">Ngày trả</label>
              <input
                type="text"
                defaultValue={task?.returnDate || '05/07'}
                className="w-full p-2 bg-[var(--chip)] text-[11px] font-mono rounded-lg text-[var(--text)] border border-[var(--border)]"
              />
            </div>
            <div className="space-y-1">
              <label className="text-[10px] font-bold text-[var(--text-2)]">Ngày Air</label>
              <input
                type="text"
                defaultValue={task?.airDate || '07/07'}
                className="w-full p-2 bg-[var(--chip)] text-[11px] font-mono rounded-lg text-[var(--text)] border border-[var(--border)]"
              />
            </div>
          </div>

          <button
            type="submit"
            className="w-full py-3 bg-[var(--accent)] text-white font-extrabold text-xs rounded-xl shadow-md flex items-center justify-center gap-1.5 active:scale-95 transition-transform"
          >
            <Save className="w-4 h-4" />
            <span>{isCreate ? 'Lưu Task Mới' : 'Cập nhật thay đổi'}</span>
          </button>
        </form>
      ),
    };
  }

  if (activeSheet === 'shoot_detail' || activeSheet === 'shoot_create') {
    const isCreate = activeSheet === 'shoot_create';
    const shoot = !isCreate ? MOCK_SHOOTS.find((s) => s.id === selectedShootId) || MOCK_SHOOTS[0] : null;

    return {
      title: isCreate ? 'Tạo Buổi Quay Mới' : `Lịch Quay Ngày ${shoot?.date.split('-')[2]}/07`,
      content: (
        <form
          onSubmit={(e) => {
            e.preventDefault();
            closeSheet();
          }}
          className="space-y-4"
        >
          <div className="space-y-1">
            <label className="text-[11px] font-bold text-[var(--text)]">Địa điểm quay</label>
            <input
              type="text"
              defaultValue={shoot ? shoot.place : 'SHOWROOM HÒA BÌNH'}
              className="w-full p-2.5 bg-[var(--chip)] text-xs font-semibold rounded-xl text-[var(--text)] border border-[var(--border)]"
              required
            />
          </div>

          <div className="grid grid-cols-2 gap-2">
            <div className="space-y-1">
              <label className="text-[11px] font-bold text-[var(--text)]">Loại lịch quay</label>
              <select
                defaultValue={shoot ? shoot.type : 'lichquay'}
                className="w-full p-2.5 bg-[var(--chip)] text-xs font-semibold rounded-xl text-[var(--text)] border border-[var(--border)]"
              >
                <option value="livestream">Livestream</option>
                <option value="lichquay">Lịch quay</option>
                <option value="onset">On set</option>
                <option value="other">Khác</option>
              </select>
            </div>

            <div className="space-y-1">
              <label className="text-[11px] font-bold text-[var(--text)]">Thời gian (Ca quay)</label>
              <input
                type="text"
                defaultValue={shoot ? shoot.time : 'ALL MORNING'}
                className="w-full p-2.5 bg-[var(--chip)] text-xs font-semibold rounded-xl text-[var(--text)] border border-[var(--border)]"
              />
            </div>
          </div>

          <div className="space-y-1">
            <label className="text-[11px] font-bold text-[var(--text)]">Êkíp / Nhân sự tham gia</label>
            <input
              type="text"
              defaultValue={shoot ? shoot.crew : 'ĐẠT - HẢI - BUMI'}
              className="w-full p-2.5 bg-[var(--chip)] text-xs font-semibold rounded-xl text-[var(--text)] border border-[var(--border)]"
            />
          </div>

          <div className="space-y-1">
            <label className="text-[11px] font-bold text-[var(--text)]">Nội dung ghi chú</label>
            <textarea
              rows={3}
              defaultValue={shoot ? shoot.note : 'Quay kịch bản Chạm vào an yên tập 9 & review nệm mới'}
              className="w-full p-2.5 bg-[var(--chip)] text-xs font-medium rounded-xl text-[var(--text)] border border-[var(--border)]"
            />
          </div>

          <button
            type="submit"
            className="w-full py-3 bg-[var(--accent)] text-white font-extrabold text-xs rounded-xl shadow-md flex items-center justify-center gap-1.5 active:scale-95 transition-transform"
          >
            <Save className="w-4 h-4" />
            <span>{isCreate ? 'Tạo Buổi Quay' : 'Cập nhật Lịch Quay'}</span>
          </button>
        </form>
      ),
    };
  }

  if (activeSheet === 'content_plan_detail') {
    const item = MOCK_CONTENT_PLAN.find((c) => c.id === selectedContentPlanId) || MOCK_CONTENT_PLAN[0];

    return {
      title: 'Chi tiết Kịch bản Content',
      content: (
        <div className="space-y-4">
          <div className="space-y-1">
            <span className="text-[10px] font-bold text-purple-600 dark:text-purple-400 bg-purple-500/10 px-2 py-0.5 rounded-full">
              Thể loại: {item.category}
            </span>
            <h3 className="text-sm font-extrabold text-[var(--text)] mt-1">{item.video_name}</h3>
          </div>

          <div className="p-3 bg-[var(--chip)] rounded-xl space-y-1 text-xs text-[var(--text-2)]">
            <span className="font-bold text-[var(--text)]">Ghi chú kịch bản:</span>
            <p className="italic">{item.note || 'Không có ghi chú thêm.'}</p>
          </div>

          <div className="space-y-2">
            <label className="text-[11px] font-bold text-[var(--text)]">Phân công Editor dựng clip</label>
            <select
              defaultValue={item.editor_id || 'dat'}
              className="w-full p-2.5 bg-[var(--chip)] text-xs font-semibold rounded-xl text-[var(--text)] border border-[var(--border)]"
            >
              {EDITORS.map((e) => (
                <option key={e.id} value={e.id}>
                  {e.shortName} ({e.role})
                </option>
              ))}
            </select>
          </div>

          <button
            onClick={() => closeSheet()}
            className="w-full py-3 bg-[var(--accent)] text-white font-extrabold text-xs rounded-xl shadow-md flex items-center justify-center gap-1.5 active:scale-95 transition-transform"
          >
            <CheckCircle2 className="w-4 h-4" />
            <span>Lưu phân công Editor</span>
          </button>
        </div>
      ),
    };
  }

  if (activeSheet === 'user_detail') {
    return {
      title: 'Thông tin Nhân sự',
      content: (
        <div className="space-y-4 text-xs">
          <div className="flex items-center gap-3 p-3 bg-[var(--chip)] rounded-2xl">
            <div className="w-12 h-12 rounded-full bg-sky-500 text-white flex items-center justify-center text-base font-bold shadow-xs">
              Đ
            </div>
            <div>
              <h3 className="font-extrabold text-sm text-[var(--text)]">Đoàn Quốc Đạt</h3>
              <p className="text-[11px] text-[var(--text-2)]">dat.dq@company.com</p>
              <span className="text-[10px] font-bold px-2 py-0.2 rounded-full bg-purple-500/15 text-purple-600 dark:text-purple-400 mt-1 inline-block">
                Admin / Video Editor
              </span>
            </div>
          </div>

          <div className="space-y-2">
            <label className="text-[11px] font-bold text-[var(--text)] font-sans">Cấp vai trò (Role)</label>
            <select className="w-full p-2.5 bg-[var(--chip)] text-xs font-semibold rounded-xl text-[var(--text)] border border-[var(--border)]">
              <option value="admin">Admin (Toàn quyền)</option>
              <option value="creative_manager">Creative Manager</option>
              <option value="content_creator">Content Creator</option>
              <option value="editor">Video Editor</option>
            </select>
          </div>

          <button
            onClick={() => closeSheet()}
            className="w-full py-3 bg-[var(--accent)] text-white font-extrabold text-xs rounded-xl shadow-md flex items-center justify-center gap-1.5 active:scale-95 transition-transform"
          >
            <Save className="w-4 h-4" />
            <span>Lưu phân quyền</span>
          </button>
        </div>
      ),
    };
  }

  if (activeSheet === 'profile_edit' || activeSheet === 'password_edit') {
    const isPassword = activeSheet === 'password_edit';

    return {
      title: isPassword ? 'Đổi Mật Khẩu Cá Nhân' : 'Cập Nhật Hồ Sơ',
      content: (
        <form
          onSubmit={(e) => {
            e.preventDefault();
            closeSheet();
          }}
          className="space-y-4"
        >
          {isPassword ? (
            <>
              <div className="space-y-1">
                <label className="text-[11px] font-bold text-[var(--text)]">Mật khẩu hiện tại</label>
                <input
                  type="password"
                  placeholder="••••••••"
                  className="w-full p-2.5 bg-[var(--chip)] text-xs font-semibold rounded-xl text-[var(--text)] border border-[var(--border)]"
                  required
                />
              </div>
              <div className="space-y-1">
                <label className="text-[11px] font-bold text-[var(--text)]">Mật khẩu mới</label>
                <input
                  type="password"
                  placeholder="••••••••"
                  className="w-full p-2.5 bg-[var(--chip)] text-xs font-semibold rounded-xl text-[var(--text)] border border-[var(--border)]"
                  required
                />
              </div>
            </>
          ) : (
            <>
              <div className="space-y-1">
                <label className="text-[11px] font-bold text-[var(--text)]">Họ và tên hiển thị</label>
                <input
                  type="text"
                  defaultValue="Đoàn Quốc Đạt"
                  className="w-full p-2.5 bg-[var(--chip)] text-xs font-semibold rounded-xl text-[var(--text)] border border-[var(--border)]"
                  required
                />
              </div>
              <div className="space-y-1">
                <label className="text-[11px] font-bold text-[var(--text)]">Chức danh / Role</label>
                <input
                  type="text"
                  defaultValue="Video Editor & Admin"
                  className="w-full p-2.5 bg-[var(--chip)] text-xs font-semibold rounded-xl text-[var(--text)] border border-[var(--border)]"
                />
              </div>
            </>
          )}

          <button
            type="submit"
            className="w-full py-3 bg-[var(--accent)] text-white font-extrabold text-xs rounded-xl shadow-md flex items-center justify-center gap-1.5 active:scale-95 transition-transform"
          >
            <Save className="w-4 h-4" />
            <span>Cập nhật thông tin</span>
          </button>
        </form>
      ),
    };
  }

  if (activeSheet === 'more_menu') {
    return {
      title: 'Thông báo & Phím tắt',
      content: (
        <div className="space-y-3 text-xs">
          <div className="p-3 bg-[var(--chip)] rounded-xl space-y-2">
            <h4 className="font-bold text-[var(--text)]">Thông báo mới nhất (2)</h4>
            <div className="space-y-1.5 text-[11.5px] text-[var(--text-2)]">
              <div className="flex items-start gap-2">
                <span className="w-2 h-2 rounded-full bg-blue-500 shrink-0 mt-1"></span>
                <p>Bạn vừa được phân công dựng video <strong>"Review IKI Premium"</strong></p>
              </div>
              <div className="flex items-start gap-2">
                <span className="w-2 h-2 rounded-full bg-amber-500 shrink-0 mt-1"></span>
                <p>Lịch quay ngày 08/07 tại Showroom Hòa Bình đã được cập nhật êkíp.</p>
              </div>
            </div>
          </div>

          <button
            onClick={() => closeSheet()}
            className="w-full py-2.5 bg-[var(--chip)] text-[var(--text)] font-bold text-xs rounded-xl hover:bg-[var(--chip-2)] transition-colors"
          >
            Đóng bảng thông báo
          </button>
        </div>
      ),
    };
  }

  return null;
}
