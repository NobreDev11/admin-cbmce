-- ADMIN CBMCE — páginas visíveis na Página dos Usuários (/usuarios).
-- Rodar UMA vez no Supabase do Checklist: Dashboard → SQL Editor → colar tudo → Run.
-- Pode rodar de novo sem problema (não duplica nada).
--
-- Leitura: qualquer pessoa (a página dos usuários é pública).
-- Alteração: somente administradores (is_admin(), a mesma regra do Checklist).

CREATE TABLE IF NOT EXISTS public.portal_pages (
  id text PRIMARY KEY CHECK (id ~ '^[a-z0-9-]{1,40}$'),
  visible boolean NOT NULL DEFAULT true,
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.portal_pages ENABLE ROW LEVEL SECURITY;

GRANT SELECT ON public.portal_pages TO anon, authenticated;
GRANT INSERT, UPDATE ON public.portal_pages TO authenticated;

DROP POLICY IF EXISTS "public read portal pages" ON public.portal_pages;
CREATE POLICY "public read portal pages" ON public.portal_pages
  FOR SELECT TO anon, authenticated USING (true);

DROP POLICY IF EXISTS "admin insert portal pages" ON public.portal_pages;
CREATE POLICY "admin insert portal pages" ON public.portal_pages
  FOR INSERT TO authenticated WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "admin update portal pages" ON public.portal_pages;
CREATE POLICY "admin update portal pages" ON public.portal_pages
  FOR UPDATE TO authenticated USING (public.is_admin()) WITH CHECK (public.is_admin());

-- Link oficial (Escala). Mesmo conteúdo de portal_pages_link.sql.
ALTER TABLE public.portal_pages
  ADD COLUMN IF NOT EXISTS link text NOT NULL DEFAULT '';
ALTER TABLE public.portal_pages DROP CONSTRAINT IF EXISTS portal_pages_link_check;
ALTER TABLE public.portal_pages
  ADD CONSTRAINT portal_pages_link_check
  CHECK (link = '' OR (char_length(link) <= 500 AND link ~ '^https://(drive|docs)\.google\.com/'));

-- Estado inicial. A Escala começa desativada (ative pelo portal quando ela estiver pública).
INSERT INTO public.portal_pages (id, visible) VALUES
  ('checklist', true),
  ('escala', false),
  ('sisdirso', true)
ON CONFLICT (id) DO NOTHING;
