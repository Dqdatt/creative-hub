import type { VideoTask } from '../types/task';
import { displayDateToLocalDate, startOfToday } from './month';

// Trạng thái deadline, áp dụng cho toàn bộ task chứ không riêng task liên kết:
// - on-time      : đã xong và mốc hoàn thành không vượt Ngày Air.
// - late         : đã xong nhưng hoàn thành sau Ngày Air.
// - running-late : chưa xong và Ngày Air đã qua.
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

function diffInDays(later: Date, earlier: Date) {
  return Math.round((startOfDay(later).getTime() - startOfDay(earlier).getTime()) / MS_PER_DAY);
}

export function getTaskDeadlineState(
  task: VideoTask,
  monthValue: string,
  today = startOfToday(),
): TaskDeadlineState {
  const airDate = displayDateToLocalDate(task.airDate, monthValue);
  if (!airDate) return 'unknown';

  if (task.status === 'Đã xong') {
    if (!task.completedAt) return 'unknown';

    const completedAt = new Date(task.completedAt);
    if (!Number.isFinite(completedAt.getTime())) return 'unknown';

    // Hoàn thành đúng Ngày Air vẫn là đúng hạn, chỉ sau đó mới tính trễ.
    return diffInDays(completedAt, airDate) > 0 ? 'late' : 'on-time';
  }

  return diffInDays(today, airDate) > 0 ? 'running-late' : 'in-progress';
}

// Trễ deadline gộp hai trường hợp: đã xong sau Ngày Air, và chưa xong khi Ngày
// Air đã qua. Cả hai đều là lỡ hạn air nên báo cáo chung một con số.
export function isLateTask(task: VideoTask, monthValue: string, today = startOfToday()) {
  const state = getTaskDeadlineState(task, monthValue, today);
  return state === 'late' || state === 'running-late';
}
