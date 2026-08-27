# resume-server

## Papel no ecossistema (PT)

Infraestrutura e Gateway de Rede do Currículo Interativo: configurações do NGINX, orquestração de
containers (`docker-compose.yml`) e scripts relacionados (ver Constitution Principle I,
`.specify/memory/constitution.md`).

Por Constitution Principle IV, a infraestrutura aqui MUST usar volumes Docker para permitir modificações
em tempo real ("hot-reloading") durante o desenvolvimento, sem exigir rebuild de imagens a cada alteração
de código nos serviços.

## Status atual

- `docker-compose.yml`: sobe os 7 serviços do ecossistema (`resume-app`, `resume-bff`,
  `resume-orchestrator`, `resume-injections`, `resume-embeddings`, `resume-llm-engine`,
  `resume-guard-rails`), o `nginx` e um `auto-updater`. Cada serviço tem seu código-fonte montado como
  volume (bind mount) para hot-reloading — `uvicorn --reload` nos serviços Python, `vite --host` com HMR
  no frontend — sem necessidade de rebuild a cada alteração (Constitution Principle IV).
- `nginx/nginx.conf`: roteamento reverso público — `/` → `resume-app` (com suporte a WebSocket para o
  HMR do Vite), `/bff/` → `resume-bff`, `/orchestrator/` → `resume-orchestrator` (endpoints públicos de
  upload/auditoria de `features/injection/rules.md`). Os demais serviços não são expostos publicamente,
  só acessíveis dentro da rede Docker por outros serviços (Constitution Principle II).
- `scripts/auto-update.sh`: roda dentro do serviço `auto-updater`, mantém sincronizados os 9
  repositórios GitHub independentes deste ecossistema (`resume-ia`, `resume-server`, `resume-app`,
  `resume-bff`, `resume-guard-rails`, `resume-llm-engine`, `resume-injections`, `resume-orchestrator`,
  `resume-embeddings`), para que o hot-reloading já ativo pegue automaticamente qualquer commit novo —
  sem servidor remoto de deploy, só sincronização dos checkouts locais. Sempre fast-forward
  (`--ff-only`), nunca sobrescreve alterações locais.
  - **Gate de CI (`deployed` branch)**: todo repositório que roda de fato dentro do
    `docker-compose` (os 7 serviços + este próprio `resume-server`) tem
    `.github/workflows/main.yml`. **Importante**: uma GitHub Action roda nos servidores do GitHub, não
    consegue acessar a máquina local do desenvolvedor nem os containers já rodando — por isso ela nunca
    faz o `git pull` diretamente; o que ela faz é decidir *o quê* pode ser puxado, avançando um branch
    `deployed` só depois que a pipeline passa. `resume-injections`, `resume-orchestrator` e
    `resume-embeddings` rodam a suíte real (testes unitários + cobertura ≥80%, via `make
    validate-pipeline`); `resume-app` roda lint + build (ainda sem suíte de testes própria); `resume-bff`,
    `resume-guard-rails`, `resume-llm-engine` (ainda stubs, sem `Makefile`/testes) e este próprio
    `resume-server` rodam a validação disponível — `docker build` nos três primeiros, sintaxe de
    `docker-compose.yml`/`nginx.conf` + `shellcheck` nos scripts para `resume-server`. Em todos os casos,
    o job `promote` só roda **depois** (`needs:`) do job de validação passar, e só em `push` real para
    `main` — nunca em PR. `auto-update.sh` rastreia `deployed` (não `main`) em todos esses 8
    repositórios, então o ambiente local só recebe código que já passou pela pipeline. Só o repositório
    externo `resume-ia` (que só guarda o tracking das tasks, não roda em `docker-compose`) continua sem
    gate, com `git pull --ff-only` direto em `main`.

## Estrutura

```
resume-server/
├── docker-compose.yml          # orquestração dos 7 serviços + nginx + auto-updater
├── nginx/
│   └── nginx.conf              # roteamento reverso
└── scripts/
    └── auto-update.sh          # sync periódico nos 9 repositórios (8 deles gated por CI)
```

## Como subir o ambiente

```sh
cd resume-server
docker compose up --build
```

Portas: `resume-app` em `5173`, `resume-bff` em `8001`, `resume-orchestrator` em `8002`,
`resume-injections` em `8003`, `resume-embeddings` em `8004`, `resume-llm-engine` em `8005`,
`resume-guard-rails` em `8006` (todos também acessíveis via `nginx` na porta `80`). Pré-requisito:
`resume-injections`, `resume-orchestrator` e `resume-embeddings` precisam do seu próprio `.env` local já
configurado (copiar `.env.example` → `.env` em cada um) antes de subir.

## Role in the ecosystem (EN)

Network infrastructure and gateway: `docker-compose.yml` orchestrates all 7 services plus `nginx` plus
an `auto-updater` sidecar, each service's source bind-mounted for hot-reload (no rebuild needed for a
code change to take effect, per Constitution Principle IV). `nginx/nginx.conf` publicly routes only to
`resume-app`, `resume-bff`, and `resume-orchestrator`, keeping the other services internal-only per the
Constitution's strict call flow. `scripts/auto-update.sh` keeps each of the 9 independent GitHub repos
in this ecosystem in sync (including `resume-app`, which — like every service under `/services/*` — is
its own separate repo, not tracked by the outer `resume-ia` repo) so the already-running, hot-reloading
containers pick up new commits automatically — there is no remote deploy target in this project, so this
keeps the local checkouts in sync instead. Always fast-forward-only, never overwrites local changes.

**CI gate (`deployed` branch)**: every repo that actually runs inside `docker-compose` (the 7
services plus `resume-server` itself) has `.github/workflows/main.yml`. A GitHub Action runs on
GitHub's own servers — it cannot reach the developer's machine or the already-running containers, so
it never does the `git pull` itself; instead it decides *what's allowed* to be pulled, by only
advancing a `deployed` branch once its validation job passes. `resume-injections`,
`resume-orchestrator`, and `resume-embeddings` run the real suite (unit tests + ≥80% coverage, via
`make validate-pipeline`); `resume-app` runs lint + build (no test suite of its own yet);
`resume-bff`, `resume-guard-rails`, `resume-llm-engine` (still stubs, no `Makefile`/tests) and
`resume-server` itself run whatever validation is meaningful for them — `docker build` for the three
stubs, `docker-compose.yml`/`nginx.conf` syntax + `shellcheck` for `resume-server`. In every case the
`promote` job only runs (`needs:`) after validation passes, and only on a real push to `main` — never
a PR. `auto-update.sh` tracks `deployed` (not `main`) across all 8 of those repos, so the local
environment only ever receives code that has actually passed CI. Only the outer `resume-ia` repo
(task tracking only, doesn't run in `docker-compose`) stays ungated, pulled directly from `main`.
