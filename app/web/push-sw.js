/*
 * Service worker só das notificações (skill notificacoes-push), no escopo `push/`. Mostra o mesmo JSON
 * declarativo que o iPhone 18.4+ mostra sozinho: { web_push: 8030, notification: { title, body, navigate } }.
 * Tocar abre (ou foca) o app no endereço do aviso.
 */
self.addEventListener('install', function () { self.skipWaiting(); });

self.addEventListener('push', function (e) {
  var j = {};
  try { j = e.data ? e.data.json() : {}; } catch (_) { j = { notification: { title: e.data ? e.data.text() : 'Aviso' } }; }
  var n = j.notification || {};
  e.waitUntil(self.registration.showNotification(n.title || 'Aviso', {
    body: n.body || '',
    lang: n.lang, dir: n.dir, silent: n.silent,
    icon: 'icons/Icon-192.png', badge: 'icons/Icon-192.png',
    data: { link: n.navigate || self.registration.scope.replace(/push\/$/, '') },
  }));
  if (n.app_badge && self.navigator.setAppBadge) self.navigator.setAppBadge(Number(n.app_badge)).catch(function () {});
});

self.addEventListener('notificationclick', function (e) {
  e.notification.close();
  var link = (e.notification.data && e.notification.data.link) || '/';
  e.waitUntil(self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then(function (abas) {
    for (var i = 0; i < abas.length; i++) {
      if (abas[i].url.indexOf(new URL(link, self.location).origin) === 0 && 'focus' in abas[i]) {
        return abas[i].focus();
      }
    }
    return self.clients.openWindow(link);
  }));
});
