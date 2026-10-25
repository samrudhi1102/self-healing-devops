# Self-Healing DevOps Deployment Platform

A local FastAPI and Docker project demonstrating health checks and recovery with a PowerShell watchdog. No AWS or paid cloud services are required.

## Components
- FastAPI app with `/`, `/health`, `/ready`, and `/info` endpoints.
- Docker image and Compose service; host port 8002 maps to container port 8000.
- Docker health check and Compose restart policy `unless-stopped`.
- PowerShell watchdog monitors port 8002, restarts only `self-healing-compose-app`, retries health checks, and logs to `logs/recovery.log`.
- GitHub Actions runs pytest and builds a Docker image.

## Requirements and setup
Windows, PowerShell, Docker Desktop with Compose, and Python 3.12+ for local tests.

From the project folder, run:
```powershell
docker compose config
docker compose up --build -d app
docker inspect --format='Status={{.State.Status}} Health={{if .State.Health}}{{.State.Health.Status}}{{else}}not-configured{{end}}' self-healing-compose-app
```
The service is available at `http://localhost:8002`. Stop only this service with `docker compose stop app`.

## API
| Method | Path | Purpose |
| --- | --- | --- |
| GET | `/` | App name and running status |
| GET | `/health` | Health status, service, and UTC timestamp |
| GET | `/ready` | Readiness status |
| GET | `/info` | App name, version, and hostname |

## Tests
Install dependencies with `python -m pip install -r requirements.txt`; run tests with `python -m pytest -v`.
Verified locally: 4 tests passed, with one non-fatal Starlette deprecation warning related to `httpx`.

## Watchdog recovery
Run `.\watchdog.ps1` in a dedicated PowerShell window and leave it open. In another window, test recovery with `docker stop self-healing-compose-app`. Review `logs\recovery.log`; press Ctrl+C in the watchdog window to stop monitoring.
The watchdog targets only the Compose test container on port 8002. The `logs/` folder is ignored by Git and remains local evidence.

## Health and restart behavior
Docker HEALTHCHECK reports whether the app responds to `/health`. Compose `unless-stopped` restarts a container when its main process exits; it does not restart solely because health is unhealthy. The watchdog supplies separate health-based restart behavior.

## CI and verified evidence
The workflow `.github/workflows/ci.yml` runs tests and builds an image on pushes and pull requests to `main`. GitHub Actions: https://github.com/samrudhi1102/self-healing-devops/actions
Verified: all four endpoints responded on port 8002; no-cache Docker build succeeded; recreated container reported running and healthy; recovery log recorded a successful recovery. GitHub Actions run #1 passed for commit `c3277ca`; later untracked files were not included.

## Limitations
Single-machine demonstration. The watchdog must be started manually; there is no alerting, cloud deployment, or external dependency monitoring. The health endpoint checks HTTP responsiveness only; dependencies are not pinned to exact versions.
