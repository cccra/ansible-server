# Upstream publishes to PyPI only, so this builds its source into an image, with the
# dependencies its lockfile pins, as its deployment guide installs them. Python 3.12 is
# the newest release upstream's CI tests against.

FROM python:3.12-slim AS builder

COPY --from=ghcr.io/astral-sh/uv:0.11 /uv /bin/uv

# Bytecode is compiled here because the container runs as a user who cannot write it
# into the venv later. The image's own Python is used, never a managed download, so the
# venv points at the same interpreter the runtime stage has.
ENV UV_COMPILE_BYTECODE=1 UV_PYTHON_DOWNLOADS=never

WORKDIR /app
COPY . .

# --no-editable installs the project into the venv rather than linking back to src/,
# so the venv is all the runtime stage needs.
RUN uv sync --locked --no-dev --no-editable

FROM python:3.12-slim

COPY --from=builder /app/.venv /app/.venv

ENV PATH="/app/.venv/bin:$PATH" PYTHONUNBUFFERED=1

EXPOSE 8000

CMD ["nextcloud-organizer-mcp"]
