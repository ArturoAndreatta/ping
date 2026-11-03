# Ping (app do celular)

Ping: controle o League of Legends pelo celular. PWA em Flutter web, servida na raiz do site (`--base-href /`).

- Entrar: conta Ping (e-mail e senha). O PC entra na mesma conta pelo painel dele (página Conta) e aparece aqui na hora.
- Lê o estado do PC em `ao_vivo/<pc>` e manda comandos em `comandos/<pc>` (Realtime Database). Os PCs da conta ficam em `contas/<uid>/pcs`.
- Avisos com o app fechado (push): a inscrição de cada aparelho fica em `push/<uid>/<aparelho>`; quem manda é o disparador da pasta `disparador/`.
- Modo de demonstração sem Firebase nem PC: abra com `?vitrine=<tela>` (lista em `lib/vitrine.dart`).

## Build

```
flutter pub get
flutter build web --release --base-href /
```

## Teste local com os emuladores do Firebase

Database na porta 9411 e Auth na 9412:

```
flutter build web --release --base-href / --dart-define=EMU=true
```
