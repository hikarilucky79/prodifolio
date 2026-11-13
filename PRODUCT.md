# Product

<!-- impeccable:product-schema 1 -->

## Platform

web

## Users

Recrutadores, tech leads e potenciais clientes (freelance e consultoria) avaliando o trabalho de Hikari (`@hikarilucky79`) em engenharia backend (Go), dados (PostgreSQL/Supabase) e aplicativos multiplataforma (Flutter).

## Product Purpose

Portfólio pessoal dinâmico (`prodifolio`) que se atualiza automaticamente a partir da conta GitHub `hikarilucky79`, apresentando projetos reais com busca/filtro e inspeção técnica detalhada, estatísticas autorais de linguagens e commits, trajetória profissional e canal direto de contato/briefing ligado ao backend em Go e PostgreSQL.

## Positioning

Diferente de portfólios estáticos ou templates pré-prontos, o `prodifolio` expõe um sistema completo em produção: API REST própria em Go 1.22+ com cache TTL e rate limit por IP, banco Supabase normalizado até a 3FN e aplicativo Flutter responsivo (Web + Mobile) com gráficos desenhados manualmente em `CustomPainter`.

## Operating Context

- Aplicação principal publicada na Vercel (`https://prodifolio.vercel.app`) conectada à API Go (`https://prodifolio-api.vercel.app`) e banco Supabase (`prodifolio`, ref `kehvigrupngftwqhfnmv`).
- Suporte contínuo a múltiplos viewports: celular (`< 600px`), tablet (`600–1023px`) e desktop (`>= 1024px`), mantendo compatibilidade com builds Android e iOS em Flutter.
- Fluxos obrigatórios preservados: Home (apresentação, links sociais e currículo), Projetos (busca, filtro por linguagem, cards e ficha técnica/lightbox), Estatísticas (gráficos em `CustomPainter`), Sobre (linha do tempo animada) e Contato (briefing/formulário validado integrado ao `POST /contact`).

## Capabilities and Constraints

- Manter Flutter (Dart com null safety), arquitetura `data / domain / presentation`, gerenciamento de estado com Riverpod, gráficos sem pacotes externos (`CustomPainter`), `Semantics` nos controles principais, alternância de tema claro/escuro e tratamento explícito de estados de loading, erro e vazio em todas as telas.
- Manter os endpoints e contratos existentes da API Go (`GET /health`, `GET /projects`, `GET /projects/{name}`, `GET /stats`, `POST /contact`) e os testes automatizados (`go test` e `flutter test`).
- O formulário de contato em produção aguarda a configuração opcional de `SUPABASE_DB_URL` e `GITHUB_TOKEN` na Vercel (sem essa variável, o backend opera em modo `memory` temporário).

## Brand Commitments

- Identidade do autor: `Hikari` (`@hikarilucky79`, nome do produto `prodifolio`), idioma `pt-BR`.
- Referência visual vinculada pelo usuário: projeto Behance `#258242081` (*CANTO — Art Portfolio & E-commerce Website*, By.Shiva Studio), adaptado ao cenário de desenvolvedor com vitrine editorial de repositórios, ficha técnica/lightbox de projetos e briefing estruturado de contato no lugar de carrinho/checkout de obras de arte.
- Tema claro e escuro selecionáveis pelo usuário.

## Evidence on Hand

- Perfil público real do GitHub (`hikarilucky79` / `Hikari`, avatar, bio, website e lista de repositórios como `KaorCount`, `Finac`, etc.) servido ao vivo por `GET /projects`.
- Métricas reais de linguagens e atividade de commits dos últimos 14 dias servidas ao vivo por `GET /stats`.
- Marcos de trajetória em `aboutTimelineProvider` derivados dinamicamente da stack e dos projetos ativos.
- Ausências explícitas: não há fotografia de estúdio separada do avatar do GitHub, nem depoimentos de clientes, prêmios ou links comerciais externos; nunca fabricar dados fictícios de clientes, preços ou métricas inventadas.

## Product Principles

- Verdade dos dados em primeiro lugar: toda contagem de repositórios, estrelas, linguagens e commits vem da API ao vivo.
- Presença editorial sem esconder a utilidade: busca, filtros, fichas técnicas e envio de contato continuam imediatos em desktop e mobile.
- Resiliência visível: estados de carregamento, erro de API, validação 422, rate limit 429 e estado vazio fazem parte do design.
- Acessibilidade e movimento respeitoso: manter rótulos `Semantics`, contraste legível nos temas claro e escuro e respeito a `MediaQuery.disableAnimationsOf`.

## Accessibility & Inclusion

Controles principais com `Semantics`, navegação por teclado/foco preservada, suporte a redução de movimento (`MediaQuery.disableAnimationsOf`) e contraste mínimo de 4.5:1 em texto corrido e 3:1 em títulos de destaque em ambos os temas.
