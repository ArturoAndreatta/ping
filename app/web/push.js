/*
 * Notificações push do app (skill notificacoes-push). Sem dependência, carregado no index.html.
 *
 * - iPhone/iPad 18.4+ (app na tela de início): push declarativo, `window.pushManager`, sem service worker.
 * - Resto (Android, PC, iOS 16.4 a 18.3): service worker próprio `push-sw.js`, num escopo só dele
 *   (`push/`), pra não mexer no service worker do Flutter (o do aviso de versão nova).
 *
 * O app chama window.appPush.estado() / ativar(chavePublica) / desativar(); todos devolvem Promise com um
 * objeto simples. A inscrição volta pro app, que grava no banco dele.
 */
(function () {
  function chave(b64) {
    var s = atob(b64.replace(/-/g, '+').replace(/_/g, '/') + '==='.slice((b64.length + 3) % 4));
    var out = new Uint8Array(s.length);
    for (var i = 0; i < s.length; i++) out[i] = s.charCodeAt(i);
    return out;
  }
  var ios = /iPad|iPhone|iPod/.test(navigator.userAgent) ||
    (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
  var telaInicio = window.matchMedia('(display-mode: standalone)').matches || navigator.standalone === true;
  var declarativo = 'pushManager' in window;
  var comSw = 'serviceWorker' in navigator && 'PushManager' in window;

  async function gerente() {
    if (declarativo) return window.pushManager;
    var reg = await navigator.serviceWorker.register('push-sw.js', { scope: 'push/' });
    // o escopo push/ não controla a página, então o `ready` não serve: espera este ativar
    if (!reg.active) {
      var sw = reg.installing || reg.waiting;
      await new Promise(function (ok) {
        if (!sw) return ok();
        sw.addEventListener('statechange', function () { if (sw.state === 'activated') ok(); });
        setTimeout(ok, 10000);
      });
    }
    return reg.pushManager;
  }

  async function inscricaoAtual() {
    if (declarativo) return window.pushManager.getSubscription();
    if (!comSw) return null;
    var reg = await navigator.serviceWorker.getRegistration('push/');
    return reg ? reg.pushManager.getSubscription() : null;
  }

  function simples(insc) {
    if (!insc) return null;
    var j = insc.toJSON();
    return { endpoint: j.endpoint, keys: { p256dh: j.keys.p256dh, auth: j.keys.auth } };
  }

  var pendente = null; // ativarSozinho esperando o primeiro toque
  function limpar() { pendente = null; }

  window.appPush = {
    /** situacao: ativo | desligado | negado | tela_inicio (iPhone fora da tela de início) | sem_suporte */
    estado: async function () {
      var situacao;
      if (!declarativo && !comSw) situacao = ios && !telaInicio ? 'tela_inicio' : 'sem_suporte';
      else if (!('Notification' in window)) situacao = 'sem_suporte';
      else if (Notification.permission === 'denied') situacao = 'negado';
      else {
        var insc = null;
        try { insc = await inscricaoAtual(); } catch (e) {}
        situacao = insc && Notification.permission === 'granted' ? 'ativo' : 'desligado';
        return { situacao: situacao, inscricao: simples(insc), ua: navigator.userAgent.slice(0, 200) };
      }
      return { situacao: situacao, inscricao: null, ua: navigator.userAgent.slice(0, 200) };
    },
    /** Chamar direto do toque (o iPhone só pede permissão dentro do gesto). */
    ativar: async function (publica) {
      var perm = await Notification.requestPermission();
      if (perm !== 'granted') return { situacao: perm === 'denied' ? 'negado' : 'desligado', inscricao: null };
      var g = await gerente();
      var insc = await g.getSubscription();
      if (!insc) insc = await g.subscribe({ userVisibleOnly: true, applicationServerKey: chave(publica) });
      return { situacao: 'ativo', inscricao: simples(insc), ua: navigator.userAgent.slice(0, 200) };
    },
    /**
     * Pra framework que trata o toque fora do evento do navegador (Flutter web: o onTap roda no pointerup).
     * O Safari só mostra o pedido de permissão dentro de um touchend/click de verdade: espera o próximo
     * (que vem logo depois do pointerup) e ativa dentro dele. Sem nenhum em 600ms, tenta direto.
     */
    ativarNoToque: function (publica) {
      var self = this;
      if (pendente) return pendente; // o ligar sozinho já espera o próximo toque: o mesmo pedido serve
      return new Promise(function (resolve, reject) {
        var feito = false;
        function rodar() {
          if (feito) return;
          feito = true;
          document.removeEventListener('touchend', rodar, true);
          document.removeEventListener('click', rodar, true);
          self.ativar(publica).then(resolve, reject);
        }
        document.addEventListener('touchend', rodar, true);
        document.addEventListener('click', rodar, true);
        setTimeout(rodar, 600);
      });
    },
    /**
     * Ligar sozinho (avisos vêm ligados): com a permissão já dada inscreve na hora; sem ela, espera o
     * primeiro toque de verdade em qualquer lugar do app e pede dentro dele (o Safari exige o gesto).
     */
    ativarSozinho: function (publica) {
      var self = this;
      if (Notification.permission === 'granted') return self.ativar(publica);
      if (pendente) return pendente;
      pendente = new Promise(function (resolve, reject) {
        function rodar() {
          document.removeEventListener('touchend', rodar, true);
          document.removeEventListener('click', rodar, true);
          self.ativar(publica).then(resolve, reject);
        }
        document.addEventListener('touchend', rodar, true);
        document.addEventListener('click', rodar, true);
      });
      pendente.then(limpar, limpar);
      return pendente;
    },
    desativar: async function () {
      var insc = await inscricaoAtual();
      var antiga = simples(insc);
      if (insc) await insc.unsubscribe();
      return { situacao: 'desligado', inscricao: antiga };
    },
  };
})();
