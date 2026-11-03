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
Preencha `url` do sistema em `SYSTEMS`. SisVTR e SisDirso têm login próprio por enquanto.

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
