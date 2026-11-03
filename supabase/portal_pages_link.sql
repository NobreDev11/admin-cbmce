-- ADMIN CBMCE — link oficial da Escala (e de outras páginas, se precisar).
-- Rodar UMA vez no Supabase do Checklist: Dashboard → SQL Editor → colar tudo → Run.
-- Pode rodar de novo sem problema. As regras de acesso da tabela continuam as mesmas:
-- qualquer pessoa lê; só administrador (is_admin()) altera.

ALTER TABLE public.portal_pages
  ADD COLUMN IF NOT EXISTS link text NOT NULL DEFAULT '';

ALTER TABLE public.portal_pages DROP CONSTRAINT IF EXISTS portal_pages_link_check;
ALTER TABLE public.portal_pages
  ADD CONSTRAINT portal_pages_link_check
  CHECK (link = '' OR (char_length(link) <= 500 AND link ~ '^https://(drive|docs)\.google\.com/'));

-- Começa com o link que a Escala já usava (só se ainda estiver vazio).
UPDATE public.portal_pages
  SET link = 'https://drive.google.com/file/d/1O2pbF-Ip8O2sbZ_J3r_Ix5PkbUITKm32/view?usp=drivesdk', updated_at = now()
  WHERE id = 'escala' AND link = '';
