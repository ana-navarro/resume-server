# resume-server

## Papel no ecossistema (PT)

Infraestrutura e Gateway de Rede do Currículo Interativo: configurações do NGINX, orquestração de
containers (`docker-compose.yml`) e scripts relacionados (ver Constitution Principle I,
`.specify/memory/constitution.md`).

Por Constitution Principle IV, a infraestrutura aqui MUST usar volumes Docker para permitir modificações
em tempo real ("hot-reloading") durante o desenvolvimento, sem exigir rebuild de imagens a cada alteração
de código nos serviços.

## Status atual

- `nginx/nginx.conf`: existe mas ainda está vazio — o roteamento reverso para os serviços
  (`resume-app`, `resume-bff`, etc.) ainda precisa ser configurado.
- `docker-compose.yml`: existe mas ainda está vazio — a orquestração dos containers de todos os
  `/services/*` e `/apps/resume-app` (incluindo os volumes de hot-reloading exigidos pela Principle IV)
  ainda precisa ser definida.

## Estrutura

```
resume-server/
├── docker-compose.yml   # orquestração dos containers (a implementar)
└── nginx/
    └── nginx.conf        # roteamento reverso (a implementar)
```

## Como subir o ambiente (quando implementado)

```sh
cd resume-server
docker compose up --build
```

## Role in the ecosystem (EN)

Network infrastructure and gateway: NGINX configuration, container orchestration
(`docker-compose.yml`), and related scripts. Both `nginx/nginx.conf` and `docker-compose.yml` currently
exist but are empty — routing and container orchestration (including the Docker volumes required for
hot-reloading, per Constitution Principle IV) have not been implemented yet.
