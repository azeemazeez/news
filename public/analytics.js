// Shared analytics helpers for thenuus.com.
//
// Event names and property shapes are mirrored in ios/TheNuus/Analytics.swift.
// `edition_loaded`, `article_opened` and `archive_date_selected` are the
// cross-platform funnel, so renaming one side without the other quietly
// splits the numbers in two.
//
// Loaded after posthog.js, which installs the queueing stub, so calls made
// before the library finishes downloading are buffered rather than dropped.

(function () {
  'use strict';

  function client() {
    return window.posthog && typeof window.posthog.capture === 'function'
      ? window.posthog
      : null;
  }

  function track(event, properties) {
    var ph = client();
    if (ph) ph.capture(event, properties || {});
  }

  // For clicks that navigate the current tab away: a beacon survives the
  // unload, whereas a normal request can be cancelled mid-flight.
  function trackNavigation(event, properties) {
    var ph = client();
    if (ph) ph.capture(event, properties || {}, { transport: 'sendBeacon' });
  }

  // Outbound clicks are wired once here rather than per page: the publisher
  // link inside a story, and the App Store links in the utility bar and footer.
  document.addEventListener('click', function (event) {
    var link = event.target.closest ? event.target.closest('a[href]') : null;
    if (!link) return;

    if (link.classList.contains('story-link')) {
      // Story links open in a new tab, so the page is not unloading.
      track('article_opened', {
        url: link.href,
        story_source: link.dataset.storySource || null,
        position: Number(link.dataset.storyPosition) || null,
        edition_date: link.dataset.editionDate || null,
      });
      return;
    }

    if (link.href.indexOf('apps.apple.com') !== -1) {
      trackNavigation('app_store_clicked', {
        location: link.closest('.footer') ? 'footer' : 'util_bar',
        page: window.location.pathname,
      });
    }
  });

  window.NuusAnalytics = { track: track, trackNavigation: trackNavigation };
})();
