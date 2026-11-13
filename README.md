# prodifolio

Portfólio pessoal dinâmico de **hikarilucky79**, atualizado automaticamente a partir dos repositórios públicos do GitHub, com backend em **Go 1.22+**, banco **Supabase (PostgreSQL em 3FN)** e app **Flutter Material 3** (Web + Mobile).

- **Ao vivo:** [dev-hikari.vercel.app](https://dev-hikari.vercel.app)
- **Currículo (PDF):** [dev-hikari.vercel.app/curriculo.pdf](https://dev-hikari.vercel.app/curriculo.pdf)
- **LinkedIn:** [linkedin.com/in/kauã-oliveira-43b07b268](https://www.linkedin.com/in/kau%C3%A3-oliveira-43b07b268/)

## Estrutura do monorepo

```text
prodifolio/
├── .github/workflows/ci.yml
├── supabase/migrations/001_init_3nf.sql
├── backend/
│   ├── cmd/server/main.go
│   ├── internal/
│   │   ├── cache/          # Cache em memória com TTL e relógio injetável
│   │   ├── config/         # Configuração por variáveis de ambiente
│   │   ├── github/         # Cliente da API REST do GitHub (interface injetável)
│   │   ├── httpapi/        # Rotas Go 1.22 net/http, CORS, slog e erros JSON
│   │   ├── portfolio/      # Regras de projetos, estatísticas e validação de contato
│   │   ├── ratelimit/      # Rate limit por IP com suporte opcional a proxy confiável
│   │   └── store/          # Persistência Supabase Postgres 3FN + fallback em memória
│   ├── Dockerfile
│   ├── .env.example
│   └── go.mod
├── app/
│   ├── lib/
│   │   ├── core/           # Config via --dart-define e tema Material 3 claro/escuro
│   │   ├── data/           # Cliente HTTP e implementação do repositório
│   │   ├── domain/         # Entidades e contrato PortfolioRepository
│   │   └── presentation/   # Providers Riverpod, telas, widgets e CustomPainter
│   ├── test/
│   └── pubspec.yaml
└── README.md
```

**Justificativa do Riverpod:** Riverpod garante injeção de dependências com segurança em tempo de compilação e override direto do repositório nos testes sem `BuildContext`, evitando boilerplate de eventos/estados do Bloc para uma UI orientada a chamadas assíncronas.

---

## Banco de dados (Supabase · 3FN)

O arquivo [supabase/migrations/001_init_3nf.sql](supabase/migrations/001_init_3nf.sql) cria as tabelas normalizadas até a **Terceira Forma Normal (3FN)**:

- **1FN:** Todos os campos são atômicos; grupos repetidos de linguagens por repositório são separados em `repository_languages`.
- **2FN:** Na única tabela com chave composta (`repository_languages(repository_id, language_id)`), `bytes_count` depende da chave inteira.
- **3FN:** Nenhuma dependência transitiva nem totais derivados armazenados:
  - `owners` isola dados do perfil GitHub de `repositories`.
  - `languages` isola nomes de linguagens das tabelas de repositórios.
  - `contact_senders` separa identidade (`email`, `name`) de `contact_messages` (cada envio aponta para `sender_id`).
- Todas as tabelas possuem **Row Level Security (RLS)** habilitado por padrão para bloquear acesso direto anônimo via PostgREST.

### Aplicando a migração no Supabase

1. Crie um projeto no [Supabase](https://supabase.com).
2. No **SQL Editor**, execute o conteúdo de `supabase/migrations/001_init_3nf.sql`.
3. Copie a connection string PostgreSQL (Session Pooler ou Direct Connection) em **Connect -> Connection String** e configure `SUPABASE_DB_URL`.

---

## Rodando localmente

### 1. Backend (Go 1.22+)

```bash
cd backend
cp .env.example .env
# Preencha GITHUB_TOKEN (recomendado para evitar 60 req/h) e SUPABASE_DB_URL (opcional em dev)
go run ./cmd/server
```

Variáveis de ambiente principais:

| Variável | Padrão | Descrição |
|---|---|---|
| `PORT` | `8080` | Porta HTTP do servidor |
| `GITHUB_USERNAME` | `hikarilucky79` | Usuário GitHub do portfólio |
| `GITHUB_TOKEN` | _(vazio)_ | Personal Access Token (nunca no código) |
| `CACHE_TTL` | `15m` | Expiração do cache em memória |
| `CORS_ALLOWED_ORIGINS` | `*` | Origens permitidas separadas por vírgula |
| `CONTACT_RATE_LIMIT` | `5` | Máximo de envios no `POST /contact` por janela |
| `CONTACT_RATE_WINDOW` | `1m` | Janela do rate limit por IP |
| `TRUST_PROXY` | `false` | Se `true`, lê `X-Forwarded-For` / `X-Real-IP` |
| `SUPABASE_DB_URL` | _(vazio)_ | Connection string Postgres do Supabase (vazio usa memória em dev) |

Testes do backend:

```bash
cd backend
go test -v ./...
```

### 2. App Flutter (Web e Mobile)

A URL da API nunca fica fixa no código; informe via `--dart-define`:

```bash
cd app
flutter pub get

# Web
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8080

# Android Emulator (aponta localhost da máquina via 10.0.2.2)
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080
```

Opcionalmente, passe `--dart-define=RESUME_URL=https://seu-link-de-curriculo.pdf` para abrir um PDF externo no botão **Currículo** (sem ela, o app exibe um resumo interativo do perfil).

Testes e análise do app:

```bash
cd app
flutter analyze
flutter test
```

---

## Deploy

### Banco de Dados (Supabase)

O projeto Supabase `prodifolio` (ref `kehvigrupngftwqhfnmv`, regiao `sa-east-1`) ja esta provisionado com o schema em 3FN aplicado ([supabase/migrations/001_init_3nf.sql](supabase/migrations/001_init_3nf.sql)).

Copie a string de conexao Postgres (Transaction pooler) em **Supabase Dashboard -> prodifolio -> Connect** e use-a na variavel `SUPABASE_DB_URL` do backend.

### Backend na Vercel (`backend/vercel.json`)

```bash
cd backend
vercel login
vercel --scope hikari-s-projects2 link --yes
vercel --scope hikari-s-projects2 env add SUPABASE_DB_URL production
vercel --scope hikari-s-projects2 env add GITHUB_TOKEN production
vercel --scope hikari-s-projects2 env add TRUST_PROXY production
vercel --scope hikari-s-projects2 env add CORS_ALLOWED_ORIGINS production
vercel --scope hikari-s-projects2 deploy --prod
```

> Em ambiente serverless na Vercel, o cache em memoria e o rate limit por IP valem por instancia quente, enquanto o Supabase persiste snapshots e contatos entre invocacoes.

### Backend via Docker (Fly.io, Cloud Run, Render, Railway)

```bash
cd backend
docker build -t prodifolio-api .
docker run -p 8080:8080 \
  -e GITHUB_TOKEN="$GITHUB_TOKEN" \
  -e SUPABASE_DB_URL="$SUPABASE_DB_URL" \
  -e CORS_ALLOWED_ORIGINS="https://seu-dominio.com" \
  -e TRUST_PROXY=true \
  prodifolio-api
```

### App Flutter Web na Vercel (`app/vercel.json`)

```bash
cd app
flutter build web --release \
  --dart-define=API_BASE_URL=https://sua-api.vercel.app \
  --dart-define=RESUME_URL=https://dev-hikari.vercel.app/curriculo.pdf
cp vercel.json build/web/vercel.json
cd build/web
vercel --scope hikari-s-projects2 deploy --prod
```

Para Cloudflare Pages ou Netlify, publique diretamente a pasta `app/build/web`.
