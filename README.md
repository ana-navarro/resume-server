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
- `scripts/auto-update.sh`: roda dentro do serviço `auto-updater`, faz `git pull --ff-only` periódico em
  cada um dos 8 repositórios GitHub independentes deste ecossistema (`resume-ia`, `resume-server`,
  `resume-bff`, `resume-guard-rails`, `resume-llm-engine`, `resume-injections`, `resume-orchestrator`,
  `resume-embeddings`), para que o hot-reloading já ativo pegue automaticamente qualquer commit novo
  enviado ao GitHub — sem servidor remoto de deploy, só sincronização dos checkouts locais.

## Estrutura

```
resume-server/
├── docker-compose.yml          # orquestração dos 7 serviços + nginx + auto-updater
├── nginx/
│   └── nginx.conf              # roteamento reverso
└── scripts/
    └── auto-update.sh          # git pull --ff-only periódico nos 8 repositórios
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
Constitution's strict call flow. `scripts/auto-update.sh` periodically fast-forward-pulls each of the 8
independent GitHub repos in this ecosystem so the already-running, hot-reloading containers pick up new
commits automatically — there is no remote deploy target in this project, so this keeps the local
checkouts in sync instead.
