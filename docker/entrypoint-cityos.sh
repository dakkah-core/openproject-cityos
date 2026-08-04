#!/bin/bash
# CityOS HELM entrypoint wrapper
# Runs before the standard OpenProject entrypoint
set -e

echo "[CityOS HELM] Entrypoint starting..."

# Ensure CityOS plugins are registered
if [ -d /app/modules/cityos ]; then
  for plugin in /app/modules/cityos/*/; do
    plugin_name=$(basename "$plugin")
    echo "[CityOS HELM] Plugin detected: ${plugin_name}"
  done
fi

# Run CityOS config seeder (idempotent)
if [ -f /app/config/cityos-helm-manifest.yml ]; then
  echo "[CityOS HELM] Applying config manifest..."
  bundle exec rails runner "CityOS::Foundation::Seeder.apply('/app/config/cityos-helm-manifest.yml')" 2>&1 || \
    echo "[CityOS HELM] Seeder skipped (DB not ready or plugin not loaded)"
fi

echo "[CityOS HELM] Entrypoint complete."

exec /app/docker/prod/entrypoint.sh "$@"
