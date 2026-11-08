// ADMIN CBMCE — Acessos (administradores) no portal.
// Mesmas regras do Admin → Acessos do Checklist (vistoria-whatsapp, src/lib/admins):
//  - só um administrador logado usa (token da sessão do portal + tabela admin_users);
//  - ninguém remove a si mesmo e sempre sobra pelo menos um administrador;
//  - senha de 10 a 72 caracteres; conta criada já confirmada (quem cria entrega a senha).
// Variável na Vercel (projeto admin-cbmce), NUNCA no código: SUPABASE_SERVICE_ROLE_KEY.
// Opcional: SUPABASE_URL (padrão: o mesmo do config.js).

const SUPABASE_URL = (process.env.SUPABASE_URL || "https://ytionrwdwdmcxbdgqnkt.supabase.co").replace(/\/+$/, "");
const KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || "";
const PASSWORD_MIN = 10;
const PASSWORD_MAX = 72;
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

function serviceHeaders(extra) {
  return { apikey: KEY, Authorization: `Bearer ${KEY}`, "Content-Type": "application/json", ...extra };
}

async function call(path, { method = "GET", body, headers } = {}) {
  const r = await fetch(SUPABASE_URL + path, {
    method,
    headers: serviceHeaders(headers),
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await r.text();
  let data = null;
  try { data = text ? JSON.parse(text) : null; } catch { data = text; }
  return { ok: r.ok, status: r.status, data };
}

function errMsg(data, fallback) {
  if (data && typeof data === "object") return data.msg || data.message || data.error_description || data.error || fallback;
  return fallback;
}

function friendly(message) {
  const m = String(message || "").toLowerCase();
  if (m.includes("password") && (m.includes("weak") || m.includes("short") || m.includes("least"))) {
    return "A senha foi recusada por ser fraca. Use uma mais longa, com letras e números.";
  }
  if (m.includes("rate limit")) return "Muitas tentativas. Aguarde um pouco e tente de novo.";
  return message || "Não foi possível concluir.";
}

function checkPassword(p) {
  if (typeof p !== "string" || p.length < PASSWORD_MIN) return `A senha precisa ter pelo menos ${PASSWORD_MIN} caracteres.`;
  if (p.length > PASSWORD_MAX) return `A senha pode ter no máximo ${PASSWORD_MAX} caracteres.`;
  return null;
}

/** Quem está chamando: valida o token no Supabase Auth e confere se está em admin_users. */
async function currentAdmin(req) {
  const auth = String(req.headers.authorization || "");
  const token = auth.startsWith("Bearer ") ? auth.slice(7).trim() : "";
  if (!token) return null;
  const r = await fetch(SUPABASE_URL + "/auth/v1/user", { headers: { apikey: KEY, Authorization: `Bearer ${token}` } });
  if (!r.ok) return null;
  const user = await r.json().catch(() => null);
  if (!user || !UUID_RE.test(String(user.id || ""))) return null;
  const row = await call(`/rest/v1/admin_users?select=user_id&user_id=eq.${user.id}`);
  if (!row.ok || !Array.isArray(row.data) || !row.data.length) return null;
  return { id: user.id, email: user.email || "" };
}

async function listAdmins(self) {
  const rows = await call("/rest/v1/admin_users?select=user_id,created_at&order=created_at");
  if (!rows.ok) throw new Error(errMsg(rows.data, "Não foi possível listar."));
  return Promise.all(rows.data.map(async (row) => {
    const u = await call(`/auth/v1/admin/users/${row.user_id}`);
    return {
      userId: row.user_id,
      email: (u.ok && u.data && u.data.email) || "(sem e-mail)",
      createdAt: row.created_at,
      lastSignInAt: (u.ok && u.data && u.data.last_sign_in_at) || null,
      isSelf: row.user_id === self.id,
    };
  }));
}

async function findUserIdByEmail(email) {
  for (let page = 1; page <= 10; page++) {
    const r = await call(`/auth/v1/admin/users?page=${page}&per_page=200`);
    if (!r.ok) throw new Error(errMsg(r.data, "Não foi possível procurar o usuário."));
    const users = (r.data && r.data.users) || [];
    const found = users.find((u) => String(u.email || "").toLowerCase() === email);
    if (found) return found.id;
    if (users.length < 200) return null;
  }
  return null;
}

async function createAdmin(body) {
  const email = String(body.email || "").trim().toLowerCase();
  if (!email) return { ok: false, message: "Informe o e-mail." };
  if (email.length > 254 || !EMAIL_RE.test(email)) return { ok: false, message: "E-mail inválido." };
  const bad = checkPassword(body.password);
  if (bad) return { ok: false, message: bad };

  const created = await call("/auth/v1/admin/users", {
    method: "POST",
    body: { email, password: body.password, email_confirm: true },
  });
  let userId = created.ok && created.data ? created.data.id : null;
  let existing = false;

  if (!userId) {
    const message = errMsg(created.data, "");
    if (!/already|registered|exists/i.test(message)) {
      return { ok: false, message: friendly(message || "Não foi possível criar o usuário.") };
    }
    userId = await findUserIdByEmail(email);
    if (!userId) return { ok: false, message: "Esse e-mail já existe, mas não o encontrei." };
    existing = true;
  }

  const promoted = await call("/rest/v1/admin_users?on_conflict=user_id", {
    method: "POST",
    body: { user_id: userId },
    headers: { Prefer: "resolution=ignore-duplicates,return=minimal" },
  });
  if (!promoted.ok) {
    if (!existing) await call(`/auth/v1/admin/users/${userId}`, { method: "DELETE" });
    return { ok: false, message: errMsg(promoted.data, "Não foi possível dar acesso de administrador.") };
  }
  return {
    ok: true,
    message: existing
      ? `${email} já tinha conta e agora é administrador (a senha dela não foi alterada).`
      : `${email} criado como administrador.`,
  };
}

async function isAdminId(userId) {
  const r = await call(`/rest/v1/admin_users?select=user_id&user_id=eq.${userId}`);
  if (!r.ok) throw new Error(errMsg(r.data, "Não foi possível conferir o administrador."));
  return Array.isArray(r.data) && r.data.length > 0;
}

async function resetPassword(body) {
  const userId = String(body.userId || "");
  if (!UUID_RE.test(userId)) return { ok: false, message: "Administrador inválido." };
  const bad = checkPassword(body.password);
  if (bad) return { ok: false, message: bad };
  if (!(await isAdminId(userId))) return { ok: false, message: "Esse usuário não é administrador." };
  const r = await call(`/auth/v1/admin/users/${userId}`, { method: "PUT", body: { password: body.password } });
  if (!r.ok) return { ok: false, message: friendly(errMsg(r.data, "")) };
  return { ok: true, message: "Senha redefinida." };
}

async function removeAdmin(body, self) {
  const userId = String(body.userId || "");
  if (!UUID_RE.test(userId)) return { ok: false, message: "Administrador inválido." };
  const all = await call("/rest/v1/admin_users?select=user_id");
  if (!all.ok) return { ok: false, message: errMsg(all.data, "Não foi possível conferir.") };
  const ids = all.data.map((r) => r.user_id);
  if (!ids.includes(userId)) return { ok: false, message: "Esse usuário não é administrador." };
  if (userId === self.id) return { ok: false, message: "Você não pode remover o seu próprio acesso." };
  if (ids.length <= 1) return { ok: false, message: "É preciso manter pelo menos um administrador." };
  // Apagar a conta do Auth também apaga a linha de admin_users (ON DELETE CASCADE).
  const del = await call(`/auth/v1/admin/users/${userId}`, { method: "DELETE" });
  if (!del.ok) return { ok: false, message: errMsg(del.data, "Não foi possível remover.") };
  return { ok: true, message: "Administrador removido." };
}

module.exports = async function handler(req, res) {
  res.setHeader("Cache-Control", "no-store");
  if (req.method !== "POST") return res.status(405).json({ ok: false, message: "Método não permitido." });
  if (!KEY) {
    return res.status(503).json({ ok: false, setup: true, message: "Falta configurar SUPABASE_SERVICE_ROLE_KEY na Vercel (projeto admin-cbmce)." });
  }
  try {
    const self = await currentAdmin(req);
    if (!self) return res.status(401).json({ ok: false, message: "Sessão expirada ou sem permissão. Entre de novo." });
    const body = (req.body && typeof req.body === "object") ? req.body : {};
    switch (body.action) {
      case "list": return res.status(200).json({ ok: true, admins: await listAdmins(self) });
      case "create": return res.status(200).json(await createAdmin(body));
      case "reset": return res.status(200).json(await resetPassword(body));
      case "remove": return res.status(200).json(await removeAdmin(body, self));
      default: return res.status(400).json({ ok: false, message: "Ação inválida." });
    }
  } catch (e) {
    return res.status(500).json({ ok: false, message: friendly(e && e.message) });
  }
};
