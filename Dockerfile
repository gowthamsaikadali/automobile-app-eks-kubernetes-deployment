FROM python:3.12-slim

WORKDIR /app

# Copy requirements first so Docker caches this layer — dependencies change
# far less often than app code, so this avoids a full pip install on every
# code-only change.
COPY app/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app/ .

# Run as non-root — a basic hardening step, and something interviewers
# specifically ask about for container security.
RUN useradd -m appuser
USER appuser

EXPOSE 5000

# gunicorn instead of Flask's dev server — the dev server isn't meant for
# anything but local debugging, even inside a container.
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "2", "app:app"]
