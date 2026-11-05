# ADMIN CBMCE — Portal de administração

Painel central do CBMCE. Login único: o mesmo e-mail e senha de administrador do Checklist
(Supabase Auth + `is_admin()`). Depois de entrar, o portal mostra os botões para cada sistema.

## Como o login único funciona
- O navegador guarda a sessão por endereço. Para o painel do Checklist reconhecer o login do portal,
  ele é servido **pelo mesmo endereço do portal**: o `vercel.json` repassa (proxy) tudo que não é
  arquivo do portal para `https://vistoria-whatsapp.vercel.app`.
- `/` = portal (login + botões). `/admin` = painel do Checklist (já logado).
- `/admin/login` redireciona para o portal. O "Sair" do Checklist também volta ao portal.
- O código do Checklist não foi alterado. O endereço antigo `vistoria-whatsapp.vercel.app/admin`
  continua funcionando, com o login próprio.

## Arquivos
- `index.html`: portal (login e botões). Lista de sistemas em `SYSTEMS`, no fim do arquivo.
- `config.js`: endereço do Supabase e chave **publicável** (`sb_publishable_...`), a mesma do Checklist.
  Nunca colocar aqui a `service_role`/chave secreta.
- `vercel.json`: redirecionamentos e o proxy para o Checklist.

## Publicar na Vercel
1. Crie um repositório (ex.: `NobreDev11/admin-cbmce`) com estes arquivos e importe na Vercel.
2. Framework Preset: **Other**. Sem build. Sem variáveis de ambiente.
3. Teste: entrar no portal → "Abrir admin do Checklist" deve abrir o painel **sem pedir login de novo**.
   Teste também salvar algo no painel (ex.: uma configuração) e o "Sair".

## Testar no computador
Abrir `index.html` direto testa só o login. O botão do Checklist só funciona publicado na Vercel.

## Ativar outros sistemas
Preencha `url` do sistema em `SYSTEMS`. SisDirso tem login próprio por enquanto.

## Escala de Serviço
O botão "Abrir Escala" abre `/escala/`, que o `vercel.json` repassa para `https://escala-cbmce.vercel.app`
(repo `NobreDev11/escala-cbmce`, pasta `C:\Projetos\web\CBMCE\Escala`). Mesmo endereço = mesmo login.
Se o endereço da Escala na Vercel for outro, ajuste a regra `/escala/:path*` no `vercel.json`.

## Página dos Usuários (`/usuarios`)
Página **pública, sem login**, para distribuir ao efetivo: `https://admin-cbmce.vercel.app/usuarios`.
Só tem links de usuário (nada administrativo). As páginas ficam em `pages.js`:
- Checklist de Vistoria → `https://vistoria-whatsapp.vercel.app/` (vistoria pública).
- Escala de Serviço → `https://escala-cbmce.vercel.app/` (pública a partir do PR #2 do `escala-cbmce`).
- SisDirso → `https://sisdirso-cbmce.vercel.app/` (login próprio com Google).

No portal, o cartão "Página dos Usuários" abre a página e tem o botão "Copiar link".

### Ativar/desativar páginas para o efetivo
Cada cartão do portal com página de usuário tem o botão **"Visível na página dos usuários"**.
Desligado = a página some de `/usuarios`. A escolha fica no Supabase, tabela `portal_pages`
(leitura pública, alteração só por administrador).

**Criar a tabela (uma vez):** Supabase → SQL Editor → colar `supabase/portal_pages.sql` → Run.
Enquanto a tabela não existir, os botões mostram "Falta criar a tabela" e a página dos usuários
mostra Checklist e SisDirso (a Escala fica oculta até ser ativada).

Para incluir uma nova página de usuário: novo bloco em `pages.js` e `userPage: "<id>"` no cartão do portal.

### Link oficial da Escala
No cartão da Escala, o responsável cola o link do PDF (Google Drive, "Qualquer pessoa com o link") e clica
em **Salvar link**. Todo o efetivo vê a escala desse link; ninguém troca pela página da Escala.
Fica em `portal_pages.link` (linha `escala`). **Uma vez:** rodar `supabase/portal_pages_link.sql` no SQL Editor.

## SisVTR (`/sisvtr`)
Dashboard da frota dentro do portal (`sisvtr.html`), com o **mesmo login** (sessão do portal + `is_admin()`).
Sem sessão → volta ao login do portal e, depois de entrar, abre o SisVTR.
- Dados: tabela `public.sisvtr_frota` no Supabase do Checklist. **Somente administradores** leem, editam e excluem (RLS `is_admin()`); nada é público.
- Estrutura: `supabase/sisvtr_frota.sql`. Os **dados** (planilha `arquivo_pronto_para_dashboard.xlsx`) não ficam no GitHub:
  são carregados uma vez pelo arquivo `sisvtr_dados_supabase.sql` (tabela + itens), guardado só no computador (pasta `SisVTR`).
- **Uma vez:** Supabase do Checklist → SQL Editor → colar `sisvtr_dados_supabase.sql` → Run (deve mostrar 1224 itens). Pode rodar de novo sem duplicar.
- **Só a 7ª CIA:** a página busca apenas `obm = '7ª CIA/1º BBM - CISP'` (constante `OBM_FIXA` em `sisvtr.html`). Para outra OBM, trocar a constante.
- **Sem valores (R$):** a página não busca nem mostra a coluna `valor` (nem cartões, nem tabela, nem edição). O valor continua guardado no banco.
- Mantido pelo chat SISVTR. O projeto antigo `NobreDev11/SisVTR` (login próprio, nunca publicado) não é usado aqui.

## Checklist - Mata Branca (`/mata-branca`)
Página pública (sem login), no padrão do Checklist VTR ABTS14: número do oficial, identificação (data, VTR,
Oficial/Fiscal de Dia, COV, operadores, conferentes), blocos Mangueiras (opcional), Porta traseira e Cabine
com Conforme/Alteração (Falta, Danificado, Outros) e observações; gera o relatório e abre o WhatsApp.
Base: formulário Google "Checklist VTR Florestal" (7ª CIA/1º BBM). Rascunho fica no navegador.
**Não grava as vistorias em banco** (diferente do ABTS14). Itens: lista `CHECKLIST` em `mata-branca.html`.
Aparece na página dos usuários (id `mata-branca`, botão de visibilidade no cartão do portal).
