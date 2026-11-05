// Páginas de USUÁRIO (nada administrativo). Usado pela página /usuarios e pelos
// botões "Visível na página dos usuários" do portal.
// "id" liga a página à linha da tabela portal_pages (ver supabase/portal_pages.sql).
// Para adicionar uma página: novo bloco aqui + "userPage" no cartão do portal (index.html).
window.USER_PAGES = [
  {
    id: "checklist", name: "Checklist ABTS14", icon: "✅",
    description: "Preencher a vistoria e enviar o resultado pelo WhatsApp.",
    url: "https://vistoria-whatsapp.vercel.app/"
  },
  {
    id: "mata-branca", name: "Checklist - Mata Branca", icon: "🌳",
    description: "Conferência da VTR DIRSO Florestal e envio pelo WhatsApp.",
    url: "/mata-branca"
  },
  {
    id: "escala", name: "Escala de Serviço", icon: "📋",
    description: "Consultar a escala por militar, função e data.",
    url: "https://escala-cbmce.vercel.app/",
    defaultVisible: false // até ser ativada no portal
  },
  {
    id: "sisdirso", name: "SisDirso", icon: "📅",
    description: "Simular e controlar plantões de DIRSO.",
    url: "https://sisdirso-cbmce.vercel.app/"
  }
];

// Lê quais páginas estão visíveis. Retorna { ok, visible: {id: bool}, missing }.
// missing = a tabela ainda não foi criada no Supabase (vale o defaultVisible de cada página).
window.loadPageVisibility = async function (cfg) {
  try {
    const r = await fetch(cfg.supabaseUrl + "/rest/v1/portal_pages?select=id,visible", {
      headers: { apikey: cfg.supabasePublishableKey },
      cache: "no-store"
    });
    if (r.status === 404) return { ok: true, visible: {}, missing: true };
    if (!r.ok) {
      const body = await r.json().catch(() => ({}));
      if (body && (body.code === "PGRST205" || body.code === "42P01")) return { ok: true, visible: {}, missing: true };
      return { ok: false, visible: {}, missing: false };
    }
    const rows = await r.json();
    const visible = {};
    for (const row of rows) visible[row.id] = row.visible === true;
    return { ok: true, visible, missing: false };
  } catch {
    return { ok: false, visible: {}, missing: false };
  }
};

// Regra única: valor gravado no banco; sem valor, o padrão da página (visível, salvo defaultVisible: false).
window.isPageVisible = function (page, visible) {
  return Object.prototype.hasOwnProperty.call(visible, page.id) ? visible[page.id] : page.defaultVisible !== false;
};
