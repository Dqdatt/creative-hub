import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const allowedRoles = new Set([
  "admin",
  "creative_manager",
  "content_creator",
  "editor",
]);

function jsonResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}

function cleanText(value: unknown) {
  return typeof value === "string" ? value.trim() : "";
}

function getBearerToken(req: Request) {
  const authHeader =
    req.headers.get("Authorization") ?? req.headers.get("authorization") ?? "";
  const match = authHeader.match(/^Bearer\s+(.+)$/i);
  return match?.[1]?.trim() ?? "";
}

async function handleCreateUser(req: Request) {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "Phương thức không được hỗ trợ." }, 405);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceRoleKey =
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? Deno.env.get("SERVICE_ROLE_KEY");

  if (!supabaseUrl || !supabaseAnonKey || !serviceRoleKey) {
    return jsonResponse(
      { error: "Thiếu cấu hình Supabase Edge Function." },
      500,
    );
  }

  const token = getBearerToken(req);
  if (!token) {
    return jsonResponse({ error: "Thiếu Authorization bearer token." }, 401);
  }

  const userClient = createClient(supabaseUrl, supabaseAnonKey, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
  });
  const adminClient = createClient(supabaseUrl, serviceRoleKey, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
  });

  const { data: callerData, error: callerError } =
    await userClient.auth.getUser(token);
  if (callerError || !callerData.user) {
    return jsonResponse({ error: "Phiên đăng nhập không hợp lệ." }, 401);
  }

  const { data: callerProfile, error: profileError } = await adminClient
    .from("profiles")
    .select("role")
    .eq("id", callerData.user.id)
    .maybeSingle();

  if (profileError) {
    return jsonResponse({ error: "Không thể kiểm tra quyền admin." }, 500);
  }

  if (callerProfile?.role !== "admin") {
    return jsonResponse({ error: "Bạn không có quyền tạo thành viên." }, 403);
  }

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "Dữ liệu gửi lên không hợp lệ." }, 400);
  }

  const email = cleanText(body.email).toLowerCase();
  const password = cleanText(body.password);
  const fullName = cleanText(body.full_name);
  const displayName = cleanText(body.display_name) || fullName;
  const role = cleanText(body.role);
  const department = cleanText(body.department) || "Team Marketing";
  const phone = cleanText(body.phone);
  const editorCode = cleanText(body.editor_code).toLowerCase();
  const crewKey = cleanText(body.crew_key).toUpperCase();
  const isEditorMember = body.is_editor_member === true;

  if (!email) return jsonResponse({ error: "Vui lòng nhập email." }, 400);
  if (!password) return jsonResponse({ error: "Vui lòng nhập mật khẩu." }, 400);
  if (!fullName) return jsonResponse({ error: "Vui lòng nhập họ tên." }, 400);
  if (!role) return jsonResponse({ error: "Vui lòng chọn vai trò." }, 400);

  if (!allowedRoles.has(role)) {
    return jsonResponse({ error: "Vai trò không hợp lệ." }, 400);
  }

  if (password.length < 8) {
    return jsonResponse({ error: "Mật khẩu cần tối thiểu 8 ký tự." }, 400);
  }

  const { data: createdUserData, error: createUserError } =
    await adminClient.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: {
        full_name: fullName,
        display_name: displayName,
        role,
        department,
        phone,
      },
    });

  if (createUserError || !createdUserData.user) {
    return jsonResponse(
      {
        error: createUserError?.message || "Không thể tạo Auth user.",
      },
      400,
    );
  }

  const { error: upsertError } = await adminClient.from("profiles").upsert({
    id: createdUserData.user.id,
    email,
    full_name: fullName,
    short_name: displayName,
    display_name: displayName,
    phone: phone || null,
    department,
    role,
    editor_code: editorCode || null,
    crew_key: crewKey || null,
    is_editor_member: isEditorMember,
    active: true,
    is_active: true,
  });

  if (upsertError) {
    return jsonResponse(
      {
        error:
          upsertError.message ||
          "Đã tạo Auth user nhưng chưa cập nhật được profile.",
        user_id: createdUserData.user.id,
      },
      500,
    );
  }

  return jsonResponse({
    message: "Đã tạo thành viên.",
    user_id: createdUserData.user.id,
    email,
  });
}

Deno.serve(async (req) => {
  try {
    return await handleCreateUser(req);
  } catch (error) {
    console.error("create-user unexpected error:", error);
    return jsonResponse({ error: "Lỗi hệ thống khi tạo thành viên." }, 500);
  }
});
