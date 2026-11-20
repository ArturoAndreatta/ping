# Ping

Controle o League of Legends pelo celular. Repositório público (MIT).

## Regra principal

O Ping só faz o que você pede pelo celular. Nada de ação sozinha no client: nada de aceitar, escolher, banir, mudar runa, feitiço ou skin sem um toque no app. Toda escrita no client:

- vem de um comando do celular (`ponte.executar`)
- usa a mesma rota e o mesmo corpo da tela do client
- nunca sai no mesmo instante que outra (`_espacar`, `_no_ritmo`); travar e banir sempre marcam antes (`_escolher`)
- leitura (GET) local é livre; cada POST/PATCH/PUT/DELETE conta

## Partes

| Pasta | Papel |
|---|---|
| `pc/` | Programa do Windows (Python). `ping.pyw` bandeja e threads; `ponte.py` estado do client em `ao_vivo/<pc>` e comandos de `comandos/<pc>`; `lcu.py` API local do client e dados do jogo; `painel.py` + `ui/index.html` janela de conta, QR, Hoje e opções; `avisos.py` pede push; `hoje.py` resumo do dia; `atualizar.py` atualiza pelo GitHub Releases (versao.json assinado, `assinatura.py`); `empacotar.py` gera o .exe (IExpress + Python do NuGet); `servidor.py` endereços do Firebase e do disparador; `idioma.py` idioma do PC (Windows ou escolha nas opções) e textos do Python |
| `app/` | PWA em Flutter web. `?vitrine=<tela>` = demonstração sem Firebase |
| `disparador/` | Cloudflare Worker `ping-avisos`: POST /aviso do PC com o ID token; tipos em `src/ping.js` (os mesmos de `app/lib/avisos.dart`) |
| `tool/` | Scripts de apoio rodados da raiz: `prints.py` refaz os prints do README |
| `database.rules.json` | Regras do RTDB: `pcs`, `contas`, `ao_vivo`, `comandos`, `push` |

Projeto Firebase: `ping-celular` (Hosting na raiz, `--base-href /`). Segredos fora do repo: `~/.ping/` (assinatura.key, vapid.json, conta-servico.json) e secrets do GitHub (`PING_ASSINATURA`, `FIREBASE_SERVICE_ACCOUNT_PING`).

## Contrato PC e celular

- Estado: chaves em `ponte.CHAVES_ESTADO`. Chave nova vai lá e no app.
- Texto pro celular é código estável em snake_case (status de amigo, grupo de modo, aviso do chat, `resposta.msg`), com o dado variável em `p` (resposta) ou `quem` (aviso). O app traduz em `app/lib/codigos.dart` + as três ARB; código desconhecido aparece cru (PC antigo ainda manda PT). Código novo no PC pede ramo lá e nas ARB (o teste confere). Nomes de fila e de jogo vêm do client, já no idioma dele (`lcu.locale_dd`).
- Comandos: tipos em `ponte.executar` e na regex do `database.rules.json` (os dois juntos).
- Avisos: tipos em `disparador/src/ping.js` e `app/lib/avisos.dart`.
- Campo novo num comando: também na lista `$campo` (e nos limites) de `comandos` no `database.rules.json`, senão o banco recusa.
- Serviços de push aceitos (Chrome, Firefox, Safari, Edge): regex em `database.rules.json` (`push`) e `SERVICOS` em `disparador/src/webpush.js`, os dois juntos.
- O PC só executa comando com `de` igual ao uid da conta dele (`cache/conta.json`), além das regras.

## Convenções

- Português do Brasil, "você". Sem travessão nem meia-risca.
- Log (`ping.log`) e scripts `.ps1` em ASCII.
- Commits: Conventional Commits em português, só assunto.
- UI nunca seca: transição de abrir e fechar, `prefers-reduced-motion` respeitado.

## Testar

- PC: LCU falso (classe com `get`/`req`) trocando `lcu.get`/`lcu.req`, cache numa pasta temporária (`lcu.CACHE`). Testes prontos: `cd pc; python -m unittest discover testes`.
- App: `flutter analyze`, `flutter test`, `flutter build web --release --base-href /`, vitrine (`?vitrine=<tela>&idioma=en|es|pt`).
- Regras: emuladores do Firebase (database 9411, auth 9412) ou um projeto de teste.
- Disparador: `npm run teste`.
- Prints do README (`docs/`): `python tool/prints.py` (compila o app e tira cada tela pela vitrine). Refazer quando a tela mostrada mudar.
- Release: workflow `release.yml` à mão (`workflow_dispatch` com uma versão) testa o .exe num Windows limpo.
- Mudança em `pc/` só chega no Ping instalado com uma tag nova (`vX.Y.Z`): o push da tag publica o release em uns 2 min. Com o release no ar, Reiniciar (bandeja ou janela) já sobe com a versão nova.
