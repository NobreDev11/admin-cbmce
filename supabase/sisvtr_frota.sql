-- ADMIN CBMCE — SisVTR (frota) dentro do portal (/sisvtr).
-- Tabela no Supabase do Checklist. Leitura e alteração SOMENTE por administradores
-- (is_admin(), a mesma regra do portal). Nada é público.
--
-- Rodar no Supabase do Checklist: Dashboard → SQL Editor → colar → Run.
-- Pode rodar de novo sem problema.
--
-- Os DADOS da frota não ficam no GitHub: são carregados por um arquivo SQL separado,
-- gerado a partir da planilha e guardado só no computador (pasta SisVTR).

CREATE TABLE IF NOT EXISTS public.sisvtr_frota (
  id text PRIMARY KEY,
  prefixo text,
  situacao text,
  segmentacao text,
  ano_chegada integer,
  valor numeric(14,2),
  tipo text,
  segmento text,
  tipo_vtr text,
  marca text,
  modelo text,
  ano_fabricacao integer,
  ano_modelo integer,
  cor text,
  obm text,
  classificacao text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.sisvtr_frota ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.sisvtr_frota FROM anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.sisvtr_frota TO authenticated;

DROP POLICY IF EXISTS "admin select sisvtr" ON public.sisvtr_frota;
CREATE POLICY "admin select sisvtr" ON public.sisvtr_frota
  FOR SELECT TO authenticated USING (public.is_admin());

DROP POLICY IF EXISTS "admin insert sisvtr" ON public.sisvtr_frota;
CREATE POLICY "admin insert sisvtr" ON public.sisvtr_frota
  FOR INSERT TO authenticated WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "admin update sisvtr" ON public.sisvtr_frota;
CREATE POLICY "admin update sisvtr" ON public.sisvtr_frota
  FOR UPDATE TO authenticated USING (public.is_admin()) WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "admin delete sisvtr" ON public.sisvtr_frota;
CREATE POLICY "admin delete sisvtr" ON public.sisvtr_frota
  FOR DELETE TO authenticated USING (public.is_admin());
