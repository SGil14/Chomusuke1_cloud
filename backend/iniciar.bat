@echo off
rem Levanta la API en modo desarrollo (se recarga sola al guardar cambios).
cd /d "%~dp0"
set PYTHONIOENCODING=utf-8
.venv\Scripts\alembic upgrade head || exit /b 1
.venv\Scripts\python -m uvicorn app.main:app --reload --port 8000
