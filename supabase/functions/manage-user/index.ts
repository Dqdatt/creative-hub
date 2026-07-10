import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type ManageAction = "update_email" | "delete_user";
type SupabaseLikeError = {
  code?: string;
  message?: string;
  details?: string;
  hint?: string;
  status?: number;
  statusCode?: string;
  name?: string;
};

const AVATAR_BUCKET = "avatars";

function normalizeError(error: unknown) {
  if (error instanceof Error) {
    const extra = error as Error & {
      status?: unknown;
      code?: unknown;
      details?: unknown;
      hint?: unknown;
    };

    return {
      message: error.message || "Lỗi không xác định.",
      name: error.name,
      status: extra.status,
      code: extra.code,
      details: extra.details,
      hint: extra.hint,
    };
  }

  if (typeof error === "object" && error !== null) {
    const record = error as Record<string, unknown>;
    return {
      message: typeof record.message === "string" ? record.message : "Lỗi không xác định.",
      name: typeof record.name === "string" ? record.name : undefined,
      status: record.status,
      code: record.code,
      details: record.details,
      hint: record.hint,
    };
  }

  return { message: String(error) };
}

function readableMessage(value: unknown, fallback: string) {
  const message = typeof value === "string" ? value.trim() : "";
  if (!message || message === "{}") return fallback;
  return message;
}

function jsonResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}

function stepErrorResponse(
  step: string,
  userId: string,
  message: string,
  status: number,
  code: string,
  error?: SupabaseLikeError | null,
) {
  const normalized = normalizeError(error ?? { message, code });
  const normalizedCode = typeof normalized.code === "string"
    ? normalized.code
    : typeof normalized.code === "number"
      ? String(normalized.code)
      : error?.statusCode ?? code;
  const normalizedDetails = typeof normalized.details === "string" ? normalized.details : undefined;
  const normalizedHint = typeof normalized.hint === "string" ? normalized.hint : undefined;

  console.error("manage-user delete_user failed", {
    step,
    target_user_id: userId,
    code: normalizedCode,
    message: readableMessage(normalized.message, message),
    details: normalizedDetails ?? null,
    hint: normalizedHint ?? null,
    status: normalized.status ?? error?.status ?? null,
    name: normalized.name ?? null,
  });

  return jsonResponse({
    error: normalized.message && normalized.message !== "Lỗi không xác định."
      ? readableMessage(normalized.message, message)
      : message,
    code: normalizedCode,
    step,
    ...(normalizedDetails ? { details: normalizedDetails } : {}),
    ...(normalizedHint ? { hint: normalizedHint } : {}),
  }, status);
}

function validationError(step: string, message: string, status = 400, code = "validation_error") {
  return jsonResponse({ error: message, code, step }, status);
}

function cleanText(value: unknown) {
  return typeof value === "string" ? value.trim() : "";
}

function cleanEmail(value: unknown) {
  return cleanText(value).toLowerCase();
}

function isValidEmail(email: string) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}

function getBearerToken(req: Request) {
  const authHeader =
    req.headers.get("Authorization") ?? req.headers.get("authorization") ?? "";
  const match = authHeader.match(/^Bearer\s+(.+)$/i);
  return match?.[1]?.trim() ?? "";
}

function getConfig() {
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceRoleKey =
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? Deno.env.get("SERVICE_ROLE_KEY");

  if (!supabaseUrl || !supabaseAnonKey || !serviceRoleKey) {
    throw new Error("Thiếu cấu hình Supabase Edge Function.");
  }

  return { supabaseUrl, supabaseAnonKey, serviceRoleKey };
}

function createClients() {
  const { supabaseUrl, supabaseAnonKey, serviceRoleKey } = getConfig();

  return {
    userClient: createClient(supabaseUrl, supabaseAnonKey, {
      auth: {
        persistSession: false,
        autoRefreshToken: false,
      },
    }),
    adminClient: createClient(supabaseUrl, serviceRoleKey, {
      auth: {
        persistSession: false,
        autoRefreshToken: false,
      },
    }),
  };
}

async function getAdminCaller(req: Request) {
  const token = getBearerToken(req);
  if (!token) {
    return {
      error: jsonResponse({
        error: "Thiếu Authorization bearer token.",
        code: "missing_bearer_token",
        step: "authorize_admin",
      }, 401),
    };
  }

  const { userClient, adminClient } = createClients();
  const { data: callerData, error: callerError } =
    await userClient.auth.getUser(token);

  if (callerError || !callerData.user) {
    return {
      error: jsonResponse({
        error: "Phiên đăng nhập không hợp lệ.",
        code: "invalid_session",
        step: "authorize_admin",
      }, 401),
    };
  }

  const { data: callerProfile, error: profileError } = await adminClient
    .from("profiles")
    .select("id, role, is_active, active")
    .eq("id", callerData.user.id)
    .maybeSingle();

  if (profileError) {
    return {
      error: stepErrorResponse(
        "authorize_admin",
        callerData.user.id,
        "Không thể kiểm tra quyền admin.",
        500,
        "admin_profile_check_failed",
        profileError,
      ),
    };
  }

  if (callerProfile?.role !== "admin" || (callerProfile.is_active ?? callerProfile.active ?? true) === false) {
    return {
      error: jsonResponse({
        error: "Bạn không có quyền quản lý tài khoản.",
        code: "admin_required",
        step: "authorize_admin",
      }, 403),
    };
  }

  return {
    adminClient,
    caller: callerData.user,
  };
}

async function findAuthUserByEmail(adminClient: ReturnType<typeof createClient>, email: string) {
  let page = 1;

  while (page <= 10) {
    const { data, error } = await adminClient.auth.admin.listUsers({
      page,
      perPage: 1000,
    });

    if (error) throw error;

    const users = data.users ?? [];
    const found = users.find((user) => user.email?.toLowerCase() === email);
    if (found) return found;
    if (users.length < 1000) return null;
    page += 1;
  }

  return null;
}

async function logActivitySafely(
  adminClient: ReturnType<typeof createClient>,
  input: {
    actorId: string;
    entityId: string;
    action: "updated" | "deleted";
    title: string;
    description: string;
    metadata: Record<string, unknown>;
  },
) {
  try {
    await adminClient.from("activity_logs").insert({
      actor_id: input.actorId,
      entity_type: "profile",
      entity_id: input.entityId,
      action: input.action,
      title: input.title,
      description: input.description,
      metadata: input.metadata,
    });
  } catch (error) {
    console.error("manage-user activity log skipped:", error);
  }
}

async function handleUpdateEmail(body: Record<string, unknown>, req: Request) {
  const auth = await getAdminCaller(req);
  if ("error" in auth) return auth.error;

  const userId = cleanText(body.user_id);
  const email = cleanEmail(body.email);

  if (!userId) return jsonResponse({ error: "Thiếu mã thành viên." }, 400);
  if (!email) return jsonResponse({ error: "Vui lòng nhập email mới." }, 400);
  if (!isValidEmail(email)) return jsonResponse({ error: "Email chưa đúng định dạng." }, 400);

  const { adminClient, caller } = auth;

  const { data: targetProfile, error: targetProfileError } = await adminClient
    .from("profiles")
    .select("id, email, full_name, display_name, short_name, role")
    .eq("id", userId)
    .maybeSingle();

  if (targetProfileError) {
    return jsonResponse({ error: "Không thể kiểm tra hồ sơ thành viên." }, 500);
  }

  if (!targetProfile) {
    return jsonResponse({ error: "Không tìm thấy thành viên." }, 404);
  }

  const existingAuthUser = await findAuthUserByEmail(adminClient, email);
  if (existingAuthUser && existingAuthUser.id !== userId) {
    return jsonResponse({ error: "Email này đã được dùng cho tài khoản khác." }, 409);
  }

  const { data: existingProfile, error: existingProfileError } = await adminClient
    .from("profiles")
    .select("id")
    .ilike("email", email)
    .neq("id", userId)
    .maybeSingle();

  if (existingProfileError) {
    return jsonResponse({ error: "Không thể kiểm tra email trong hồ sơ." }, 500);
  }

  if (existingProfile) {
    return jsonResponse({ error: "Email này đã được dùng cho hồ sơ khác." }, 409);
  }

  const { data: updatedAuth, error: updateAuthError } =
    await adminClient.auth.admin.updateUserById(userId, { email });

  if (updateAuthError || !updatedAuth.user) {
    return jsonResponse(
      { error: updateAuthError?.message || "Không thể cập nhật email đăng nhập." },
      400,
    );
  }

  const { data: updatedProfile, error: updateProfileError } = await adminClient
    .from("profiles")
    .update({ email })
    .eq("id", userId)
    .select("id, email, full_name, display_name, short_name, role, department, is_active, active")
    .single();

  if (updateProfileError) {
    return jsonResponse(
      { error: "Auth email đã đổi nhưng chưa đồng bộ được profile. Vui lòng kiểm tra lại hồ sơ." },
      500,
    );
  }

  await logActivitySafely(adminClient, {
    actorId: caller.id,
    entityId: userId,
    action: "updated",
    title: updatedProfile.display_name || updatedProfile.short_name || updatedProfile.full_name || email,
    description: `Đã cập nhật email đăng nhập thành "${email}".`,
    metadata: {
      field: "email",
      previous_email: targetProfile.email,
      email,
    },
  });

  return jsonResponse({
    message: "Đã cập nhật email đăng nhập.",
    user: {
      id: updatedAuth.user.id,
      email: updatedAuth.user.email,
    },
    profile: updatedProfile,
  });
}

async function clearReference(
  adminClient: ReturnType<typeof createClient>,
  {
    table,
    column,
    userId,
  }: {
    table: string;
    column: string;
    userId: string;
  },
) {
  const step = `clear_${table}_${column}`;
  const { error } = await adminClient
    .from(table)
    .update({ [column]: null })
    .eq(column, userId);

  if (error) {
    return stepErrorResponse(
      step,
      userId,
      "Không thể dọn dữ liệu liên quan trước khi xóa tài khoản.",
      409,
      "reference_cleanup_failed",
      error,
    );
  }

  return null;
}

function isMissingAvatarBucketError(error: unknown) {
  const normalized = normalizeError(error);
  const code = typeof normalized.code === "string" ? normalized.code.toLowerCase() : "";
  const message = normalized.message.toLowerCase();
  const details = typeof normalized.details === "string" ? normalized.details.toLowerCase() : "";
  const codeLooksMissing = code.includes("nosuchbucket") ||
    code.includes("no_such_bucket") ||
    (code.includes("bucket") && code.includes("not"));

  return codeLooksMissing ||
    message.includes("bucket not found") ||
    message.includes("bucket does not exist") ||
    details.includes("bucket not found") ||
    details.includes("bucket does not exist");
}

async function deleteAvatarStorageObjects(adminClient: ReturnType<typeof createClient>, userId: string) {
  const listStep = "delete_avatar_list";
  const { data: avatarObjects, error: listError } = await adminClient.storage
    .from(AVATAR_BUCKET)
    .list(userId, {
      limit: 100,
      offset: 0,
      sortBy: { column: "name", order: "asc" },
    });

  if (listError) {
    if (isMissingAvatarBucketError(listError)) return null;

    return stepErrorResponse(
      listStep,
      userId,
      "Không thể kiểm tra ảnh đại diện trước khi xóa tài khoản.",
      409,
      "avatar_list_failed",
      listError,
    );
  }

  const paths = (avatarObjects ?? [])
    .filter((item) => item.name && item.name !== ".emptyFolderPlaceholder")
    .map((item) => `${userId}/${item.name}`);

  if (!paths.length) return null;

  const { error: removeError } = await adminClient.storage
    .from(AVATAR_BUCKET)
    .remove(paths);

  if (removeError) {
    return stepErrorResponse(
      "delete_avatar_remove",
      userId,
      "Không thể xóa ảnh đại diện của tài khoản.",
      409,
      "avatar_remove_failed",
      removeError,
    );
  }

  return null;
}

async function cleanupUserRelations(adminClient: ReturnType<typeof createClient>, userId: string) {
  const shootEditorsStep = "delete_shoot_editors";
  const { error: shootEditorsError } = await adminClient
    .from("shoot_editors")
    .delete()
    .eq("profile_id", userId);

  if (shootEditorsError) {
    return stepErrorResponse(
      shootEditorsStep,
      userId,
      "Không thể xóa phân công editor trong lịch quay.",
      409,
      "shoot_editors_cleanup_failed",
      shootEditorsError,
    );
  }

  const references = [
    ["video_tasks", "editor_id"],
    ["video_tasks", "created_by"],
    ["video_tasks", "updated_by"],
    ["shoots", "created_by"],
    ["shoots", "updated_by"],
    ["content_plan", "editor_id"],
    ["content_plan", "created_by"],
    ["content_plan", "updated_by"],
    ["activity_logs", "actor_id"],
  ] as const;

  for (const [table, column] of references) {
    const errorResponse = await clearReference(adminClient, { table, column, userId });
    if (errorResponse) return errorResponse;
  }

  return null;
}

async function handleDeleteUser(body: Record<string, unknown>, req: Request) {
  const auth = await getAdminCaller(req);
  if ("error" in auth) return auth.error;

  const userId = cleanText(body.user_id);
  if (!userId) return validationError("validate_payload", "Thiếu mã thành viên.");

  const { adminClient, caller } = auth;

  if (userId === caller.id) {
    return validationError(
      "prevent_current_admin_delete",
      "Không thể xóa tài khoản admin đang đăng nhập.",
      403,
      "current_admin_delete_blocked",
    );
  }

  const loadProfileStep = "load_target_profile";
  const { data: targetProfile, error: targetProfileError } = await adminClient
    .from("profiles")
    .select("id, email, full_name, display_name, short_name, role, is_active, active")
    .eq("id", userId)
    .maybeSingle();

  if (targetProfileError) {
    return stepErrorResponse(
      loadProfileStep,
      userId,
      "Không thể kiểm tra hồ sơ thành viên.",
      500,
      "target_profile_load_failed",
      targetProfileError,
    );
  }

  if (!targetProfile) {
    return validationError("load_target_profile", "Không tìm thấy thành viên.", 404, "target_profile_not_found");
  }

  if (targetProfile.role === "admin") {
    const lastAdminStep = "prevent_last_active_admin_delete";
    const { data: adminRows, error: adminCountError } = await adminClient
      .from("profiles")
      .select("id, is_active, active")
      .eq("role", "admin");

    if (adminCountError) {
      return stepErrorResponse(
        lastAdminStep,
        userId,
        "Không thể kiểm tra số lượng admin.",
        500,
        "active_admin_count_failed",
        adminCountError,
      );
    }

    const activeAdminCount = (adminRows ?? []).filter((admin) => admin.is_active ?? admin.active ?? true).length;
    if (activeAdminCount <= 1) {
      return validationError(
        lastAdminStep,
        "Không thể xóa admin hoạt động cuối cùng.",
        409,
        "last_active_admin_delete_blocked",
      );
    }
  }

  const title =
    targetProfile.display_name ||
    targetProfile.short_name ||
    targetProfile.full_name ||
    targetProfile.email ||
    "Thành viên";

  await logActivitySafely(adminClient, {
    actorId: caller.id,
    entityId: userId,
    action: "deleted",
    title,
    description: `Đã xóa vĩnh viễn tài khoản "${title}".`,
    metadata: {
      email: targetProfile.email,
      role: targetProfile.role,
    },
  });

  const storageError = await deleteAvatarStorageObjects(adminClient, userId);
  if (storageError) return storageError;

  const cleanupError = await cleanupUserRelations(adminClient, userId);
  if (cleanupError) return cleanupError;

  const deleteAuthStep = "delete_auth_user";
  const { data: authUserData, error: getAuthUserError } = await adminClient.auth.admin.getUserById(userId);

  if (getAuthUserError || !authUserData.user) {
    const normalized = normalizeError(getAuthUserError ?? { message: "Không tìm thấy Auth user." });
    const normalizedStatus = Number(normalized.status);
    const isNotFound = normalizedStatus === 404 || normalized.message.toLowerCase().includes("not found");
    return stepErrorResponse(
      deleteAuthStep,
      userId,
      "Không tìm thấy Auth user.",
      isNotFound ? 404 : 500,
      isNotFound ? "auth_user_not_found" : "auth_user_lookup_failed",
      getAuthUserError,
    );
  }

  const { error: deleteAuthError } = await adminClient.auth.admin.deleteUser(userId, false);

  if (deleteAuthError) {
    const normalized = normalizeError(deleteAuthError);
    const normalizedStatus = Number(normalized.status);
    const normalizedMessage = normalized.message.toLowerCase();
    const conflictLike = normalizedStatus === 409 ||
      normalizedMessage.includes("conflict") ||
      normalizedMessage.includes("foreign key") ||
      normalizedMessage.includes("constraint") ||
      normalizedMessage.includes("storage");

    return stepErrorResponse(
      deleteAuthStep,
      userId,
      readableMessage(normalized.message, "Không thể xóa Auth user."),
      conflictLike ? 409 : 500,
      typeof normalized.code === "string" ? normalized.code : "AUTH_DELETE_CONFLICT",
      deleteAuthError,
    );
  }

  const verifyStep = "verify_profile_deleted";
  const { data: remainingProfile, error: verifyProfileError } = await adminClient
    .from("profiles")
    .select("id")
    .eq("id", userId)
    .maybeSingle();

  if (verifyProfileError) {
    return stepErrorResponse(
      verifyStep,
      userId,
      "Đã xóa Auth user nhưng chưa thể xác minh profile.",
      500,
      "profile_verify_failed",
      verifyProfileError,
    );
  }

  if (remainingProfile) {
    return stepErrorResponse(
      verifyStep,
      userId,
      "Auth user đã xóa nhưng profile chưa được cascade. Vui lòng kiểm tra khóa ngoại profiles.",
      409,
      "profile_cascade_missing",
    );
  }

  return jsonResponse({
    message: "Đã xóa tài khoản.",
    step: "delete_complete",
    user_id: userId,
  });
}

async function handleManageUser(req: Request) {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "Phương thức không được hỗ trợ.", code: "method_not_allowed", step: "validate_request" }, 405);
  }

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "Dữ liệu gửi lên không hợp lệ.", code: "invalid_json", step: "validate_request" }, 400);
  }

  const action = cleanText(body.action) as ManageAction;

  if (action === "update_email") return await handleUpdateEmail(body, req);
  if (action === "delete_user") return await handleDeleteUser(body, req);

  return jsonResponse({ error: "Hành động không được hỗ trợ.", code: "unsupported_action", step: "validate_action" }, 400);
}

Deno.serve(async (req) => {
  try {
    return await handleManageUser(req);
  } catch (error) {
    console.error("manage-user unexpected error:", error);
    const message = error instanceof Error ? error.message : "Lỗi hệ thống khi quản lý tài khoản.";
    return jsonResponse({ error: message, code: "unexpected_error", step: "unexpected" }, 500);
  }
});
