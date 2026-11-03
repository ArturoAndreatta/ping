{{flutter_js}}
{{flutter_build_config}}

// Sem serviceWorkerSettings: o flutter.js nao registra o worker com ?v= no endereco. Quem registra e o script
// de aviso de versao nova no index.html, sempre em flutter_service_worker.js (endereco fixo).
_flutter.loader.load();
