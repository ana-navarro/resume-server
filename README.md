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
  - **Gate de CI (`deployed` branch)**: `resume-app`, `resume-injections`, `resume-orchestrator` e
    `resume-embeddings` têm pipeline de CI (`.github/workflows/ci.yml` em cada repo). A cada `push` para
    `main`, a CI roda a suíte de testes (unitários + cobertura ≥80% nos três serviços Python, via `make
    validate-pipeline`; lint + build no frontend, que ainda não tem suíte de testes própria — ver nota no
    workflow) e só então avança um branch `deployed` para aquele commit — nunca em PR, só em merge real.
    `auto-update.sh` rastreia `deployed` (não `main`) nesses 4 repositórios, então o ambiente local só
    recebe código que já passou pela pipeline. Os demais 5 repositórios (`resume-ia`, `resume-server`,
    `resume-bff`, `resume-guard-rails`, `resume-llm-engine`) ainda não têm pipeline própria — continuam
    com `git pull --ff-only` direto em `main`, sem gate.

## Estrutura

```
resume-server/
├── docker-compose.yml          # orquestração dos 7 serviços + nginx + auto-updater
├── nginx/
│   └── nginx.conf              # roteamento reverso
└── scripts/
    └── auto-update.sh          # sync periódico nos 9 repositórios (4 deles gated por CI)
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

**CI gate (`deployed` branch)**: `resume-app`, `resume-injections`, `resume-orchestrator`, and
`resume-embeddings` each have a `.github/workflows/ci.yml` that runs the test suite (unit tests +
≥80% coverage gate for the three Python services, via `make validate-pipeline`; lint + build for the
frontend, which has no test suite of its own yet) on every push to `main`, and only then — never on a
PR — fast-forwards a bot-managed `deployed` branch to that commit. `auto-update.sh` tracks `deployed`
(not `main`) for those 4 repos, so the local environment only ever receives code that has actually
passed CI. The remaining 5 repos (`resume-ia`, `resume-server`, `resume-bff`, `resume-guard-rails`,
`resume-llm-engine`) have no pipeline yet and are still pulled directly from `main`, ungated.
