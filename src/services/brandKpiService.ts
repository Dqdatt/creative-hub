import { supabase, supabaseConfigError } from '../lib/supabase';

export interface BrandKpiTarget {
  monthValue: string;
  longVideos: number;
  motion: number;
}

interface BrandKpiTargetRow {
  month_value: string;
  long_videos_target: number;
  motion_target: number;
}

function requireSupabase() {
  if (!supabase) {
    throw new Error(supabaseConfigError ? 'Kết nối dữ liệu chưa sẵn sàng. Vui lòng liên hệ quản trị viên.' : 'Kết nối dữ liệu chưa sẵn sàng.');
  }
  return supabase;
}

// Bảng do supabase/brand_kpi_target_patch.sql tạo ra. Chưa chạy patch thì đọc
// trả về null thay vì ném lỗi, để dashboard vẫn hiện được phần đếm tự động.
function isMissingTable(error: { message?: string; code?: string } | null) {
  if (!error) return false;
  const message = (error.message ?? '').toLowerCase();
  return error.code === '42P01' || message.includes('brand_kpi_targets');
}

function mapError(error: { message?: string; code?: string } | null) {
  if (!error) return 'Không thể xử lý KPI. Vui lòng thử lại.';

  const message = (error.message ?? '').toLowerCase();
  if (error.code === '42501' || message.includes('row-level security') || message.includes('permission denied')) {
    return 'Bạn không có quyền sửa KPI.';
  }
  if (message.includes('failed to fetch') || message.includes('network')) {
    return 'Không thể kết nối máy chủ. Vui lòng kiểm tra mạng.';
  }
  if (message.includes('brand_kpi_targets_non_negative_check')) {
    return 'Chỉ tiêu KPI không được là số âm.';
  }
  if (message.includes('brand_kpi_targets_month_value_check')) {
    return 'Tháng của KPI chưa hợp lệ.';
  }
  if (isMissingTable(error)) {
    return 'Chưa chạy supabase/brand_kpi_target_patch.sql trên Supabase.';
  }

  return error.message || 'Không thể xử lý KPI. Vui lòng thử lại.';
}

function mapRow(row: BrandKpiTargetRow): BrandKpiTarget {
  return {
    monthValue: row.month_value,
    longVideos: row.long_videos_target,
    motion: row.motion_target,
  };
}

export async function fetchBrandKpiTarget(monthValue: string): Promise<BrandKpiTarget | null> {
  const client = requireSupabase();
  const { data, error } = await client
    .from('brand_kpi_targets')
    .select('month_value, long_videos_target, motion_target')
    .eq('month_value', monthValue)
    .maybeSingle();

  if (error) {
    if (isMissingTable(error)) return null;
    throw new Error(mapError(error));
  }

  return data ? mapRow(data as BrandKpiTargetRow) : null;
}

function validateCount(value: number, label: string) {
  if (!Number.isInteger(value) || value < 0) {
    throw new Error(`${label} phải là số nguyên không âm.`);
  }
  return value;
}

export async function saveBrandKpiTarget(
  target: BrandKpiTarget,
  userId?: string | null,
): Promise<BrandKpiTarget> {
  const client = requireSupabase();
  const payload = {
    month_value: target.monthValue,
    long_videos_target: validateCount(target.longVideos, 'Chỉ tiêu video dài'),
    motion_target: validateCount(target.motion, 'Chỉ tiêu motion'),
    updated_by: userId ?? null,
  };

  const { data, error } = await client
    .from('brand_kpi_targets')
    .upsert(payload, { onConflict: 'month_value' })
    .select('month_value, long_videos_target, motion_target')
    .single();

  if (error) throw new Error(mapError(error));

  return mapRow(data as BrandKpiTargetRow);
}

// Xóa hẳn chỉ tiêu của tháng: dashboard quay về chỉ hiện số đếm được.
export async function clearBrandKpiTarget(monthValue: string) {
  const client = requireSupabase();
  const { error } = await client
    .from('brand_kpi_targets')
    .delete()
    .eq('month_value', monthValue);

  if (error) throw new Error(mapError(error));
}
