# AGENTS.md — runner

## What this is
"Fatty" Docker runner image pre-installed with tools (psql, curl, wget, git, Node.js, Python, etc.) for executing post-startup tasks in docker-compose workflows and CI/CD pipelines.

## Stack
- Docker (Debian base)
- Shell scripts (bash)
- PostgreSQL client
- Node.js, Python

## Build
```bash
docker build -t myridia/runner .
```

## Run
Used as a service in docker-compose with `depends_on` other services. Executes `runner.sh` after dependencies start.

## Structure
- `Dockerfile` — Debian image with pre-installed tools
- `Makefile` — build shortcuts
- `remove_all_dockers.sh` — cleanup script
- `pages/public/img/` — logos and screenshots
- `.github/workflows/publish.yml` — CI publish workflow

## Conventions
- No comments in code unless asked.
- Verify: `docker build -t myridia/runner .`
