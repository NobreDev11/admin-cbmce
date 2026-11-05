-- ADMIN CBMCE — Checklist - Mata Branca (/mata-branca e /mata-branca-admin).
-- Rodar no Supabase do Checklist: Dashboard → SQL Editor → colar tudo → Run.
-- Pode rodar de novo sem problema (não apaga nada; não sobrescreve o checklist já editado).
--
-- mb_config     → conteúdo do checklist (VTRs, perguntas, blocos, itens).
--                 Leitura: qualquer pessoa (a página pública precisa). Alteração: só administradores.
-- mb_vistorias  → cada vistoria enviada pela página pública.
--                 Envio (INSERT): qualquer pessoa. Ler e excluir: só administradores.

-- ===================== Checklist =====================
CREATE TABLE IF NOT EXISTS public.mb_config (
  id text PRIMARY KEY CHECK (id = 'main'),
  content jsonb NOT NULL CHECK (jsonb_typeof(content) = 'object' AND pg_column_size(content) < 200000),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.mb_config ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON public.mb_config TO anon, authenticated;
GRANT INSERT, UPDATE ON public.mb_config TO authenticated;

DROP POLICY IF EXISTS "public read mb_config" ON public.mb_config;
CREATE POLICY "public read mb_config" ON public.mb_config
  FOR SELECT TO anon, authenticated USING (true);

DROP POLICY IF EXISTS "admin insert mb_config" ON public.mb_config;
CREATE POLICY "admin insert mb_config" ON public.mb_config
  FOR INSERT TO authenticated WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "admin update mb_config" ON public.mb_config;
CREATE POLICY "admin update mb_config" ON public.mb_config
  FOR UPDATE TO authenticated USING (public.is_admin()) WITH CHECK (public.is_admin());

-- Checklist inicial (formulário "Checklist VTR Florestal", 7ª CIA/1º BBM). Só entra se ainda não existir.
INSERT INTO public.mb_config (id, content) VALUES ('main', $json$
{
  "title": "CHECKLIST - MATA BRANCA",
  "vtrs": ["ABT 33", "ABTS 04", "AHQ 01"],
  "questions": [
    {"id": "oficial", "text": "Oficial de Dia / Fiscal de Dia", "required": true},
    {"id": "cov", "text": "COV", "required": true},
    {"id": "op1", "text": "Operador de Linha 1", "required": true},
    {"id": "op2", "text": "Operador de Linha 2", "required": false},
    {"id": "outros", "text": "Outros Conferentes", "required": false}
  ],
  "blocks": [
    {"id": "mangueiras", "title": "Mangueiras", "required": false, "items": [
      {"id": "mangueiras-0", "name": "4 MANGUEIRAS DE 2,5\""},
      {"id": "mangueiras-1", "name": "3 MANGUEIRAS DE 1,5\""}
    ]},
    {"id": "traseira", "title": "Porta traseira", "required": true, "items": [
      {"id": "traseira-0", "name": "02 EPRA COMPLETO (LOI)"},
      {"id": "traseira-1", "name": "2 CHAVES DE MANGUEIRAS"},
      {"id": "traseira-2", "name": "1 ESGUICHO LEADER (LOI)"},
      {"id": "traseira-3", "name": "2 ESGUICHOS DE LATÃO DE 1,5\""},
      {"id": "traseira-4", "name": "1 DIVISOR"},
      {"id": "traseira-5", "name": "1 ADAPTADOR DE HIDRANTE (AT)"},
      {"id": "traseira-6", "name": "1 REDUÇÃO (AT)"},
      {"id": "traseira-7", "name": "1 LUVA DE HIDRANTE"},
      {"id": "traseira-8", "name": "1 CHAVE T"},
      {"id": "traseira-9", "name": "5 CONES"},
      {"id": "traseira-10", "name": "2 PÁS"},
      {"id": "traseira-11", "name": "2 ENXADAS"},
      {"id": "traseira-12", "name": "1 CORTA FRIO"},
      {"id": "traseira-13", "name": "1 FOICE"},
      {"id": "traseira-14", "name": "1 HALLIGAN"},
      {"id": "traseira-15", "name": "1 GADANHO"},
      {"id": "traseira-16", "name": "2 FACÕES"},
      {"id": "traseira-17", "name": "1 ALAVANCA"},
      {"id": "traseira-18", "name": "2 BOMBAS COSTAIS"},
      {"id": "traseira-19", "name": "2 ABAFADORES"},
      {"id": "traseira-20", "name": "1 ESCADA"},
      {"id": "traseira-21", "name": "1 CHAVE DE FENDA"},
      {"id": "traseira-22", "name": "1 CHAVE ESTRELA"},
      {"id": "traseira-23", "name": "1 LANTERNA AMARELA"}
    ]},
    {"id": "cabine", "title": "Cabine", "required": true, "items": [
      {"id": "cabine-0", "name": "1 HT (SESSÃO)"},
      {"id": "cabine-1", "name": "02 MÁSCARAS - SCOTT EN"},
      {"id": "cabine-2", "name": "01 LANTERNA (AHQ01/ABTS04)"},
      {"id": "cabine-3", "name": "01 CHAVE DE FENDA"},
      {"id": "cabine-4", "name": "01 CHAVE ESTRELA (AHQ01/ABTS04)"}
    ]}
  ]
}
$json$::jsonb)
ON CONFLICT (id) DO NOTHING;

-- ===================== Vistorias recebidas =====================
CREATE TABLE IF NOT EXISTS public.mb_vistorias (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  data date NOT NULL,
  vtr text NOT NULL CHECK (char_length(vtr) BETWEEN 1 AND 60),
  telefone text NOT NULL DEFAULT '' CHECK (char_length(telefone) <= 20),
  respostas jsonb NOT NULL DEFAULT '{}' CHECK (jsonb_typeof(respostas) = 'object'),
  itens jsonb NOT NULL DEFAULT '[]' CHECK (jsonb_typeof(itens) = 'array'),
  observacoes jsonb NOT NULL DEFAULT '[]' CHECK (jsonb_typeof(observacoes) = 'array'),
  conformes integer NOT NULL DEFAULT 0 CHECK (conformes >= 0),
  alteracoes integer NOT NULL DEFAULT 0 CHECK (alteracoes >= 0),
  sem_resposta integer NOT NULL DEFAULT 0 CHECK (sem_resposta >= 0),
  CONSTRAINT mb_vistorias_tamanho CHECK (pg_column_size(respostas) + pg_column_size(itens) + pg_column_size(observacoes) < 100000)
);

CREATE INDEX IF NOT EXISTS mb_vistorias_created_at_idx ON public.mb_vistorias (created_at DESC);

ALTER TABLE public.mb_vistorias ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.mb_vistorias FROM anon;
GRANT INSERT ON public.mb_vistorias TO anon, authenticated;
GRANT SELECT, DELETE ON public.mb_vistorias TO authenticated;

DROP POLICY IF EXISTS "public insert mb_vistorias" ON public.mb_vistorias;
CREATE POLICY "public insert mb_vistorias" ON public.mb_vistorias
  FOR INSERT TO anon, authenticated WITH CHECK (true);

DROP POLICY IF EXISTS "admin select mb_vistorias" ON public.mb_vistorias;
CREATE POLICY "admin select mb_vistorias" ON public.mb_vistorias
  FOR SELECT TO authenticated USING (public.is_admin());

DROP POLICY IF EXISTS "admin delete mb_vistorias" ON public.mb_vistorias;
CREATE POLICY "admin delete mb_vistorias" ON public.mb_vistorias
  FOR DELETE TO authenticated USING (public.is_admin());
