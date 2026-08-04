# CITYOS-PATCH-001: Branding Assets
# 
# This directory contains CityOS branding assets that replace
# the default OpenProject CE branding.
#
# Applied by Dockerfile.cityos:
#   COPY patches/001-branding/ /app/
#
# Files:
#   app/assets/images/cityos-logo.png      → Main logo (replaces openproject-logo)
#   app/assets/images/cityos-favicon.ico   → Favicon
#   app/assets/stylesheets/cityos-theme.css → CityOS color overrides
#
# Removal condition: Upstream OpenProject CE exposes branding as a
# configurable feature (not Enterprise-gated).

# This directory intentionally empty in the template.
# Add actual branding assets during implementation.
