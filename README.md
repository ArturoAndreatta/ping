# Ping

**Controle o League of Legends pelo celular.** Você saiu de perto do PC e a fila estourou? Aceite a partida, escolha o campeão, monte as runas e converse no chat, tudo pelo celular.

O Ping é um programinha que fica na bandeja do Windows e conversa só com a API local do client do LoL. O celular manda um toque, o PC executa no client, como se você tivesse clicado. **Nada acontece sem um toque seu.**

## O que dá pra fazer pelo celular

- **Fila**: ver o tempo na fila, buscar partida, sair da fila
- **Partida encontrada**: aceitar ou recusar (com aviso no celular mesmo com o app fechado)
- **Seleção de campeão**: marcar, travar e banir; trocar campeão, posição e ordem com aliados; pegar do banco no ARAM; cartas da ARAM: Desordem; Arena
- **Runas, feitiços e skins**: escolher a página, editar ou criar uma, trocar os feitiços e a skin
- **Sala**: criar sala em qualquer modo, convidar amigos, escolher posição, chat da sala
- **Mensagens**: conversar com os amigos do client
- **Partida em andamento**: tempo, placar, seu KDA e os objetivos; tela de carregamento com os dois times; vitória ou derrota no fim
- **Abrir e fechar o LoL** de longe
- **Hoje**: o resumo das suas partidas do dia

## Como usar

1. Baixe o `Ping-x.y.z.exe` na página de [Releases](../../releases/latest) e abra.
   Se o Windows avisar: *Mais informações > Executar assim mesmo*.
2. Na janela do Ping, crie uma conta (e-mail e senha).
3. Escaneie o QR code com o celular e entre com a mesma conta.
4. No iPhone: *Compartilhar > Adicionar à Tela de Início* (os avisos só chegam assim).

O programa se atualiza sozinho (só com o LoL no menu ou fechado).

## Como funciona

```
 celular (PWA)  <-->  Firebase Realtime Database  <-->  PC (Python, bandeja)  <-->  client do LoL (API local)
```

- `pc/`: programa do Windows. `ponte.py` espelha o estado do client em `ao_vivo/<pc>` e executa os comandos de `comandos/<pc>`; `lcu.py` fala com a API local do client; `painel.py` + `ui/` é a janela de conta e QR; `avisos.py` pede as notificações push.
- `app/`: app do celular em Flutter web (PWA). `?vitrine=<tela>` abre um modo de demonstração com dados de mentira, sem Firebase nem PC.
- `disparador/`: Cloudflare Worker que manda as notificações push (Web Push padrão, sem FCM).
- `database.rules.json`: regras do banco. Só a conta que o PC confirmou lê o estado dele e manda comandos.

Tudo que o PC escreve no client acontece só por comando do celular, pela mesma rota que a tela do client usa, com um intervalo entre duas ações seguidas.

## Hospedar o seu

O Ping público usa o Firebase do projeto (plano grátis). Pra ter o seu:

1. Crie um projeto no Firebase com Realtime Database e Authentication (e-mail/senha e anônimo).
2. Troque o projeto em `pc/servidor.py`, `.firebaserc`, `app/lib/main.dart` (opções do Firebase) e `disparador/wrangler.toml`.
3. `firebase deploy --only database,hosting` (depois de `flutter build web --release --base-href /` em `app/`).
4. Disparador: `cd disparador && npm install && npm run vapid`, ponha a chave pública em `app/lib/push.dart` e no `wrangler.toml`, os segredos `VAPID_PRIVADA` e `FIREBASE_CONTA` (conta de serviço) com `npx wrangler secret put`, e `npx wrangler deploy`. Troque a URL em `pc/servidor.py`.
5. Releases: `python pc/assinatura.py gerar`, ponha a chave pública em `pc/assinatura.py` e a privada no secret `PING_ASSINATURA` do GitHub. Tag `v1.0.0` publica o instalador.

**Limite do plano grátis do Firebase**: o Realtime Database aceita 100 conexões ao mesmo tempo (cada PC e cada celular aberto contam uma). Acima disso, só no plano pago por uso.

## Desenvolvimento

- PC: Python 3.10+ no Windows. `pip install -r pc/requirements.txt` e `pythonw pc/ping.pyw`.
- App: Flutter 3.38. `cd app && flutter pub get && flutter run -d chrome`.
- Testes do disparador: `cd disparador && npm install && npm run teste`.
- Instalador: `python pc/empacotar.py 1.2.3` (Windows).

## Aviso

O Ping não é endossado pela Riot Games e não reflete a visão ou opinião da Riot Games nem de ninguém envolvido oficialmente na produção ou gestão de League of Legends. League of Legends e Riot Games são marcas registradas da Riot Games, Inc. Os sons e imagens do jogo usados no app pertencem à Riot Games.

## Licença

[MIT](LICENSE)
