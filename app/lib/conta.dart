part of 'main.dart';

// ---------------- conta Ping ----------------
//
// Só conta Ping (e-mail e senha) mexe no app: os PCs são os que entraram na mesma conta pelo painel,
// cada um com as contas do LoL que já apareceram nele. Vale em qualquer aparelho.

InputDecoration _decoConta(String dica) => InputDecoration(
  hintText: dica,
  hintStyle: TextStyle(color: Cor.apagado),
  isDense: true,
  filled: true,
  fillColor: Cor.campo,
  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
  enabledBorder: OutlineInputBorder(
    borderRadius: Raio.r1,
    borderSide: BorderSide(color: Cor.linha2),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: Raio.r1,
    borderSide: BorderSide(color: Cor.ouro),
  ),
);

/// Janela no meio da tela, com a mesma entrada do [confirmar].
Future<T?> _janela<T>(BuildContext context, WidgetBuilder corpo) =>
    showGeneralDialog<T>(
      context: context,
      barrierDismissible: true,
      barrierLabel: context.txt.fechar,
      barrierColor: Cor.veu,
      transitionDuration: _dur(context, 220),
      transitionBuilder: (_, a, _, c) => FadeTransition(
        opacity: a,
        child: ScaleTransition(
          scale: Tween(
            begin: 0.94,
            end: 1.0,
          ).animate(CurvedAnimation(parent: a, curve: curvaSaida)),
          child: c,
        ),
      ),
      pageBuilder: (ctx, _, _) => Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Material(
                type: MaterialType.transparency,
                child: Cartao(child: corpo(ctx)),
              ),
            ),
          ),
        ),
      ),
    );

/// Criar conta ou entrar (troca entre os dois dentro da janela).
Future<void> abrirConta(
  BuildContext context,
  Conexao con, {
  bool criar = true,
}) => _janela<void>(context, (_) => _FormConta(con: con, criar: criar));

class _FormConta extends StatefulWidget {
  const _FormConta({
    required this.con,
    required this.criar,
    this.naJanela = true,
  });
  final Conexao con;
  final bool criar;

  /// Na janela fecha ao entrar; na tela de entrar quem troca a tela é a conexão.
  final bool naJanela;

  @override
  State<_FormConta> createState() => _FormContaState();
}

class _FormContaState extends State<_FormConta> {
  final _email = TextEditingController();
  final _senha = TextEditingController();
  late bool _criar = widget.criar;
  String? _erro;

  @override
  void dispose() {
    _email.dispose();
    _senha.dispose();
    super.dispose();
  }

  Future<void> _ir() async {
    FocusScope.of(context).unfocus();
    final c = widget.con;
    final erro = _criar
        ? await c.criarConta(_email.text, _senha.text)
        : await c.entrarConta(_email.text, _senha.text);
    if (!mounted) return;
    if (erro == null && c.email != null) {
      if (widget.naJanela) Navigator.of(context).pop();
      return;
    }
    setState(() => _erro = erro);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.con,
    builder: (context, _) => AutofillGroup(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AnimatedSwitcher(
            duration: _dur(context, 200),
            transitionBuilder: (c, a) => FadeTransition(opacity: a, child: c),
            child: Column(
              key: ValueKey(_criar),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  (_criar
                          ? context.txt.contaCriarTitulo
                          : context.txt.contaEntrarTitulo)
                      .toUpperCase(),
                  style: fonteTitulo(16),
                ),
                const SizedBox(height: 8),
                Text(
                  _criar
                      ? context.txt.contaCriarTexto
                      : context.txt.contaEntrarTexto,
                  style: TextStyle(color: Cor.apagado, fontSize: 14.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.username, AutofillHints.email],
            textInputAction: TextInputAction.next,
            autocorrect: false,
            style: const TextStyle(fontSize: 15.5),
            cursorColor: Cor.ouro,
            decoration: _decoConta(context.txt.contaEmail),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _senha,
            obscureText: true,
            autofillHints: [
              _criar ? AutofillHints.newPassword : AutofillHints.password,
            ],
            textInputAction: TextInputAction.go,
            onSubmitted: (_) => _ir(),
            style: const TextStyle(fontSize: 15.5),
            cursorColor: Cor.ouro,
            decoration: _decoConta(
              _criar ? context.txt.contaSenha6 : context.txt.contaSenha,
            ),
          ),
          AnimatedSwitcher(
            duration: _dur(context, 200),
            transitionBuilder: (c, a) => FadeTransition(opacity: a, child: c),
            child: _erro == null
                ? const SizedBox(width: double.infinity)
                : Padding(
                    key: ValueKey(_erro),
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      _erro!,
                      style: const TextStyle(color: Cor.vermelho, fontSize: 14),
                    ),
                  ),
          ),
          const SizedBox(height: 14),
          Botao(
            texto: _criar
                ? context.txt.contaBotaoCriar
                : context.txt.contaBotaoEntrar,
            principal: true,
            carregando: widget.con.contaOcupada,
            aoTocar: _ir,
          ),
          const SizedBox(height: 8),
          Botao(
            texto: _criar
                ? context.txt.contaJaTenho
                : context.txt.contaCriarNova,
            aoTocar: () => setState(() {
              _criar = !_criar;
              _erro = null;
            }),
          ),
        ],
      ),
    ),
  );
}

/// Grupo Conta Ping da aba Mais: sem conta, o convite; com conta, os PCs (tocar troca) e Sair.
class _GrupoConta extends StatelessWidget {
  const _GrupoConta({required this.con});
  final Conexao con;

  static String _titulo(Map<String, dynamic> p) {
    final n = p['nome'], pc = p['pc'];
    if (n is String && n.isNotEmpty) return n;
    if (pc is String && pc.isNotEmpty) return pc;
    return 'PC';
  }

  /// Nome do PC e as outras contas do LoL que já apareceram nele.
  static String _detalhe(Txt t, Map<String, dynamic> p, bool aberto) {
    final nome = p['nome'];
    final lol = <String>[
      if (p['lol'] is Map)
        for (final v in (p['lol'] as Map).values)
          if (v is String && v != nome) v,
    ]..sort();
    final partes = [
      if (p['pc'] is String && (p['pc'] as String).isNotEmpty) 'PC ${p['pc']}',
      if (lol.isNotEmpty) t.contaTambem(lol.join(', ')),
    ];
    final resto = partes.join(' · ');
    if (aberto) {
      return resto.isEmpty ? t.contaAberto : t.contaAbertoResto(resto);
    }
    return resto.isEmpty ? t.contaToqueAbrir : resto;
  }

  Future<void> _tirar(BuildContext context, String id, String nome) async {
    final sim = await confirmar(
      context,
      titulo: context.txt.contaTirarQ,
      texto: context.txt.contaTirarTexto(nome),
      sim: context.txt.contaTirar,
      nao: context.txt.cancelar,
    );
    if (sim) await con.tirarPc(id);
  }

  Future<void> _sair(BuildContext context) async {
    final sim = await confirmar(
      context,
      titulo: context.txt.contaSairQ,
      texto: context.txt.contaSairTexto,
      sim: context.txt.contaSair,
      nao: context.txt.cancelar,
    );
    if (sim) await con.sairConta();
  }

  @override
  Widget build(BuildContext context) {
    Widget seta() =>
        Icon(Icons.chevron_right_rounded, color: Cor.apagado, size: 24);
    final email = con.email;
    if (email == null) {
      return _Grupo(
        titulo: context.txt.contaTitulo,
        children: [
          _LinhaMais(
            icone: Icons.shield_outlined,
            titulo: context.txt.contaBotaoCriar,
            texto: context.txt.contaCriarLinha,
            final_: seta(),
            aoTocar: () => abrirConta(context, con),
          ),
          _LinhaMais(
            icone: Icons.login_rounded,
            titulo: context.txt.contaJaTenho,
            texto: context.txt.contaEntrarLinha,
            final_: seta(),
            aoTocar: () => abrirConta(context, con, criar: false),
          ),
        ],
      );
    }
    // o aberto primeiro, depois do mais antigo pro mais novo
    final ids = con.pcs.keys.toList()
      ..sort((a, b) {
        if (a == con.pc) return -1;
        if (b == con.pc) return 1;
        final da = (con.pcs[a]!['desde'] as num?) ?? 0;
        final db = (con.pcs[b]!['desde'] as num?) ?? 0;
        return da.compareTo(db);
      });
    return _Grupo(
      titulo: context.txt.contaTitulo,
      children: [
        _LinhaMais(
          icone: Icons.verified_user_outlined,
          titulo: email,
          texto: ids.length > 1
              ? context.txt.contaPcsN(ids.length)
              : context.txt.contaQualquerCel,
          final_: const SizedBox.shrink(),
        ),
        for (final id in ids)
          _LinhaMais(
            key: ValueKey('pc-$id'),
            icone: id == con.pc
                ? Icons.desktop_windows_rounded
                : Icons.desktop_windows_outlined,
            titulo: _titulo(con.pcs[id]!),
            texto: _detalhe(context.txt, con.pcs[id]!, id == con.pc),
            final_: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSwitcher(
                  duration: _dur(context, 200),
                  transitionBuilder: (c, a) => FadeTransition(
                    opacity: a,
                    child: ScaleTransition(scale: a, child: c),
                  ),
                  child: id == con.pc
                      ? Icon(
                          Icons.check_rounded,
                          key: ValueKey('aberto'),
                          color: Cor.teal,
                          size: 22,
                        )
                      : const SizedBox(key: ValueKey('fechado'), width: 22),
                ),
                Semantics(
                  button: true,
                  label: context.txt.contaTirarSem,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _tirar(context, id, _titulo(con.pcs[id]!)),
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: Icon(
                        Icons.close_rounded,
                        color: Cor.apagado,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            aoTocar: id == con.pc ? null : () => con.trocarPc(id),
          ),
        _LinhaMais(
          icone: Icons.add_rounded,
          titulo: context.txt.contaOutroPc,
          texto: context.txt.contaOutroPcTexto,
          final_: SizedBox.shrink(),
        ),
        _LinhaMais(
          icone: Icons.logout_rounded,
          titulo: context.txt.contaSairLinha,
          texto: context.txt.contaSairLinhaTexto,
          final_: con.contaOcupada
              ? SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Cor.ouro,
                  ),
                )
              : seta(),
          aoTocar: () => _sair(context),
        ),
      ],
    );
  }
}
