import { createClient } from '@supabase/supabase-js';
import type { SupabaseClient } from '@supabase/supabase-js';

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY;

function validateSupabaseConfig(url: string | undefined, anonKey: string | undefined) {
  if (!url && !anonKey) {
    return 'Chưa cấu hình kết nối dữ liệu. Vui lòng kiểm tra file .env.';
  }
  if (!url || !anonKey) return 'Chưa cấu hình đầy đủ kết nối dữ liệu. Vui lòng kiểm tra file .env.';
  if (url.includes('your-project') || anonKey.includes('your-anon-key')) {
    return 'Thông tin kết nối dữ liệu vẫn đang là giá trị mẫu.';
  }

  try {
    const parsedUrl = new URL(url);
    if (!['http:', 'https:'].includes(parsedUrl.protocol)) {
      return 'Địa chỉ kết nối dữ liệu không hợp lệ.';
    }
  } catch {
    return 'Địa chỉ kết nối dữ liệu không đúng định dạng.';
  }

  if (anonKey.trim().length < 20) {
    return 'Khóa kết nối dữ liệu không hợp lệ.';
  }

  return null;
}

export const supabaseConfigError = validateSupabaseConfig(supabaseUrl, supabaseAnonKey);

export const supabase: SupabaseClient | null = supabaseConfigError
  ? null
  : createClient(supabaseUrl, supabaseAnonKey, {
      auth: {
        persistSession: true,
        autoRefreshToken: true,
        detectSessionInUrl: true,
      },
    });
