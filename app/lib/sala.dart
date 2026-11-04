part of 'main.dart';

const _posicoes = {
  'TOP': 'Topo',
  'JUNGLE': 'Selva',
  'MIDDLE': 'Meio',
  'BOTTOM': 'Atirador',
  'UTILITY': 'Suporte',
  'FILL': 'Qualquer',
};

String _icone(int id) =>
    'https://raw.communitydragon.org/latest/plugins/rcp-be-lol-game-data/global/default/v1/profile-icons/$id.jpg';

/// Quem está na sala.
class _CartaoSala extends StatelessWidget {
  const _CartaoSala({
    required this.con,
    required this.sala,
    this.deitado = false,
    this.emPe = false,
  });
  final Conexao con;
  final Map sala;

  /// Em pé com tela fixa: só quem está na sala e a vaga de convidar; as ações vão pro pé da tela.
  final bool emPe;

  /// Deitado: só quem está na sala (lista rola por dentro) e Convidar; buscar e sair vão pra
  /// linha embaixo do chat.
  final bool deitado;

  @override
  Widget build(BuildContext context) {
    final membros = (sala['membros'] as List?) ?? const [];
    final convidados = ((sala['convidados'] as List?) ?? const []).cast<Map>();
    final posicoes = sala['posicoes'] == true;
    final lider = membros.any(
      (m) => m is Map && m['eu'] == true && m['lider'] == true,
    );
    final cabe = membros.length < ((sala['max'] as num?) ?? 5);
    final fila = sala['fila'];
    final modo =
        ((con.estado['filas'] as List?) ?? const [])
            .cast<Map>()
            .where((f) => f['id'] == fila)
            .map((f) => '${f['nome']}')
            .firstOrNull ??
        '${con.estado['fila_nome'] ?? ''}';
    final topo = <Widget>[
      Row(
        children: [
          Text('NA SALA', style: fonteTitulo(14)),
          const Spacer(),
          // deitado, convidar vira um ícone aqui: o botão largo embaixo desalinhava com as ações do lado
          if (deitado && sala['pode_convidar'] == true && cabe) ...[
            Tooltip(
              message: 'Convidar amigos',
              child: Semantics(
                button: true,
                label: 'Convidar amigos',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _abrirSala(context, con, passo: _Passo.convidar),
                  child: Container(
                    width: 44,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: Raio.r1,
                      color: Cor.ouro.withValues(alpha: 0.1),
                      border: Border.all(color: Cor.ouro),
                    ),
                    child: Icon(
                      Icons.person_add_alt_1_outlined,
                      size: 20,
                      color: Cor.ouroClaro,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
      if (modo.isNotEmpty) ...[
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: AnimatedSwitcher(
                duration: _dur(context, 220),
                layoutBuilder: (atual, antigos) => Stack(
                  alignment: Alignment.centerLeft,
                  children: [...antigos, ?atual],
                ),
                child: Text(
                  modo,
                  key: ValueKey(modo),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Cor.teal, fontSize: 14),
                ),
              ),
            ),
            // so o lider troca o modo (igual no client)
            if (lider)
              TextButton.icon(
                onPressed: () => _abrirSala(context, con, trocar: true),
                style: TextButton.styleFrom(
                  foregroundColor: Cor.ouro,
                  minimumSize: const Size(44, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                icon: const Icon(Icons.swap_horiz, size: 18),
                label: const Text(
                  'Trocar',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ),
      ],
    ];
    final pessoas = <Widget>[
      for (final (i, m) in membros.indexed)
        _Entrada(
          // key no _Entrada: senão quem está embaixo repete a entrada quando alguém sai
          key: ValueKey('m-${m['nome']}'),
          chave: 'm-${m['nome']}',
          atraso: i * 40,
          child: _Membro(
            m: m as Map,
            posicoes: posicoes,
            aoTocar: () => _abrirPosicao(context, con),
          ),
        ),
      for (final c in convidados)
        _Entrada(
          key: ValueKey('c-${c['puuid']}'),
          chave: 'c-${c['puuid']}',
          child: _Convidado(c: c),
        ),
    ];
    final convidar = sala['pode_convidar'] == true && cabe
        ? SizedBox(
            width: double.infinity,
            child: _Acao(
              icone: Icons.person_add_alt_1_outlined,
              texto: 'Convidar amigos',
              aoTocar: () => _abrirSala(context, con, passo: _Passo.convidar),
            ),
          )
        : null;
    if (emPe) {
      final max = ((sala['max'] as num?) ?? 5).toInt();
      final vagas = sala['pode_convidar'] == true
          ? math.max(0, max - membros.length - convidados.length)
          : 0;
      // lanes uma embaixo da outra: a faixa cresce pro lugar com mais posições
      final linhas = posicoes
          ? membros.fold<int>(
              1,
              (n, m) => math.max(n, ((m as Map)['pos'] as List?)?.length ?? 0),
            )
          : 1;
      void convidarAmigos() => _abrirSala(context, con, passo: _Passo.convidar);
      final lugares = <Widget>[
        for (final (i, m) in membros.indexed)
          _Entrada(
            key: ValueKey('m-${m['nome']}'),
            chave: 'm-${m['nome']}',
            atraso: i * 40,
            child: _Lugar.membro(
              m as Map,
              posicoes: posicoes,
              aoTocar: () => _abrirPosicao(context, con),
            ),
          ),
        for (final c in convidados)
          _Entrada(
            key: ValueKey('c-${c['puuid']}'),
            chave: 'c-${c['puuid']}',
            child: _Lugar.convidado(c),
          ),
        for (var i = 0; i < vagas; i++)
          _Entrada(
            key: ValueKey('v-$i'),
            chave: 'v-$i',
            child: _Lugar.vaga(convidarAmigos),
          ),
      ];
      return Cartao(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // uma linha só: título, modo e o Trocar do líder
            SizedBox(
              height: 32,
              child: Row(
                children: [
                  Text('NA SALA', style: fonteTitulo(13)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: _dur(context, 220),
                      layoutBuilder: (atual, antigos) => Stack(
                        alignment: Alignment.centerLeft,
                        children: [...antigos, ?atual],
                      ),
                      child: Text(
                        modo,
                        key: ValueKey(modo),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Cor.teal, fontSize: 13),
                      ),
                    ),
                  ),
                  if (lider)
                    TextButton.icon(
                      onPressed: () => _abrirSala(context, con, trocar: true),
                      style: TextButton.styleFrom(
                        foregroundColor: Cor.ouro,
                        minimumSize: const Size(44, 32),
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: const Icon(Icons.swap_horiz, size: 17),
                      label: const Text(
                        'Trocar',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            // os lugares lado a lado como no client: até 5 a faixa fica da altura do lugar mais alto
            // (nome grande quebra em duas linhas); sala grande (personalizada) rola pro lado
            if (lugares.length <= 5)
              AnimatedSize(
                duration: _dur(context, 220),
                curve: curvaSaida,
                alignment: Alignment.topCenter,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final l in lugares) Expanded(child: l),
                    for (var i = lugares.length; i < 5; i++)
                      const Expanded(child: SizedBox()),
                  ],
                ),
              )
            else
              SizedBox(
                height: _Lugar.altura(linhas + 1),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.zero,
                  children: [
                    for (final l in lugares) SizedBox(width: 68, child: l),
                  ],
                ),
              ),
          ],
        ),
      );
    }
    if (deitado) {
      return Cartao(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...topo,
            const SizedBox(height: 4),
            // celular deitado é baixo: sem altura pra todos, as linhas ficam compactas pra ninguém
            // cortar embaixo (a lista ainda rola se nem assim couber)
            Expanded(
              child: LayoutBuilder(
                builder: (context, c) {
                  final n = membros.length + convidados.length;
                  final compacto = n * _Membro.altura > c.maxHeight;
                  return ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      for (final (i, m) in membros.indexed)
                        _Entrada(
                          key: ValueKey('m-${m['nome']}'),
                          chave: 'm-${m['nome']}',
                          atraso: i * 40,
                          child: _Membro(
                            m: m as Map,
                            posicoes: posicoes,
                            compacto: compacto,
                            aoTocar: () => _abrirPosicao(context, con),
                          ),
                        ),
                      for (final c in convidados)
                        _Entrada(
                          key: ValueKey('c-${c['puuid']}'),
                          chave: 'c-${c['puuid']}',
                          child: _Convidado(c: c, compacto: compacto),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      );
    }
    return Cartao(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...topo,
          const SizedBox(height: 8),
          ...pessoas,
          if (convidar != null) ...[const SizedBox(height: 10), convidar],
          const SizedBox(height: 14),
          // so o lider da sala inicia a fila (igual no client)
          if (lider) ...[
            Botao(
              texto: 'Buscar partida',
              principal: true,
              grande: true,
              carregando: con.esperando('buscar'),
              aoTocar: () => con.enviar('buscar'),
            ),
            const SizedBox(height: 10),
          ],
          Center(
            child: TextButton.icon(
              onPressed: con.esperando('sair_sala')
                  ? null
                  : () => con.enviar('sair_sala'),
              style: TextButton.styleFrom(
                foregroundColor: Cor.apagado,
                disabledForegroundColor: Cor.apagado,
                minimumSize: const Size(44, 44),
              ),
              icon: AnimatedSwitcher(
                duration: _dur(context, 200),
                child: con.esperando('sair_sala')
                    ? SizedBox(
                        key: ValueKey('girando'),
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Cor.apagado,
                        ),
                      )
                    : const Icon(
                        Icons.logout,
                        key: ValueKey('icone'),
                        size: 17,
                      ),
              ),
              label: const Text(
                'SAIR DA SALA',
                style: TextStyle(letterSpacing: 1.2, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Deitado, na sala ou na fila com sala: à esquerda quem está (ou a fila), à direita o chat com as
/// ações embaixo. Tudo cabe na altura, sem rolar a tela.
class _SalaDeitada extends StatelessWidget {
  const _SalaDeitada({required this.con});
  final Conexao con;

  @override
  Widget build(BuildContext context) {
    final sala = con.estado['sala'] as Map;
    final naFila = con.fase == 'Matchmaking';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 5,
          child: naFila
              ? _FilaDeitada(con: con)
              : _CartaoSala(con: con, sala: sala, deitado: true),
        ),
        const SizedBox(width: 14),
        Expanded(
          flex: 6,
          child: Column(
            children: [
              Expanded(
                child: _ChatSala(con: con, sala: sala, encher: true),
              ),
              if (!naFila) ...[
                const SizedBox(height: 10),
                _AcoesSala(con: con, sala: sala),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Buscar partida e sair numa linha só, perto do polegar.
class _AcoesSala extends StatelessWidget {
  const _AcoesSala({required this.con, required this.sala});
  final Conexao con;
  final Map sala;

  @override
  Widget build(BuildContext context) {
    final membros = (sala['membros'] as List?) ?? const [];
    final lider = membros.any(
      (m) => m is Map && m['eu'] == true && m['lider'] == true,
    );
    final saindo = con.esperando('sair_sala');
    return Row(
      children: [
        // so o lider da sala inicia a fila (igual no client)
        if (lider) ...[
          Expanded(
            child: Botao(
              texto: 'Buscar partida',
              principal: true,
              carregando: con.esperando('buscar'),
              aoTocar: () => con.enviar('buscar'),
            ),
          ),
          const SizedBox(width: 8),
        ] else ...[
          Expanded(
            child: Text(
              'O líder da sala inicia a fila.',
              style: TextStyle(color: Cor.apagado, fontSize: 13.5),
            ),
          ),
          const SizedBox(width: 8),
        ],
        _BotaoSairSala(con: con, saindo: saindo),
      ],
    );
  }
}

class _BotaoSairSala extends StatelessWidget {
  const _BotaoSairSala({required this.con, required this.saindo});
  final Conexao con;
  final bool saindo;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Sair da sala',
    child: Tooltip(
      message: 'Sair da sala',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: saindo ? null : () => con.enviar('sair_sala'),
        child: Container(
          width: 50,
          height: 50,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: Raio.r1,
            color: Cor.painel2,
            border: Border.all(color: Cor.linha2),
          ),
          child: AnimatedSwitcher(
            duration: _dur(context, 200),
            child: saindo
                ? SizedBox(
                    key: ValueKey('girando'),
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Cor.apagado,
                    ),
                  )
                : Icon(
                    Icons.logout,
                    key: ValueKey('icone'),
                    size: 19,
                    color: Cor.apagado,
                  ),
          ),
        ),
      ),
    ),
  );
}

/// Um lugar da sala em pé, como no client: avatar redondo com o nome embaixo. Pode ser alguém na sala,
/// um convite esperando resposta ou a vaga vazia (tocar abre os convites).
class _Lugar extends StatelessWidget {
  const _Lugar._({
    required this.avatar,
    required this.nome,
    required this.linhas,
    this.corNome,
    this.corLinha2,
    this.borda,
    this.fundo,
    this.lider = false,
    this.aoTocar,
    this.rotulo = 'Convidar amigos',
  });

  /// [aoTocar] no seu lugar, em sala com posição: abre a escolha da posição.
  factory _Lugar.membro(
    Map m, {
    required bool posicoes,
    VoidCallback? aoTocar,
  }) {
    final eu = m['eu'] == true;
    final pos = ((m['pos'] as List?) ?? const [])
        .map((p) => _posicoes[p] ?? '')
        .where((p) => p.isNotEmpty)
        .toList();
    final escolher = eu && posicoes && aoTocar != null;
    return _Lugar._(
      avatar: ClipOval(
        child: Image.network(
          _icone((m['icone'] as num?)?.toInt() ?? 0),
          fit: BoxFit.cover,
          webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
          errorBuilder: (_, _, _) => ColoredBox(color: Cor.painel2),
        ),
      ),
      nome: '${m['nome']}',
      linhas: !posicoes
          ? const []
          // lugar estreito: uma palavra por linha pra não cortar
          : (escolher && pos.isEmpty ? const ['Escolher', 'posição'] : pos),
      corNome: eu ? Cor.ouroClaro : Cor.texto,
      corLinha2: escolher ? Cor.ouro : Cor.apagado,
      borda: eu ? Cor.ouro : Cor.linha2,
      lider: m['lider'] == true,
      aoTocar: escolher ? aoTocar : null,
      rotulo: 'Escolher sua posição',
    );
  }

  factory _Lugar.convidado(Map c) => _Lugar._(
    avatar: Center(child: Losango(cor: Cor.ouro, tamanho: 8, pulsar: true)),
    nome: '${c['nome']}',
    linhas: const ['Convidado'],
    corNome: Cor.apagado,
    corLinha2: Cor.ouro,
  );

  factory _Lugar.vaga(VoidCallback aoTocar) => _Lugar._(
    avatar: Icon(Icons.person_add_alt_1_outlined, size: 19, color: Cor.ouro),
    nome: 'Convidar',
    linhas: const [],
    corNome: Cor.ouro,
    borda: Cor.ouroEscuro,
    fundo: Cor.ouro.withValues(alpha: 0.06),
    aoTocar: aoTocar,
  );

  /// Altura da faixa rolando: avatar, nome e as linhas de baixo (uma posição por linha).
  static double altura(int linhas) => 68.0 + 14.0 * math.max(1, linhas);
  static const _avatar = 46.0;

  final Widget avatar;
  final String nome;
  final List<String> linhas;
  // null = a cor de sempre do tema em uso (texto, apagado, linha2)
  final Color? corNome;
  final Color? corLinha2;
  final Color? borda;
  final Color? fundo;
  final bool lider;
  final VoidCallback? aoTocar;
  final String rotulo;

  @override
  Widget build(BuildContext context) {
    final corpo = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: _avatar + 8,
            height: _avatar,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Container(
                  width: _avatar,
                  height: _avatar,
                  padding: const EdgeInsets.all(2),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: fundo,
                    border: Border.all(color: borda ?? Cor.linha2, width: 1.5),
                  ),
                  child: avatar,
                ),
                // coroa do líder da sala no canto, como no client
                if (lider)
                  Positioned(
                    right: 0,
                    top: -3,
                    child: Tooltip(
                      message: 'Líder da sala',
                      child: Container(
                        width: 20,
                        height: 20,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Cor.painel,
                          border: Border.all(color: Cor.ouro),
                        ),
                        child: Icon(
                          Icons.workspace_premium_outlined,
                          size: 12,
                          color: Cor.ouro,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 5),
          // nome grande quebra em duas linhas em vez de cortar
          Text(
            nome,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: corNome ?? Cor.texto,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              height: 1.15,
            ),
          ),
          for (final l in linhas)
            Text(
              l,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: corLinha2 ?? Cor.apagado,
                fontSize: 10.5,
                height: 1.3,
              ),
            ),
        ],
      ),
    );
    final toque = aoTocar;
    if (toque == null) return corpo;
    return Semantics(
      button: true,
      label: rotulo,
      child: InkWell(onTap: toque, borderRadius: Raio.r1, child: corpo),
    );
  }
}

/// A fila deitada, ao lado do chat: título, modo, tempo e sair, sem passar da altura.
class _FilaDeitada extends StatelessWidget {
  const _FilaDeitada({required this.con});
  final Conexao con;

  @override
  Widget build(BuildContext context) {
    final inicio = con.estado['fila_inicio'];
    final fila = '${con.estado['fila_nome'] ?? ''}';
    return Cartao(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('PROCURANDO PARTIDA', style: fonteTitulo(14)),
          if (fila.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              fila,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Cor.teal, fontSize: 14),
            ),
          ],
          Expanded(
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _Radar(),
                    if (inicio is int) ...[
                      const SizedBox(width: 18),
                      Relogio(
                        builder: (_) => Text(
                          _mmss(
                            con.agora.millisecondsSinceEpoch ~/ 1000 -
                                inicio ~/ 1000,
                          ),
                          style: fonteTitulo(40, cor: Cor.ouroClaro).copyWith(
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          Botao(
            texto: 'Sair da fila',
            carregando: con.esperando('sair_fila'),
            aoTocar: () => con.enviar('sair_fila'),
          ),
        ],
      ),
    );
  }
}

/// Botão secundário pequeno (convidar, trocar modo).
class _Acao extends StatelessWidget {
  const _Acao({
    required this.icone,
    required this.texto,
    required this.aoTocar,
  });
  final IconData icone;
  final String texto;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: aoTocar,
    style: OutlinedButton.styleFrom(
      foregroundColor: Cor.ouroClaro,
      minimumSize: const Size(44, 46),
      side: BorderSide(color: Cor.ouroEscuro),
      shape: const RoundedRectangleBorder(borderRadius: Raio.r1),
    ),
    icon: Icon(icone, size: 18, color: Cor.ouro),
    label: Text(
      texto.toUpperCase(),
      style: const TextStyle(
        letterSpacing: 1.1,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

/// Convite mandado e ainda sem resposta.
class _Convidado extends StatelessWidget {
  const _Convidado({required this.c, this.compacto = false});
  final Map c;
  final bool compacto;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(vertical: compacto ? 2 : 7),
    child: Row(
      children: [
        Container(
          width: compacto ? 32 : 42,
          height: compacto ? 32 : 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Cor.linha2, width: 1.5),
          ),
          child: Losango(cor: Cor.ouro, tamanho: 8, pulsar: true),
        ),
        SizedBox(width: compacto ? 10 : 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${c['nome']}',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: compacto ? 14 : 15.5,
                  color: Cor.apagado,
                ),
              ),
              SizedBox(height: compacto ? 1 : 3),
              Text(
                'Convidado, esperando resposta',
                style: TextStyle(
                  color: Cor.ouro,
                  fontSize: compacto ? 11.5 : 12.5,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Membro extends StatelessWidget {
  const _Membro({
    required this.m,
    required this.posicoes,
    this.compacto = false,
    this.aoTocar,
  });
  final Map m;
  final bool posicoes;

  /// No seu nome, em sala com posição: abre a escolha da posição.
  final VoidCallback? aoTocar;

  /// Avatar menor e letra menor (deitado, quando a sala não cabe na altura).
  final bool compacto;

  /// Altura da linha normal (42 do avatar + 7 em cima e embaixo, com folga).
  static const altura = 58.0;

  @override
  Widget build(BuildContext context) {
    final eu = m['eu'] == true;
    final pos = ((m['pos'] as List?) ?? const [])
        .map((p) => _posicoes[p] ?? '')
        .where((p) => p.isNotEmpty);
    final escolher = eu && posicoes && aoTocar != null;
    final linha = Padding(
      padding: EdgeInsets.symmetric(vertical: compacto ? 2 : 7),
      child: Row(
        children: [
          Container(
            width: compacto ? 32 : 42,
            height: compacto ? 32 : 42,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: eu ? Cor.ouro : Cor.linha2, width: 1.5),
            ),
            child: ClipOval(
              child: Image.network(
                _icone((m['icone'] as num?)?.toInt() ?? 0),
                fit: BoxFit.cover,
                webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                errorBuilder: (_, _, _) => ColoredBox(color: Cor.painel2),
              ),
            ),
          ),
          SizedBox(width: compacto ? 10 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '${m['nome']}',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: compacto ? 14 : 15.5,
                                color: eu ? Cor.ouroClaro : Cor.texto,
                              ),
                            ),
                            if ('${m['tag'] ?? ''}'.isNotEmpty)
                              TextSpan(
                                text: ' #${m['tag']}',
                                style: TextStyle(
                                  color: Cor.apagado,
                                  fontSize: compacto ? 12 : 13,
                                ),
                              ),
                          ],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (m['lider'] == true) ...[
                      const SizedBox(width: 6),
                      Tooltip(
                        message: 'Líder da sala',
                        child: Icon(
                          Icons.workspace_premium_outlined,
                          size: 16,
                          color: Cor.ouro,
                        ),
                      ),
                    ],
                  ],
                ),
                if (posicoes && (pos.isNotEmpty || escolher))
                  Padding(
                    padding: EdgeInsets.only(top: compacto ? 1 : 3),
                    child: Text(
                      pos.isEmpty ? 'Escolher posição' : pos.join('  ·  '),
                      style: TextStyle(
                        color: escolher ? Cor.ouro : Cor.apagado,
                        fontSize: compacto ? 11.5 : 12.5,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (escolher)
            Padding(
              padding: EdgeInsets.only(left: 6),
              child: Icon(Icons.edit_outlined, size: 16, color: Cor.ouro),
            ),
        ],
      ),
    );
    if (!escolher) return linha;
    return Semantics(
      button: true,
      label: 'Escolher sua posição',
      child: InkWell(onTap: aoTocar, borderRadius: Raio.r1, child: linha),
    );
  }
}

/// Chat da sala: últimas mensagens e campo pra mandar.
class _ChatSala extends StatefulWidget {
  const _ChatSala({
    super.key,
    required this.con,
    required this.sala,
    this.titulo = 'CHAT DA SALA',
    this.encher = false,
  });
  final Conexao con;
  final Map sala;
  final String titulo;

  /// Ocupa a altura que tiver (deitado): mensagens no meio, campo sempre embaixo.
  final bool encher;

  @override
  State<_ChatSala> createState() => _ChatSalaState();
}

class _ChatSalaState extends State<_ChatSala> {
  final _campo = TextEditingController();

  @override
  void dispose() {
    _campo.dispose();
    super.dispose();
  }

  void _mandar() {
    final t = _campo.text.trim();
    if (t.isEmpty) return;
    widget.con.enviar('chat', {
      'texto': t.length > 200 ? t.substring(0, 200) : t,
    });
    _campo.clear();
  }

  @override
  Widget build(BuildContext context) {
    final msgs = ((widget.sala['chat'] as List?) ?? const []).cast<Map>();
    final ok = widget.sala['chat_ok'] == true;
    final ids = [for (final m in msgs) '${m['id']}'];
    Widget caixa(Widget lista) => widget.encher
        ? Expanded(child: lista)
        : ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 300),
            child: lista,
          );
    return Cartao(
      padding: widget.encher
          ? const EdgeInsets.fromLTRB(18, 16, 18, 14)
          : const EdgeInsets.fromLTRB(22, 24, 22, 22),
      child: Column(
        // na folha do chat, só o tamanho do conteúdo; deitado, a altura toda
        mainAxisSize: widget.encher ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.titulo, style: fonteTitulo(14)),
          const SizedBox(height: 12),
          if (!ok)
            Text(
              'O chat ainda não abriu.',
              style: TextStyle(color: Cor.apagado, fontSize: 14),
            )
          else if (msgs.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Nenhuma mensagem ainda.',
                style: TextStyle(color: Cor.apagado, fontSize: 14),
              ),
            )
          else
            caixa(
              ListView.builder(
                reverse: true, // a mais nova fica embaixo e a lista acompanha
                shrinkWrap: !widget.encher,
                itemCount: msgs.length,
                findChildIndexCallback: (k) {
                  final i = ids.indexOf((k as ValueKey<String>).value);
                  return i < 0 ? null : msgs.length - 1 - i;
                },
                itemBuilder: (_, i) {
                  final m = msgs[msgs.length - 1 - i];
                  return _Entrada(
                    key: ValueKey('${m['id']}'),
                    chave: '${m['id']}',
                    child: _Mensagem2(m: m),
                  );
                },
              ),
            ),
          // sem mensagens, o campo continua no pé do cartão
          if (widget.encher && (!ok || msgs.isEmpty)) const Spacer(),
          if (ok) ...[
            const SizedBox(height: 12),
            _CampoMensagem(campo: _campo, aoMandar: _mandar),
          ],
        ],
      ),
    );
  }
}

class _Mensagem2 extends StatelessWidget {
  const _Mensagem2({required this.m});
  final Map m;

  @override
  Widget build(BuildContext context) {
    final hora = DateTime.fromMillisecondsSinceEpoch(
      (m['hora'] as num?)?.toInt() ?? 0,
    );
    final hh =
        '${hora.hour.toString().padLeft(2, '0')}:${hora.minute.toString().padLeft(2, '0')}';
    if (m['tipo'] == 'aviso') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Text(
          '${m['texto']}  ·  $hh',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Cor.apagado,
            fontSize: 12.5,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }
    final eu = m['eu'] == true;
    return Align(
      alignment: eu ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 300),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.fromLTRB(11, 7, 11, 8),
        decoration: BoxDecoration(
          borderRadius: Raio.r2,
          color: eu ? Cor.marcado : Cor.painel2,
          border: Border.all(color: eu ? Cor.ouroEscuro : Cor.linha2),
        ),
        child: Column(
          crossAxisAlignment: eu
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Text(
              eu ? 'Você · $hh' : '${m['de'] ?? ''} · $hh',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: eu ? Cor.ouro : Cor.teal,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${m['texto']}',
              style: const TextStyle(fontSize: 15, height: 1.3),
            ),
          ],
        ),
      ),
    );
  }
}

/// Entra deslizando de leve na primeira vez que aparece.
class _Entrada extends StatelessWidget {
  const _Entrada({
    super.key,
    required this.chave,
    required this.child,
    this.atraso = 0,
  });
  final String chave;
  final Widget child;
  final int atraso;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return TweenAnimationBuilder<double>(
      key: ValueKey('entrada-$chave'),
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 320 + atraso),
      curve: Interval(atraso / (320 + atraso), 1, curve: curvaSaida),
      builder: (_, t, c) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, (1 - t) * 8), child: c),
      ),
      child: child,
    );
  }
}

/// Em pé na sala: tela fixa, sem rolar. Em cima uma faixa compacta com quem está (e as vagas de convidar),
/// o chat ocupa quase tudo e as ações ficam numa linha no pé, perto do polegar.
class _SalaEmPe extends StatelessWidget {
  const _SalaEmPe({required this.con});
  final Conexao con;

  @override
  Widget build(BuildContext context) {
    final sala = con.estado['sala'] as Map;
    // na fila: a fila fica presa no topo (inclusive com o teclado aberto) e o chat pega o resto da altura
    final naFila = con.fase == 'Matchmaking';
    return LayoutBuilder(
      builder: (context, c) {
        // teclado aberto (escrevendo no chat): sala e ações saem e o chat fica com a tela. Lido do View porque
        // o Scaffold tira o teclado do MediaQuery do corpo; o LayoutBuilder reconstrói quando a altura muda.
        // O chat fica sempre no mesmo lugar da árvore (com key): se ele fosse recriado, o campo perdia o
        // foco e o teclado abria e fechava sem parar
        final teclado = View.of(context).viewInsets.bottom > 0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (naFila) ...[
              _Entrada(
                key: const ValueKey('fila-em-pe'),
                chave: 'fila-em-pe',
                child: _Fila(
                  con: con,
                  fila: (con.estado['fila_nome'] as String?) ?? '',
                  compacta: true,
                ),
              ),
              const SizedBox(key: ValueKey('vao-fila'), height: 10),
            ] else if (!teclado) ...[
              _Entrada(
                key: const ValueKey('sala-em-pe'),
                chave: 'sala-em-pe',
                child: _CartaoSala(con: con, sala: sala, emPe: true),
              ),
              const SizedBox(key: ValueKey('vao-sala'), height: 10),
            ],
            Expanded(
              key: const ValueKey('chat-sala'),
              child: _ChatSala(con: con, sala: sala, encher: true),
            ),
            if (!teclado && !naFila)
              _Entrada(
                key: const ValueKey('acoes-em-pe'),
                chave: 'acoes-em-pe',
                child: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: _AcoesSala(con: con, sala: sala),
                ),
              ),
          ],
        );
      },
    );
  }
}
