/* CITYOS-PATCH-003: RTL Mirroring Hooks
 *
 * Enables full right-to-left layout for Arabic locale.
 * CSS logical properties handle most RTL mirroring;
 * this script patches Angular components that hardcode LTR.
 *
 * Applied: loaded conditionally when locale is 'ar'.
 * Removal: when upstream implements full RTL support.
 */
(function() {
  'use strict';

  // Only activate for Arabic locale
  if (document.documentElement.lang !== 'ar') return;

  // Set dir attribute
  document.documentElement.dir = 'rtl';

  // RTL body class for CSS overrides
  document.body.classList.add('cityos-rtl');

  // Patch Gantt chart direction
  angular.module('openproject').run(['$rootScope', function($rootScope) {
    $rootScope.$on('ganttChart.rendered', function() {
      document.querySelectorAll('.gantt-chart').forEach(function(el) {
        el.setAttribute('dir', 'rtl');
      });
    });

    // Mirror board columns
    $rootScope.$on('boardView.rendered', function() {
      document.querySelectorAll('.board-view').forEach(function(el) {
        el.style.flexDirection = 'row-reverse';
      });
    });

    // Mirror timeline direction
    $rootScope.$on('timeline.rendered', function() {
      document.querySelectorAll('.tl-chart').forEach(function(el) {
        el.setAttribute('dir', 'rtl');
      });
    });
  }]);

  // Patch date picker direction
  if (window.flatpickr) {
    var orig = flatpickr.l10ns.default;
    if (orig) {
      orig.firstDayOfWeek = 6; // Saturday (Hijri/Gregorian in KSA)
    }
  }

  console.log('[CityOS HELM] RTL mode activated');
})();
