-- ADMIN CBMCE — Ônibus (/onibus): controle de solicitações de transporte.
-- Rodar UMA vez no Supabase do Checklist: Dashboard → SQL Editor → colar tudo → Run.
-- Pode rodar de novo sem problema (não duplica nem apaga dados).
--
-- Quem acessa: administradores do portal (is_admin()) e OPERADORES do Ônibus
-- (tabela onibus_operadores, contas criadas pelo admin na aba "Acessos" do /onibus).
-- Nada é público: sem login não se lê nem se grava nada.

-- 1) Operadores (login próprio do Ônibus). Só a função do servidor (api/onibus-acessos.js) grava aqui.
CREATE TABLE IF NOT EXISTS public.onibus_operadores (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.onibus_operadores ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.onibus_operadores FROM anon, authenticated;
GRANT SELECT ON public.onibus_operadores TO authenticated;
DROP POLICY IF EXISTS "onibus operador ve a si mesmo" ON public.onibus_operadores;
CREATE POLICY "onibus operador ve a si mesmo" ON public.onibus_operadores
  FOR SELECT TO authenticated USING (user_id = auth.uid() OR public.is_admin());

-- 2) Quem pode usar o Ônibus: administrador OU operador.
CREATE OR REPLACE FUNCTION public.is_onibus()
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT public.is_admin()
      OR EXISTS (SELECT 1 FROM public.onibus_operadores WHERE user_id = auth.uid());
$$;
REVOKE ALL ON FUNCTION public.is_onibus() FROM public, anon;
GRANT EXECUTE ON FUNCTION public.is_onibus() TO authenticated;

-- 3) Cadastros: solicitantes, viaturas, condutores e locais (campos em "dados").
CREATE TABLE IF NOT EXISTS public.onibus_cadastros (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tipo text NOT NULL CHECK (tipo IN ('solicitantes', 'viaturas', 'condutores', 'locais')),
  dados jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS onibus_cadastros_tipo_idx ON public.onibus_cadastros (tipo);

-- 4) Solicitações. Nomes de viatura/condutor ficam gravados como texto (histórico não muda
--    se o cadastro for editado ou excluído).
CREATE TABLE IF NOT EXISTS public.onibus_solicitacoes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ano integer NOT NULL,
  seq integer NOT NULL,
  numero text NOT NULL UNIQUE,
  solicitante text NOT NULL CHECK (char_length(solicitante) BETWEEN 1 AND 200),
  setor text NOT NULL DEFAULT '',
  contato text NOT NULL DEFAULT '',
  local text NOT NULL CHECK (char_length(local) BETWEEN 1 AND 300),
  saida_de text NOT NULL DEFAULT '',
  finalidade text NOT NULL DEFAULT '',
  datas date[] NOT NULL CHECK (cardinality(datas) BETWEEN 1 AND 92),
  saida time NOT NULL,
  chegada time,
  viatura_id uuid REFERENCES public.onibus_cadastros(id) ON DELETE SET NULL,
  viatura text NOT NULL DEFAULT '',
  condutor_id uuid REFERENCES public.onibus_cadastros(id) ON DELETE SET NULL,
  condutor text NOT NULL DEFAULT '',
  passageiros jsonb NOT NULL DEFAULT '[]'::jsonb,
  qtd integer NOT NULL DEFAULT 0 CHECK (qtd BETWEEN 0 AND 999),
  status text NOT NULL DEFAULT 'Pendente'
    CHECK (status IN ('Pendente', 'Aprovada', 'Em andamento', 'Concluída', 'Cancelada')),
  obs text NOT NULL DEFAULT '',
  log jsonb NOT NULL DEFAULT '[]'::jsonb,
  created_by uuid DEFAULT auth.uid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (ano, seq)
);
-- Horário de saída pode ficar "a definir" (vazio).
ALTER TABLE public.onibus_solicitacoes ALTER COLUMN saida DROP NOT NULL;
CREATE INDEX IF NOT EXISTS onibus_solicitacoes_datas_idx ON public.onibus_solicitacoes USING gin (datas);

-- Número automático AAAA/NNNN (no fuso de Fortaleza), sem repetir mesmo com dois cadastros ao mesmo tempo.
CREATE OR REPLACE FUNCTION public.onibus_numero()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  y integer := extract(year FROM (now() AT TIME ZONE 'America/Fortaleza'))::integer;
  n integer;
BEGIN
  PERFORM pg_advisory_xact_lock(hashtext('onibus_numero'), y);
  SELECT coalesce(max(seq), 0) + 1 INTO n FROM public.onibus_solicitacoes WHERE ano = y;
  NEW.ano := y;
  NEW.seq := n;
  NEW.numero := y::text || '/' || lpad(n::text, 4, '0');
  NEW.created_by := auth.uid();
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS onibus_numero_trg ON public.onibus_solicitacoes;
CREATE TRIGGER onibus_numero_trg BEFORE INSERT ON public.onibus_solicitacoes
  FOR EACH ROW EXECUTE FUNCTION public.onibus_numero();

-- Número, ano e autor não mudam depois de registrados.
CREATE OR REPLACE FUNCTION public.onibus_fixos()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.ano := OLD.ano; NEW.seq := OLD.seq; NEW.numero := OLD.numero;
  NEW.created_by := OLD.created_by; NEW.created_at := OLD.created_at;
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS onibus_fixos_trg ON public.onibus_solicitacoes;
CREATE TRIGGER onibus_fixos_trg BEFORE UPDATE ON public.onibus_solicitacoes
  FOR EACH ROW EXECUTE FUNCTION public.onibus_fixos();

-- 5) Regras de acesso (RLS).
ALTER TABLE public.onibus_cadastros ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.onibus_solicitacoes ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.onibus_cadastros, public.onibus_solicitacoes FROM anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.onibus_cadastros, public.onibus_solicitacoes TO authenticated;

DROP POLICY IF EXISTS "onibus cad select" ON public.onibus_cadastros;
CREATE POLICY "onibus cad select" ON public.onibus_cadastros FOR SELECT TO authenticated USING (public.is_onibus());
DROP POLICY IF EXISTS "onibus cad insert" ON public.onibus_cadastros;
CREATE POLICY "onibus cad insert" ON public.onibus_cadastros FOR INSERT TO authenticated WITH CHECK (public.is_onibus());
DROP POLICY IF EXISTS "onibus cad update" ON public.onibus_cadastros;
CREATE POLICY "onibus cad update" ON public.onibus_cadastros FOR UPDATE TO authenticated USING (public.is_onibus()) WITH CHECK (public.is_onibus());
DROP POLICY IF EXISTS "onibus cad delete" ON public.onibus_cadastros;
CREATE POLICY "onibus cad delete" ON public.onibus_cadastros FOR DELETE TO authenticated USING (public.is_onibus());

DROP POLICY IF EXISTS "onibus sol select" ON public.onibus_solicitacoes;
CREATE POLICY "onibus sol select" ON public.onibus_solicitacoes FOR SELECT TO authenticated USING (public.is_onibus());
DROP POLICY IF EXISTS "onibus sol insert" ON public.onibus_solicitacoes;
CREATE POLICY "onibus sol insert" ON public.onibus_solicitacoes FOR INSERT TO authenticated WITH CHECK (public.is_onibus());
DROP POLICY IF EXISTS "onibus sol update" ON public.onibus_solicitacoes;
CREATE POLICY "onibus sol update" ON public.onibus_solicitacoes FOR UPDATE TO authenticated USING (public.is_onibus()) WITH CHECK (public.is_onibus());
-- Excluir de vez: só administrador. Operador usa a situação "Cancelada".
DROP POLICY IF EXISTS "onibus sol delete" ON public.onibus_solicitacoes;
CREATE POLICY "onibus sol delete" ON public.onibus_solicitacoes FOR DELETE TO authenticated USING (public.is_admin());

-- 6) Cartão na Página dos Usuários: começa OCULTO (ative pelo botão no portal).
INSERT INTO public.portal_pages (id, visible) VALUES ('onibus', false)
ON CONFLICT (id) DO NOTHING;
