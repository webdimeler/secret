import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.57.0";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const reply = (body: unknown, status = 200) => new Response(JSON.stringify(body), {
  status,
  headers: { ...cors, "Content-Type": "application/json; charset=utf-8" },
});
const str = (v: unknown, max = 200) => typeof v === "string" ? v.trim().slice(0, max) : "";
const hex = (bytes: Uint8Array) => [...bytes].map(b => b.toString(16).padStart(2, "0")).join("");
const sha256 = async (value: string) => hex(new Uint8Array(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value))));
const safeName = (name: string) => name.replace(/[^A-Za-z0-9._ -]/g, "_").slice(0, 160) || "file";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return reply({ error: "Method not allowed" }, 405);

  const url = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !serviceKey) return reply({ error: "Server configuration error" }, 500);
  const db = createClient(url, serviceKey, { auth: { persistSession: false, autoRefreshToken: false } });

  const contentType = req.headers.get("content-type") || "";
  if (contentType.includes("application/json")) {
    let payload: Record<string, unknown>;
    try { payload = await req.json(); } catch { return reply({ error: "Invalid JSON" }, 400); }
    if (str(payload.action, 20) !== "pair") return reply({ error: "Unsupported action" }, 400);
    const code = str(payload.code, 40).toUpperCase();
    const device_name = str(payload.device_name, 100) || "Android device";
    const app_version = str(payload.app_version, 40);
    if (!/^[A-HJ-NP-Z2-9]{8}$/.test(code)) return reply({ error: "أدخل رمز الربط المكوّن من 8 أحرف." }, 400);

    const { data: pairing, error: pairingError } = await db.from("device_pairing_codes")
      .select("id,expires_at,used_at")
      .eq("code_hash", await sha256(code))
      .is("used_at", null)
      .gt("expires_at", new Date().toISOString())
      .maybeSingle();
    if (pairingError || !pairing) return reply({ error: "رمز الربط غير صالح أو انتهت صلاحيته أو استُخدم من قبل." }, 400);

    const { data: consumed, error: consumeError } = await db.from("device_pairing_codes")
      .update({ used_at: new Date().toISOString() })
      .eq("id", pairing.id)
      .is("used_at", null)
      .select("id")
      .maybeSingle();
    if (consumeError || !consumed) return reply({ error: "تم استخدام رمز الربط بالفعل. أنشئ رمزًا جديدًا." }, 409);

    const tokenBytes = crypto.getRandomValues(new Uint8Array(32));
    const token = hex(tokenBytes);
    const { data: device, error: deviceError } = await db.from("connected_devices").insert({
      device_name, platform: "android", app_version: app_version || null,
      status: "active", last_seen_at: new Date().toISOString(), device_token_hash: await sha256(token),
    }).select("id,device_name,status,created_at").single();
    if (deviceError || !device) return reply({ error: "تعذر تسجيل الجهاز. أنشئ رمز ربط جديدًا وحاول مرة أخرى." }, 500);
    return reply({ device, token, message: "تم ربط الجهاز. احتفظ بالرمز على هذا الجهاز فقط." }, 201);
  }

  const auth = req.headers.get("authorization") || "";
  const token = auth.startsWith("Bearer ") ? auth.slice(7).trim() : "";
  if (token.length < 40) return reply({ error: "الجهاز غير مربوط. اربطه من خلال رمز الإدارة أولًا." }, 401);
  const tokenHash = await sha256(token);
  const { data: device, error: deviceError } = await db.from("connected_devices")
    .select("id,status")
    .eq("device_token_hash", tokenHash)
    .eq("status", "active")
    .maybeSingle();
  if (deviceError || !device) return reply({ error: "تم إيقاف هذا الجهاز أو أن رمز الوصول غير صالح." }, 401);

  if (contentType.includes("application/json")) {
    const payload = await req.json().catch(() => ({}));
    const action = str(payload.action, 30);
    if (action === "heartbeat") {
      await db.from("connected_devices").update({ last_seen_at: new Date().toISOString() }).eq("id", device.id);
      return reply({ ok: true });
    }
    if (action === "sync_index") {
      if (!Array.isArray(payload.files) || payload.files.length > 500) {
        return reply({ error: "دفعة الملفات غير صالحة؛ الحد الأقصى 500 ملف في الطلب." }, 400);
      }
      const scannedAt = new Date().toISOString();
      const rows = payload.files.map((item: Record<string, unknown>) => ({
        device_id: device.id,
        relative_path: str(item.path, 1000),
        display_name: str(item.name, 255) || "ملف",
        mime_type: str(item.mime_type, 150) || null,
        size_bytes: Math.max(0, Math.floor(Number(item.size_bytes) || 0)),
        modified_at: Number(item.modified_at) > 0 ? new Date(Number(item.modified_at)).toISOString() : null,
        scanned_at: scannedAt,
      })).filter((item: { relative_path: string }) => item.relative_path.length > 0);
      if (rows.length) {
        const { error: indexError } = await db.from("device_storage_index").upsert(rows, { onConflict: "device_id,relative_path" });
        if (indexError) return reply({ error: "تعذر تحديث فهرس ملفات الهاتف." }, 500);
      }
      await db.from("connected_devices").update({ last_seen_at: scannedAt }).eq("id", device.id);
      return reply({ ok: true, indexed: rows.length, scanned_at: scannedAt });
    }
    return reply({ error: "Unsupported action" }, 400);
  }

  let form: FormData;
  try { form = await req.formData(); } catch { return reply({ error: "تعذر قراءة الملف المرسل." }, 400); }
  const file = form.get("file");
  if (!(file instanceof File)) return reply({ error: "اختر ملفًا أولًا." }, 400);
  if (file.size < 1 || file.size > 50 * 1024 * 1024) return reply({ error: "حجم الملف يجب أن يكون أقل من 50 ميجابايت." }, 413);

  const path = device.id + "/" + crypto.randomUUID() + "_" + safeName(file.name);
  const { error: uploadError } = await db.storage.from("device-files").upload(path, file, {
    contentType: file.type || "application/octet-stream", upsert: false,
  });
  if (uploadError) return reply({ error: "تعذر رفع الملف إلى التخزين الخاص." }, 500);
  const { error: metadataError } = await db.from("device_files").insert({
    device_id: device.id, storage_path: path, file_name: file.name.slice(0, 255),
    mime_type: file.type || null, size_bytes: file.size,
  });
  if (metadataError) {
    await db.storage.from("device-files").remove([path]);
    return reply({ error: "تعذر حفظ سجل الملف؛ أُلغيت عملية الرفع." }, 500);
  }
  await db.from("connected_devices").update({ last_seen_at: new Date().toISOString() }).eq("id", device.id);
  return reply({ ok: true, file_name: file.name, size_bytes: file.size }, 201);
});