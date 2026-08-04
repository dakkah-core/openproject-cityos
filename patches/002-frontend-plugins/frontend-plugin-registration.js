/* CITYOS-PATCH-002: Frontend Plugin Registration
 *
 * Registers CityOS Angular frontend modules in OpenProject's
 * Angular application. OpenProject CE requires this injection
 * point in the frontend build configuration.
 *
 * This file registers:
 *   - cityos-governance-panel (read-only governance tab)
 *   - cityos-command-buttons (Work Control command actions)
 *   - cityos-portfolio-dashboard (portfolio rollup views)
 *   - cityos-release-gate-dashboard (release gate posture)
 *
 * Applied: During OpenProject's frontend build via
 *   patches/002-frontend-plugins/package.json overlay.
 *
 * Removal: when upstream stabilizes a plugin registration API
 *   that does not require core build-tool changes.
 */

// Register Angular modules for CityOS plugins
(function() {
  'use strict';

  angular.module('openproject').requires.push(
    'openproject-cityos-governance',
    'openproject-cityos-command-buttons',
    'openproject-cityos-portfolio'
  );

  // Governance panel registration
  angular.module('openproject-cityos-governance', ['ngRoute'])
    .config(['$routeProvider', function($routeProvider) {
      $routeProvider.when('/work_packages/:id/cityos/governance', {
        templateUrl: '/assets/cityos/governance/panel.html',
        controller: 'CityOSGovernancePanelController'
      });
    }]);

  // Command buttons registration
  angular.module('openproject-cityos-command-buttons', [])
    .directive('cityosCommandButtons', function() {
      return {
        restrict: 'E',
        templateUrl: '/assets/cityos/command-buttons/buttons.html',
        controller: 'CityOSCommandButtonsController',
        scope: {
          workPackageId: '=',
          availableCommands: '='
        }
      };
    });

  // Portfolio dashboard registration
  angular.module('openproject-cityos-portfolio', ['ngRoute'])
    .config(['$routeProvider', function($routeProvider) {
      $routeProvider.when('/cityos/portfolio', {
        templateUrl: '/assets/cityos/portfolio/dashboard.html',
        controller: 'CityOSPortfolioController'
      });
    }]);

  console.log('[CityOS HELM] Frontend plugins registered');
})();
