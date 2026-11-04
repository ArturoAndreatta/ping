part of 'main.dart';

/// Avisos no celular com o app fechado (notificação push). Quem manda é o disparador na Cloudflare
/// (pasta `disparador/` deste repositório, projeto `ping`), a pedido do PC. Cada aparelho guarda junto da
/// inscrição, em `push/<uid>/<aparelho>`, o que quer receber: `pc` (o PC que ele ouve; o disparador só
/// manda o aviso de um PC pro aparelho que escolheu ele), `tipos` e `sempre` (avisar mesmo com você no PC).

typedef TipoAviso = ({
  String id,
  String nome,
  String texto,
  IconData icone,
  bool padrao,
});

/// A mesma lista (ids e padrões) do disparador (`disparador/`, projeto `ping`) e do PC.
const tiposAviso = <TipoAviso>[
  (
    id: 'fila',
    nome: 'Entrou na fila',
    texto: 'Quando você ou o líder da sala entra na fila.',
    icone: Icons.hourglass_top_rounded,
    padrao: true,
  ),
  (
    id: 'partida',
    nome: 'Partida encontrada',
    texto: 'Quando a fila acha partida.',
    icone: Icons.sports_esports_outlined,
    padrao: true,
  ),
  (
    id: 'vez',
    nome: 'Sua vez',
    texto: 'Quando chega sua vez de escolher ou banir.',
    icone: Icons.touch_app_outlined,
    padrao: true,
  ),
  (
    id: 'troca',
    nome: 'Pedido de troca',
    texto: 'Quando um aliado pede troca na seleção.',
    icone: Icons.swap_horiz_rounded,
    padrao: true,
  ),
  (
    id: 'convite',
    nome: 'Convite pra sala',
    texto: 'Quando alguém chama você pra sala.',
    icone: Icons.group_add_outlined,
    padrao: true,
  ),
  (
    id: 'mensagem',
    nome: 'Mensagens',
    texto: 'Mensagem de amigo no chat privado ou da sala.',
    icone: Icons.chat_bubble_outline_rounded,
    padrao: true,
  ),
  (
    id: 'lol_pronto',
    nome: 'LoL aberto',
    texto: 'Quando o LoL que você abriu pelo celular fica pronto.',
    icone: Icons.power_settings_new_rounded,
    padrao: true,
  ),
  (
    id: 'fim',
    nome: 'Fim da partida',
    texto: 'Vitória ou derrota, com o seu placar.',
    icone: Icons.emoji_events_outlined,
    padrao: false,
  ),
  (
    id: 'resumo',
    nome: 'Resumo do dia',
    texto: 'Quando você fecha o LoL.',
    icone: Icons.today_outlined,
    padrao: false,
  ),
];

class Avisos extends ChangeNotifier {
  Avisos(this.con);
  final Conexao con;

  static Avisos? _eu;
  static Avisos eu(Conexao con) =>
      _eu ??= con is ConexaoVitrine ? _AvisosVitrine(con) : Avisos(con);

  /// Situação do push neste navegador (ver [Push]); null enquanto não conferiu.
  String? situacao;
  bool ocupado = false;
  String? erro;

  /// "Avisar neste celular" (guardado no aparelho: o push do navegador é do aparelho todo). Vem ligado:
  /// só fica desligado se você desligou na mão.
  bool ligado = true;
  bool sempre = false;
  Map<String, bool> tipos = {};

  bool get ativo => ligado && situacao == 'ativo';
  bool quer(TipoAviso t) => tipos[t.id] ?? t.padrao;

  Map<String, dynamic>? _insc;
  String _ua = '';
  String?
  _gravadoEm; // uid|pc da última gravação: muda (conta nova, outro PC), grava de novo
  bool _carregou = false;
  String? _conferido; // uid|pc da última conferência
  bool _conferindo = false;

  /// Id deste aparelho em `push/<uid>`: um nó por aparelho, guardado no próprio aparelho.
  static Future<String> aparelho() async {
    final p = await SharedPreferences.getInstance();
    var id = p.getString('push-aparelho');
    if (id == null) {
      final r = math.Random.secure();
      id = List.generate(
        12,
        (_) => 'abcdefghijkmnpqrstuvwxyz23456789'[r.nextInt(32)],
      ).join();
      await p.setString('push-aparelho', id);
    }
    return id;
  }

  Future<void> _carregar() async {
    if (_carregou) return;
    _carregou = true;
    try {
      final p = await SharedPreferences.getInstance();
      // `avisos-ligado` (antigo) gravava false mesmo sem você desligar: só o desligar na mão conta
      ligado = !(p.getBool('avisos-desligou') ?? false);
      sempre = p.getBool('avisos-sempre') ?? false;
      final t = jsonDecode(p.getString('avisos-tipos') ?? '{}');
      if (t is Map) {
        tipos = {
          for (final e in t.entries)
            if (e.value is bool) '${e.key}': e.value as bool,
        };
      }
    } catch (e) {
      debugPrint('Ping avisos: $e');
    }
  }

  Future<void> _salvar() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool('avisos-desligou', !ligado);
      await p.setBool('avisos-sempre', sempre);
      await p.setString('avisos-tipos', jsonEncode(tipos));
    } catch (e) {
      debugPrint('Ping avisos: $e');
    }
  }

  /// Ao abrir o app e quando o vínculo muda: confere o push e regrava (o endereço da inscrição muda às
  /// vezes; o disparador apaga as mortas).
  Future<void> conferir() async {
    final chave = '${_uid()}|${con.pc}';
    if (_conferindo || chave == _conferido) return;
    _conferindo = true;
    try {
      await _carregar();
      final e = await Push.estado();
      situacao = e.situacao;
      _guardar(e);
      notifyListeners();
      if (ativo) await _gravar();
      if (ligado && situacao == 'desligado') _ligarSozinho();
      _conferido = chave;
    } catch (e) {
      debugPrint('Ping avisos: $e');
    }
    _conferindo = false;
  }

  bool _esperandoToque = false;

  /// Ligado mas sem inscrição: inscreve sozinho (com a permissão já dada, na hora; sem ela, o pedido
  /// aparece no primeiro toque no app). Recusou a permissão: fica `negado`, sem pedir de novo.
  Future<void> _ligarSozinho() async {
    if (_esperandoToque) return;
    _esperandoToque = true;
    try {
      final e = await Push.ativarSozinho();
      if (!ligado) return; // desligou na mão enquanto esperava
      situacao = e.situacao;
      _guardar(e);
      notifyListeners();
      if (ativo) await _gravar();
    } catch (e) {
      debugPrint('Ping avisos: $e');
    } finally {
      _esperandoToque = false;
    }
  }

  void _guardar(EstadoPush e) {
    if (e.inscricao != null) _insc = e.inscricao;
    if (e.ua.isNotEmpty) _ua = e.ua;
  }

  String? _uid() {
    try {
      return FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {
      return null;
    }
  }

  Future<void> _gravar() async {
    final uid = _uid(), pc = con.pc, insc = _insc;
    if (uid == null || pc == null || insc == null) return;
    final chave = '$uid|$pc';
    final ap = await aparelho();
    final db = FirebaseDatabase.instance;
    final antes = _gravadoEm?.split('|').first;
    if (antes != null && antes != uid) {
      // trocou de conta: o nó do uid antigo não serve mais (o disparador só manda pra conta do PC)
      db.ref('push/$antes/$ap').remove().catchError((_) {});
    }
    await db.ref('push/$uid/$ap').update({
      'endpoint': insc['endpoint'],
      'keys': insc['keys'],
      'em': ServerValue.timestamp,
      if (_ua.isNotEmpty) 'ua': _ua.length > 200 ? _ua.substring(0, 200) : _ua,
      'pc': pc,
      'sempre': sempre,
      for (final t in tiposAviso) 'tipos/${t.id}': quer(t),
    });
    _gravadoEm = chave;
  }

  /// Liga ou desliga. Ligar tem que vir direto do toque (o iPhone só pede a permissão dentro dele).
  Future<void> mudar(bool ligar) async {
    if (ocupado) return;
    ocupado = true;
    erro = null;
    notifyListeners();
    try {
      if (ligar) {
        final e = await Push.ativar();
        situacao = e.situacao;
        _guardar(e);
        if (e.situacao == 'ativo') {
          ligado = true;
          await _salvar();
          await _gravar();
        }
      } else {
        ligado = false;
        await _salvar();
        final uid = _uid();
        if (uid != null) {
          await FirebaseDatabase.instance
              .ref('push/$uid/${await aparelho()}')
              .remove();
        }
        _gravadoEm = null;
        final e = await Push.desativar();
        situacao = e.situacao;
      }
    } catch (err) {
      debugPrint('Ping avisos: $err');
      erro = 'Não consegui mudar o aviso neste celular.';
    }
    ocupado = false;
    notifyListeners();
  }

  Future<void> mudarTipo(TipoAviso t, bool v) async {
    tipos = {...tipos, t.id: v};
    notifyListeners();
    await _salvar();
    if (ativo) await _atualizar({'tipos/${t.id}': v});
  }

  Future<void> mudarSempre(bool v) async {
    sempre = v;
    notifyListeners();
    await _salvar();
    if (ativo) await _atualizar({'sempre': v});
  }

  Future<void> _atualizar(Map<String, Object?> patch) async {
    final uid = _uid();
    if (uid == null) return;
    try {
      await FirebaseDatabase.instance
          .ref('push/$uid/${await aparelho()}')
          .update(patch);
    } catch (e) {
      debugPrint('Ping avisos: $e');
      erro = 'Não salvou. Confira a internet.';
      notifyListeners();
    }
  }
}

/// Vitrine: sem Firebase nem push de verdade.
class _AvisosVitrine extends Avisos {
  _AvisosVitrine(super.con) {
    situacao = 'ativo';
    ligado = true;
    _carregou = true;
  }

  @override
  Future<void> conferir() async {}

  @override
  Future<void> mudar(bool ligar) async {
    ocupado = true;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 500));
    ligado = ligar;
    ocupado = false;
    notifyListeners();
  }

  @override
  Future<void> mudarTipo(TipoAviso t, bool v) async {
    tipos = {...tipos, t.id: v};
    notifyListeners();
  }

  @override
  Future<void> mudarSempre(bool v) async {
    sempre = v;
    notifyListeners();
  }
}

/// Texto do "Avisar neste celular" pela situação do push.
String textoPush(String? s, {required bool ligado}) => switch (s) {
  'ativo' when ligado => 'Ligado: chega mesmo com o app fechado.',
  'ativo' || 'desligado' => 'Chega mesmo com o app fechado.',
  'negado' => 'Recusado nos ajustes do celular.',
  'tela_inicio' => 'Adicione o app à tela de início pra ligar.',
  null => 'Conferindo...',
  _ => 'Este navegador não recebe avisos.',
};

/// Os dois cartões de Avisos (este celular e o que avisar): na página da aba Mais.
({Widget geral, Widget tipos}) _cartoesAvisos(
  BuildContext context,
  Conexao con,
  Avisos av,
) {
  final pode = av.situacao == 'ativo' || av.situacao == 'desligado';
  const lista = tiposAviso;
  final geral = _Grupo(
    titulo: 'Este celular',
    children: [
      _LinhaMais(
        icone: av.ativo
            ? Icons.notifications_active_outlined
            : Icons.notifications_none_rounded,
        titulo: 'Avisar neste celular',
        texto: av.erro ?? textoPush(av.situacao, ligado: av.ligado),
        final_: AnimatedOpacity(
          opacity: pode ? 1 : 0,
          duration: _dur(context, 200),
          child: _Alavanca(
            ligado: av.ativo,
            carregando: av.ocupado,
            ativo: pode,
            aoMudar: av.mudar,
          ),
        ),
      ),
      _LinhaMais(
        icone: Icons.computer_rounded,
        titulo: 'Mesmo com você no PC',
        texto: 'Avisa enquanto você está no PC.',
        final_: _Alavanca(
          ligado: av.sempre,
          ativo: av.ativo,
          aoMudar: av.mudarSempre,
        ),
      ),
    ],
  );
  final tipos = _Grupo(
    titulo: 'O que avisar',
    children: [
      for (final t in lista)
        _LinhaMais(
          key: ValueKey('aviso-${t.id}'),
          icone: t.icone,
          titulo: t.nome,
          texto: t.texto,
          final_: _Alavanca(
            ligado: av.quer(t),
            ativo: av.ativo,
            aoMudar: (v) => av.mudarTipo(t, v),
          ),
        ),
    ],
  );
  return (geral: geral, tipos: tipos);
}

/// Página Avisos no celular (abre por cima da lista da aba Mais).
class _PaginaAvisos extends StatelessWidget {
  const _PaginaAvisos({
    super.key,
    required this.con,
    required this.aoVoltar,
    this.base = 0,
  });
  final Conexao con;
  final VoidCallback aoVoltar;
  final double base;

  @override
  Widget build(BuildContext context) {
    final av = Avisos.eu(con);
    final deitado = _deitado(context);
    return ListenableBuilder(
      listenable: av,
      builder: (context, _) {
        final c = _cartoesAvisos(context, con, av);
        return _Rolavel(
          base: base,
          largura: deitado ? 900 : 520,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Voltar(aoTocar: aoVoltar, titulo: 'Avisos'),
              const SizedBox(height: 10),
              if (deitado)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _Entrada(chave: 'avisos-geral', child: c.geral),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _Entrada(
                        chave: 'avisos-tipos',
                        atraso: 40,
                        child: c.tipos,
                      ),
                    ),
                  ],
                )
              else ...[
                _Entrada(chave: 'avisos-geral', child: c.geral),
                const SizedBox(height: 14),
                _Entrada(chave: 'avisos-tipos', atraso: 40, child: c.tipos),
              ],
            ],
          ),
        );
      },
    );
  }
}
