# tool/

Scripts de apoio. Rode da raiz do repositório.

| Em vez de | Use |
|---|---|
| tirar os prints do README na mão | `python tool/prints.py` |

`prints.py` compila o app, abre cada tela no modo vitrine e a janela do PC com a API respondida pelo próprio script, e grava em `docs/`. Telas soltas: `python tool/prints.py pick painel`. Flags: `--skip-build` (usa o `app/build/web` em disco), `--saida <pasta>`, `--dry-run`, `--no-color`.

Precisa de `pip install playwright pillow` e `python -m playwright install chromium`.

`cli.py` é a base visual dos scripts (marca, etapas, resumo).
