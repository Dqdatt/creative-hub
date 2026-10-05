import type { VideoTask } from '../types/task';
import { displayDateToLocalDate, startOfToday } from './month';

// Trạng thái deadline, áp dụng cho toàn bộ task chứ không riêng task liên kết.
// Hạn chót = Ngày Air + 1 ngày làm việc (bỏ qua T7, CN), ví dụ air T6 thì hạn
// chót là T2 tuần sau.
// - on-time      : đã xong và mốc hoàn thành không vượt hạn chót.
// - late         : đã xong nhưng hoàn thành sau hạn chót.
// - running-late : chưa xong và hạn chót đã qua.
// - in-progress  : chưa xong, còn hạn.
// - unknown      : thiếu Ngày Air, hoặc đã xong nhưng không có mốc hoàn thành
//                  (dữ liệu cũ trước khi có cột completed_at).
export type TaskDeadlineState = 'on-time' | 'late' | 'running-late' | 'in-progress' | 'unknown';

const MS_PER_DAY = 86_400_000;

function startOfDay(date: Date) {
  const copy = new Date(date);
  copy.setHours(0, 0, 0, 0);
  return copy;
}

// Số ngày làm việc được phép thêm Link thành phẩm sau Ngày Air.
const GRACE_WORKING_DAYS = 1;

function isWeekend(date: Date) {
  const day = date.getDay();
  return day === 0 || day === 6;
}

// Hạn chót = ngày gốc + GRACE_WORKING_DAYS ngày làm việc. Trả null khi ngày
// gốc trống hoặc không hợp lệ để nơi gọi xếp task vào nhóm chưa rõ mốc.
function getDeadlineDate(value: string | undefined | null, monthValue: string) {
  const baseDate = displayDateToLocalDate(value, monthValue);
  if (!baseDate || !Number.isFinite(baseDate.getTime())) return null;

  const deadline = startOfDay(baseDate);
  let remaining = GRACE_WORKING_DAYS;
  while (remaining > 0) {
    deadline.setDate(deadline.getDate() + 1);
    if (!isWeekend(deadline)) remaining -= 1;
  }
  return deadline;
}

function diffInDays(later: Date, earlier: Date) {
  return Math.round((startOfDay(later).getTime() - startOfDay(earlier).getTime()) / MS_PER_DAY);
}

export function getTaskDeadlineState(
  task: VideoTask,
  monthValue: string,
  today = startOfToday(),
): TaskDeadlineState {
  const deadline = getDeadlineDate(task.airDate, monthValue);
  if (!deadline) return 'unknown';

  if (task.status === 'Đã xong') {
    if (!task.completedAt) return 'unknown';

    const completedAt = new Date(task.completedAt);
    if (!Number.isFinite(completedAt.getTime())) return 'unknown';

    // Hoàn thành trong ngày hạn chót vẫn là đúng hạn, chỉ sau đó mới tính trễ.
    return diffInDays(completedAt, deadline) > 0 ? 'late' : 'on-time';
  }

  return diffInDays(today, deadline) > 0 ? 'running-late' : 'in-progress';
}

// Trễ deadline gộp hai trường hợp: đã xong sau hạn chót, và chưa xong khi hạn
// chót đã qua. Cả hai đều là lỡ hạn air nên báo cáo chung một con số.
export function isLateTask(task: VideoTask, monthValue: string, today = startOfToday()) {
  const state = getTaskDeadlineState(task, monthValue, today);
  return state === 'late' || state === 'running-late';
}

// Trễ hạn trả = chưa xong mà Ngày trả (hoặc Ngày Air nếu trống Ngày trả) cộng
// thêm 1 ngày làm việc đã qua.
export function isOverdueTask(task: VideoTask, monthValue: string, today = startOfToday()) {
  if (task.status === 'Đã xong') return false;
  const deadline = getDeadlineDate(task.returnDate || task.airDate, monthValue);
  return Boolean(deadline && diffInDays(today, deadline) > 0);
}

/** Hạn chót thêm Link thành phẩm (Ngày Air + 1 ngày làm việc), để hiển thị. */
export function getTaskLinkDeadline(task: VideoTask, monthValue: string) {
  return getDeadlineDate(task.airDate, monthValue);
}
