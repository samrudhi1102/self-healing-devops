from fastapi import FastAPI
from datetime import datetime, timezone
import os

app = FastAPI(
    title="Self-Healing DevOps Platform",
    version="1.0.0"
)

START_TIME = datetime.now(timezone.utc)


@app.get("/")
def home():
    return {
        "message": "Self-Healing DevOps Platform",
        "status": "running"
    }


@app.get("/health")
def health():
    return {
        "status": "healthy",
        "service": "self-healing-devops",
        "timestamp": datetime.now(timezone.utc).isoformat()
    }


@app.get("/ready")
def readiness():
    return {
        "status": "ready"
    }


@app.get("/info")
def info():
    return {
        "app": "self-healing-devops",
        "version": "1.0.0",
        "hostname": os.getenv("HOSTNAME", "local")
    }