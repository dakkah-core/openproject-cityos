# CITYOS-PATCH-002: Frontend Plugin Registration
#
# OpenProject CE requires modifications to frontend/package.json
# to register custom Angular frontend plugins. This is a known
# limitation — the frontend plugin API requires core build-tool changes.
#
# The patched package.json adds CityOS frontend module references.
#
# Removal condition: Upstream OpenProject stabilizes a frontend
# plugin registration API that does not require core package.json edits.

# This directory intentionally empty in the template.
# Add patched package.json during implementation.
