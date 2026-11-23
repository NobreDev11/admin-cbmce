// ADMIN CBMCE — Ônibus: contas dos OPERADORES (login próprio do /onibus).
// Só um ADMINISTRADOR do portal usa (token da sessão + tabela admin_users).
// Operador entra só no /onibus: não é administrador e não abre o portal nem os outros painéis.
// Mesma variável da função de Acessos (api/admins.js), NUNCA no código: SUPABASE_SERVICE_ROLE_KEY.

const SUPABASE_URL = (process.env.SUPABASE_URL || "https://ytionrwdwdmcxbdgqnkt.supabase.co").replace(/\/+$/, "");
const KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || "";
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

async function call(path, { method = "GET", body, headers } = {}) {
  const r = await fetch(SUPABASE_URL + path, {
    method,
    headers: { apikey: KEY, Authorization: `Bearer ${KEY}`, "Content-Type": "application/json", ...headers },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await r.text();
  let data = null;
  try { data = text ? JSON.parse(text) : null; } catch { data = text; }
  return { ok: r.ok, status: r.status, data };
}

const errMsg = (d, f) => (d && typeof d === "object" && (d.msg || d.message || d.error_description || d.error)) || f;

function friendly(message) {
  const m = String(message || "").toLowerCase();
  if (m.includes("password") && (m.includes("weak") || m.includes("short") || m.includes("least"))) {
    return "A senha foi recusada por ser fraca. Use uma mais longa, com letras e números.";
  }
  if (m.includes("rate limit")) return "Muitas tentativas. Aguarde um pouco e tente de novo.";
  if (m.includes("onibus_operadores") && (m.includes("does not exist") || m.includes("could not find"))) {
    return "Falta rodar supabase/onibus.sql no Supabase (ver README).";
  }
  return message || "Não foi possível concluir.";
}

function checkPassword(p) {
  if (typeof p !== "string" || p.length < 10) return "A senha precisa ter pelo menos 10 caracteres.";
  if (p.length > 72) return "A senha pode ter no máximo 72 caracteres.";
  return null;
}

async function inTable(table, userId) {
  const r = await call(`/rest/v1/${table}?select=user_id&user_id=eq.${userId}`);
  if (!r.ok) throw new Error(errMsg(r.data, "Não foi possível conferir."));
  return Array.isArray(r.data) && r.data.length > 0;
}

async function currentAdmin(req) {
  const auth = String(req.headers.authorization || "");
  const token = auth.startsWith("Bearer ") ? auth.slice(7).trim() : "";
  if (!token) return null;
  const r = await fetch(SUPABASE_URL + "/auth/v1/user", { headers: { apikey: KEY, Authorization: `Bearer ${token}` } });
  if (!r.ok) return null;
  const user = await r.json().catch(() => null);
  if (!user || !UUID_RE.test(String(user.id || ""))) return null;
  return (await inTable("admin_users", user.id)) ? { id: user.id } : null;
}

async function list() {
  const rows = await call("/rest/v1/onibus_operadores?select=user_id,created_at&order=created_at");
  if (!rows.ok) throw new Error(errMsg(rows.data, "Não foi possível listar."));
  return Promise.all(rows.data.map(async (row) => {
    const u = await call(`/auth/v1/admin/users/${row.user_id}`);
    return {
      userId: row.user_id,
      email: (u.ok && u.data && u.data.email) || "(sem e-mail)",
      lastSignInAt: (u.ok && u.data && u.data.last_sign_in_at) || null,
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

async function create(body) {
  const email = String(body.email || "").trim().toLowerCase();
  if (!email || email.length > 254 || !EMAIL_RE.test(email)) return { ok: false, message: "E-mail inválido." };
  const bad = checkPassword(body.password);
  if (bad) return { ok: false, message: bad };

  const created = await call("/auth/v1/admin/users", { method: "POST", body: { email, password: body.password, email_confirm: true } });
  let userId = created.ok && created.data ? created.data.id : null;
  let existing = false;
  if (!userId) {
    const message = errMsg(created.data, "");
    if (!/already|registered|exists/i.test(message)) return { ok: false, message: friendly(message || "Não foi possível criar o usuário.") };
    userId = await findUserIdByEmail(email);
    if (!userId) return { ok: false, message: "Esse e-mail já existe, mas não o encontrei." };
    existing = true;
  }
  const add = await call("/rest/v1/onibus_operadores?on_conflict=user_id", {
    method: "POST", body: { user_id: userId },
    headers: { Prefer: "resolution=ignore-duplicates,return=minimal" },
  });
  if (!add.ok) {
    if (!existing) await call(`/auth/v1/admin/users/${userId}`, { method: "DELETE" });
    return { ok: false, message: friendly(errMsg(add.data, "Não foi possível dar acesso ao Ônibus.")) };
  }
  return {
    ok: true,
    message: existing
      ? `${email} já tinha conta e agora acessa o Ônibus (a senha dela não foi alterada).`
      : `${email} criado como operador do Ônibus.`,
  };
}

async function reset(body) {
  const userId = String(body.userId || "");
  if (!UUID_RE.test(userId)) return { ok: false, message: "Operador inválido." };
  const bad = checkPassword(body.password);
  if (bad) return { ok: false, message: bad };
  if (!(await inTable("onibus_operadores", userId))) return { ok: false, message: "Esse usuário não é operador do Ônibus." };
  if (await inTable("admin_users", userId)) return { ok: false, message: "É administrador: redefina a senha pelo portal (Acessos)." };
  const r = await call(`/auth/v1/admin/users/${userId}`, { method: "PUT", body: { password: body.password } });
  if (!r.ok) return { ok: false, message: friendly(errMsg(r.data, "")) };
  return { ok: true, message: "Senha redefinida." };
}

async function remove(body) {
  const userId = String(body.userId || "");
  if (!UUID_RE.test(userId)) return { ok: false, message: "Operador inválido." };
  if (!(await inTable("onibus_operadores", userId))) return { ok: false, message: "Esse usuário não é operador do Ônibus." };
  if (await inTable("admin_users", userId)) {
    // Administrador: só tira da lista de operadores; a conta continua (acesso pelo portal).
    const d = await call(`/rest/v1/onibus_operadores?user_id=eq.${userId}`, { method: "DELETE" });
    if (!d.ok) return { ok: false, message: errMsg(d.data, "Não foi possível remover.") };
    return { ok: true, message: "Removido da lista de operadores (continua administrador)." };
  }
  // Operador comum: apaga a conta (a linha de onibus_operadores sai junto, ON DELETE CASCADE).
  const del = await call(`/auth/v1/admin/users/${userId}`, { method: "DELETE" });
  if (!del.ok) return { ok: false, message: errMsg(del.data, "Não foi possível remover.") };
  return { ok: true, message: "Operador removido. A conta foi apagada." };
}

module.exports = async function handler(req, res) {
  res.setHeader("Cache-Control", "no-store");
  if (req.method !== "POST") return res.status(405).json({ ok: false, message: "Método não permitido." });
  if (!KEY) return res.status(503).json({ ok: false, setup: true, message: "Falta configurar SUPABASE_SERVICE_ROLE_KEY na Vercel (projeto admin-cbmce)." });
  try {
    const self = await currentAdmin(req);
    if (!self) return res.status(401).json({ ok: false, message: "Só administrador do portal gerencia os operadores." });
    const body = (req.body && typeof req.body === "object") ? req.body : {};
    switch (body.action) {
      case "list": return res.status(200).json({ ok: true, operadores: await list() });
      case "create": return res.status(200).json(await create(body));
      case "reset": return res.status(200).json(await reset(body));
      case "remove": return res.status(200).json(await remove(body));
      default: return res.status(400).json({ ok: false, message: "Ação inválida." });
    }
  } catch (e) {
    return res.status(500).json({ ok: false, message: friendly(e && e.message) });
  }
};
