part of 'main.dart';

/// Partida em andamento: o PC lê a API que o próprio jogo abre pra apps como o Blitz (só leitura, só no PC)
/// e manda em `jogo` o início (hora do servidor), tropas, placar, seu KDA e os objetivos. O relógio anda aqui.

/// Em que segundo as tropas saem, por mapa (11 = Summoner's Rift; 0:30 desde a 26.1, antes 1:05). Outro mapa
/// só diz que ainda não saíram. O `tropas` do PC (evento do jogo) sempre ganha desta conta.
const _tropasEm = {11: 30};

const _dragoes = {
  'fire': 'Infernal',
  'earth': 'da Montanha',
  'water': 'do Oceano',
  'air': 'das Nuvens',
  'hextech': 'Hextec',
  'chemtech': 'Quimtec',
  'elder': 'Ancião',
};

String _nomeEvento(Map ev) {
  final roubado = ev['roubado'] == true ? ' (roubado)' : '';
  return switch (ev['tipo']) {
    'primeiro_abate' => 'Primeiro abate',
    'dragao' => 'Dragão ${_dragoes[ev['dragao']] ?? ''}'.trim() + roubado,
    'arauto' => 'Arauto$roubado',
    'barao' => 'Barão$roubado',
    'vastilarvas' => 'Vastilarvas',
    'atakhan' => 'Atakhan$roubado',
    'torre' => 'Torre',
    'inibidor' => 'Inibidor',
    'ace' => 'Time inteiro abatido',
    _ => '${ev['tipo']}',
  };
}

class _EmPartida extends StatelessWidget {
  const _EmPartida({required this.con});
  final Conexao con;

  @override
  Widget build(BuildContext context) {
    final j = con.estado['jogo'];
    final carregando =
        j is! Map || j['carregando'] == true || j['inicio'] is! int;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 380),
      switchInCurve: curvaSaida,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (filho, a) => FadeTransition(
        opacity: a,
        child: ScaleTransition(
          scale: Tween(begin: 0.97, end: 1.0).animate(a),
          child: filho,
        ),
      ),
      child: carregando
          ? const _Mensagem(
              key: ValueKey('carregando'),
              icone: _Pulso(),
              titulo: 'Tela de carregamento',
              texto: 'A partida começa assim que todo mundo carregar.',
            )
          : _Placar(key: const ValueKey('jogo'), con: con, j: j),
    );
  }
}

class _Placar extends StatelessWidget {
  const _Placar({super.key, required this.con, required this.j});
  final Conexao con;
  final Map j;

  int get _segundos =>
      (con.agora.millisecondsSinceEpoch - (j['inicio'] as int)) ~/ 1000;

  String _tropas(int s) {
    if (j['tropas'] is int) return 'Tropas em campo';
    final em = _tropasEm[j['mapa']];
    if (em != null && s < em) return 'Tropas saem em ${_mmss(em - s)}';
    return 'Tropas ainda não saíram';
  }

  @override
  Widget build(BuildContext context) {
    final eu = j['eu'] is Map ? j['eu'] as Map : null;
    final placar = j['placar'] is List ? j['placar'] as List : null;
    final eventos = [
      for (final ev in (j['eventos'] is List ? j['eventos'] as List : const []))
        if (ev is Map) ev,
    ].reversed.take(_deitado(context) ? 3 : 6).toList(); // deitado falta altura

    final topo = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (eu?['id'] is int)
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              borderRadius: Raio.r1,
              border: Border.all(color: Cor.ouro.withValues(alpha: 0.6)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.network(
              _iconeCampeao(eu!['id'] as int),
              fit: BoxFit.cover,
              webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
              errorBuilder: (_, _, _) => ColoredBox(color: Cor.painel2),
            ),
          )
        else
          Icone(Icons.sports_esports_outlined, cor: Cor.teal),
        const SizedBox(height: 14),
        Text(
          (eu?['campeao'] is String && (eu!['campeao'] as String).isNotEmpty
                  ? 'Em partida de ${eu['campeao']}'
                  : 'Em partida')
              .toUpperCase(),
          textAlign: TextAlign.center,
          style: fonteTitulo(16),
        ),
        const SizedBox(height: 6),
        Relogio(
          builder: (_) {
            final s = _segundos;
            final volta = eu?['volta'];
            final falta = volta is int
                ? (volta - con.agora.millisecondsSinceEpoch) ~/ 1000
                : 0;
            return Column(
              children: [
                Text(
                  _mmss(s),
                  style: fonteTitulo(44, cor: Cor.ouroClaro).copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 2),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Text(
                    falta > 0 ? 'Você volta em ${_mmss(falta)}' : _tropas(s),
                    key: ValueKey(falta > 0 ? 'morto' : _tropas(s)),
                    style: TextStyle(
                      color: falta > 0 ? Cor.vermelho : Cor.apagado,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );

    final numeros = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (placar != null && placar.length == 2)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Lado(texto: 'SEU TIME', valor: '${placar[0]}', cor: Cor.teal),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Text('x', style: fonteTitulo(16, cor: Cor.apagado)),
              ),
              _Lado(texto: 'INIMIGO', valor: '${placar[1]}', cor: Cor.vermelho),
            ],
          ),
        if (eu != null) ...[
          const SizedBox(height: 12),
          Text(
            '${eu['k']} / ${eu['d']} / ${eu['a']}   ·   ${eu['cs']} CS',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Cor.texto,
              fontSize: 16,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
        if (eventos.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(height: 1, color: Cor.linha),
          const SizedBox(height: 10),
          for (final ev in eventos)
            _Entrada(
              key: ValueKey('ev-${ev['t']}-${ev['tipo']}'),
              chave: 'ev-${ev['t']}-${ev['tipo']}',
              child: _LinhaEvento(ev: ev),
            ),
        ],
      ],
    );

    if (_deitado(context)) {
      return Cartao(
        child: Row(
          children: [
            Expanded(child: topo),
            Container(
              width: 1,
              height: 160,
              margin: const EdgeInsets.symmetric(horizontal: 24),
              color: Cor.linha,
            ),
            Expanded(child: numeros),
          ],
        ),
      );
    }
    return Cartao(
      child: Column(
        children: [
          const SizedBox(height: 8),
          topo,
          const SizedBox(height: 20),
          numeros,
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _Lado extends StatelessWidget {
  const _Lado({required this.texto, required this.valor, required this.cor});
  final String texto;
  final String valor;
  final Color cor;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        transitionBuilder: (f, a) => FadeTransition(
          opacity: a,
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0, 0.3),
              end: Offset.zero,
            ).animate(a),
            child: f,
          ),
        ),
        child: Text(
          valor,
          key: ValueKey(valor),
          style: fonteTitulo(
            30,
            cor: cor,
          ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
        ),
      ),
      Text(
        texto,
        style: TextStyle(color: Cor.apagado, fontSize: 12, letterSpacing: 1.2),
      ),
    ],
  );
}

class _LinhaEvento extends StatelessWidget {
  const _LinhaEvento({required this.ev});
  final Map ev;

  @override
  Widget build(BuildContext context) {
    final lado = ev['lado'];
    final cor = lado == 'nos'
        ? Cor.teal
        : lado == 'eles'
        ? Cor.vermelho
        : Cor.apagado;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: Text(
              _mmss((ev['t'] as num?)?.toInt() ?? 0),
              style: TextStyle(
                color: Cor.apagado,
                fontSize: 14,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          Losango(cor: cor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _nomeEvento(ev),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Cor.texto, fontSize: 15),
            ),
          ),
          if (lado is String)
            Text(
              lado == 'nos' ? 'seu time' : 'inimigo',
              style: TextStyle(color: cor, fontSize: 13),
            ),
        ],
      ),
    );
  }
}
// ---------------- tela de carregamento ----------------

const _fasesJogo = {'GameStart', 'InProgress', 'Reconnect'};

/// O jogo ainda carregando e o PC já mandou os dois times.
bool _emCarregamento(Conexao con) {
  if (!_fasesJogo.contains(con.fase)) return false;
  final j = con.estado['jogo'];
  final c = con.estado['carregamento'];
  if (j is Map && j['carregando'] != true) return false;
  if (c is! Map) return false;
  // Arena: uma lista só com os 18 (sem dois times)
  if (c['arena'] == true) {
    return c['jogadores'] is List && (c['jogadores'] as List).isNotEmpty;
  }
  return c['times'] is List && (c['times'] as List).isNotEmpty;
}

const _elos = {
  'IRON': 'Ferro',
  'BRONZE': 'Bronze',
  'SILVER': 'Prata',
  'GOLD': 'Ouro',
  'PLATINUM': 'Platina',
  'EMERALD': 'Esmeralda',
  'DIAMOND': 'Diamante',
  'MASTER': 'Mestre',
  'GRANDMASTER': 'Grão-Mestre',
  'CHALLENGER': 'Desafiante',
};

String _textoElo(Object? elo) {
  if (elo is! Map) return '';
  final t = '${elo['tier'] ?? ''}';
  final nome = _elos[t] ?? '';
  if (nome.isEmpty) return '';
  // do Mestre pra cima não tem divisão
  if (const {'MASTER', 'GRANDMASTER', 'CHALLENGER'}.contains(t)) return nome;
  return '$nome ${elo['div'] ?? ''}'.trim();
}

List<Map> _time(Object? t) => [
  for (final x in (t is List ? t : const []))
    if (x is Map) x,
];

/// Imagem que aparece em fade quando chega (a arte vem do CommunityDragon e demora um pouco).
class _ArteFade extends StatelessWidget {
  const _ArteFade({required this.url, this.alinhamento = Alignment.center});
  final String url;
  final Alignment alinhamento;

  @override
  Widget build(BuildContext context) => Image.network(
    url,
    fit: BoxFit.cover,
    alignment: alinhamento,
    webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
    frameBuilder: (_, filho, quadro, sincrono) => sincrono
        ? filho
        : AnimatedOpacity(
            opacity: quadro == null ? 0 : 1,
            duration: _dur(context, 420),
            curve: curvaSaida,
            child: filho,
          ),
    errorBuilder: (_, _, _) => ColoredBox(color: Cor.painel2),
  );
}

class _Feiticos2 extends StatelessWidget {
  const _Feiticos2({required this.j, this.tamanho = 16, this.vertical = false});
  final Map j;
  final double tamanho;
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final f = [
      for (final x
          in (j['feiticos'] is List ? j['feiticos'] as List : const []))
        '${x ?? ''}',
    ].where((x) => x.isNotEmpty).toList();
    if (f.isEmpty) return const SizedBox.shrink();
    final itens = [
      for (final (i, x) in f.indexed) ...[
        if (i > 0) const SizedBox(width: 3, height: 3),
        Container(
          width: tamanho,
          height: tamanho,
          decoration: BoxDecoration(
            borderRadius: Raio.r1,
            border: Border.all(color: Cor.ouroEscuro),
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.network(
            _arte(x, 0),
            fit: BoxFit.cover,
            webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
            errorBuilder: (_, _, _) => ColoredBox(color: Cor.painel2),
          ),
        ),
      ],
    ];
    return vertical
        ? Column(mainAxisSize: MainAxisSize.min, children: itens)
        : Row(mainAxisSize: MainAxisSize.min, children: itens);
  }
}

class _Carregamento extends StatelessWidget {
  const _Carregamento({required this.con});
  final Conexao con;

  @override
  Widget build(BuildContext context) {
    final c = con.estado['carregamento'] as Map;
    // Arena: 18 jogadores numa grade só, sem dois times
    if (c['arena'] == true) return _CarregamentoArena(con: con);
    final times = c['times'] as List;
    final nos = _time(times.isNotEmpty ? times[0] : null);
    final eles = _time(times.length > 1 ? times[1] : null);
    final fila = '${c['fila'] ?? ''}';
    final topo = Row(
      children: [
        Losango(cor: Cor.ouro, pulsar: true),
        const SizedBox(width: 10),
        Text('CARREGANDO', style: fonteTitulo(13)),
        const SizedBox(width: 12),
        if (fila.isNotEmpty)
          Expanded(
            child: Text(
              fila,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: TextStyle(color: Cor.apagado, fontSize: 13),
            ),
          ),
      ],
    );
    if (_deitado(context)) {
      return LayoutBuilder(
        builder: (context, c) {
          // as cartas usam a altura toda; os textos vão pras sobras dos lados (a carta segue a altura,
          // então sempre sobra largura). Sem sobra suficiente, volta a faixa em cima
          // fica com o que der a carta maior: texto do lado (cartas com a altura toda, mas largura
          // limitada pela sobra mínima) ou faixa em cima. No iPhone o notch come os lados e a faixa ganha
          const ladoMin = 90.0, faixa = 22.0 + 6;
          final largLado = math.min(
            (c.maxWidth - 2 * ladoMin - 4 * 8) / 5,
            (c.maxHeight - 8) / 2 * 0.78,
          );
          final largCima = math.min(
            (c.maxWidth - 4 * 8) / 5,
            (c.maxHeight - faixa - 8) / 2 * 0.78,
          );
          final bloco = 5 * largLado + 4 * 8;
          final lado = (c.maxWidth - bloco) / 2;
          final cartas = Column(
            children: [
              Expanded(child: _FileiraCartas(time: nos, nosso: true, base: 0)),
              const SizedBox(height: 8),
              Expanded(
                child: _FileiraCartas(time: eles, nosso: false, base: 5),
              ),
            ],
          );
          if (largCima > largLado) {
            return Column(
              children: [
                SizedBox(height: 22, child: topo),
                const SizedBox(height: 6),
                Expanded(child: cartas),
              ],
            );
          }
          return Row(
            children: [
              SizedBox(
                width: lado,
                child: Padding(
                  padding: const EdgeInsets.only(right: 12, top: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // losango em cima do texto: lado a lado não cabia na sobra estreita do iPhone
                      Padding(
                        padding: EdgeInsets.only(right: 2, bottom: 6),
                        child: Losango(cor: Cor.ouro, pulsar: true),
                      ),
                      // Cinzel em caixa alta não cabe na sobra do lado: fonte do texto, em dourado
                      Text(
                        'Carregando',
                        maxLines: 1,
                        overflow: TextOverflow.fade,
                        softWrap: false,
                        style: TextStyle(
                          color: Cor.ouro,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (fila.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          fila,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: Cor.apagado,
                            fontSize: 12,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              SizedBox(width: bloco, child: cartas),
              // vazio do outro lado: as cartas ficam no meio da tela
              SizedBox(width: lado),
            ],
          );
        },
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: 22, child: topo),
        const SizedBox(height: 8),
        Expanded(child: _ListaFaixas(time: nos, nosso: true, base: 0)),
        const SizedBox(height: 16), // separa os times sem rótulo
        Expanded(child: _ListaFaixas(time: eles, nosso: false, base: 5)),
      ],
    );
  }
}

/// Deitado: as cartas do jogo, cinco por fileira, seu time em cima.
class _FileiraCartas extends StatelessWidget {
  const _FileiraCartas({
    required this.time,
    required this.nosso,
    required this.base,
  });
  final List<Map> time;
  final bool nosso;
  final int base;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      // em pé como a carta do jogo: a largura segue a altura, sem esticar
      final larg = math.min((c.maxWidth - 4 * 8) / 5, c.maxHeight * 0.78);
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final (i, j) in time.indexed) ...[
            if (i > 0) const SizedBox(width: 8),
            SizedBox(
              width: larg,
              height: c.maxHeight,
              child: _Entrada(
                key: ValueKey('carta-${base + i}'),
                chave: 'carta-${base + i}-${j['campeao']}',
                atraso: (base + i) * 45,
                child: _Carta2(j: j, nosso: nosso),
              ),
            ),
          ],
        ],
      );
    },
  );
}

class _Carta2 extends StatelessWidget {
  const _Carta2({required this.j, required this.nosso});
  final Map j;
  final bool nosso;

  @override
  Widget build(BuildContext context) {
    final eu = j['eu'] == true;
    final cid = (j['campeao'] as num?)?.toInt() ?? 0;
    final elo = _textoElo(j['elo']);
    return Container(
      decoration: BoxDecoration(
        color: Cor.painel,
        borderRadius: Raio.r2,
        border: Border.all(
          color: eu ? Cor.ouro : Cor.ouroEscuro.withValues(alpha: 0.8),
          width: eu ? 1.5 : 1,
        ),
        boxShadow: eu
            ? [
                BoxShadow(
                  color: Cor.ouro.withValues(alpha: 0.25),
                  blurRadius: 14,
                ),
              ]
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _ArteFade(
            url: _arte(j['tela'], cid),
            alinhamento: const Alignment(0, -0.55),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                // escurece cedo: nome dourado em cima de arte clara sumia
                stops: [0.3, 0.68, 1],
                colors: [
                  Color(0x00010A13),
                  Color(0xD9010A13),
                  Color(0xFA010A13),
                ],
              ),
            ),
          ),
          // fio do time no topo: verde-água o seu, vermelho o inimigo
          Align(
            alignment: Alignment.topCenter,
            child: Container(
              height: 2,
              color: (nosso ? Cor.teal : Cor.vermelho).withValues(alpha: 0.8),
            ),
          ),
          Positioned(
            left: 6,
            right: 6,
            bottom: 6,
            child: Column(
              children: [
                Text(
                  '${j['skin'] ?? j['nome_campeao'] ?? ''}'.toUpperCase(),
                  maxLines:
                      2, // nome de skin é comprido: quebra em vez de cortar
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: fonteTitulo(9.5, cor: Cor.ouro).copyWith(height: 1.15),
                ),
                const SizedBox(height: 2),
                Text(
                  '${j['nome'] ?? ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: eu ? Cor.ouroClaro : Cor.texto,
                    fontSize: 12,
                    fontWeight: eu ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _Feiticos2(j: j, tamanho: 15),
                    if (elo.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          elo,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Cor.apagado, fontSize: 10.5),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Em pé: cada jogador numa faixa com a arte da skin ao fundo, cinco por time.
class _ListaFaixas extends StatelessWidget {
  const _ListaFaixas({
    required this.time,
    required this.nosso,
    required this.base,
  });
  final List<Map> time;
  final bool nosso;
  final int base;

  @override
  Widget build(BuildContext context) {
    final cor = nosso ? Cor.teal : Cor.vermelho;
    // sem rótulo de time: o fio colorido de cada faixa já diz de que lado ela é
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, j) in time.indexed) ...[
          if (i > 0) const SizedBox(height: 5),
          Expanded(
            child: _Entrada(
              key: ValueKey('faixa-${base + i}'),
              chave: 'faixa-${base + i}-${j['campeao']}',
              atraso: (base + i) * 40,
              child: _Faixa(j: j, cor: cor),
            ),
          ),
        ],
      ],
    );
  }
}

class _Faixa extends StatelessWidget {
  const _Faixa({required this.j, required this.cor});
  final Map j;
  final Color cor;

  @override
  Widget build(BuildContext context) {
    final eu = j['eu'] == true;
    final cid = (j['campeao'] as num?)?.toInt() ?? 0;
    final elo = _textoElo(j['elo']);
    final tag = '${j['tag'] ?? ''}';
    return Container(
      decoration: BoxDecoration(
        color: Cor.painel,
        borderRadius: Raio.r2,
        border: Border.all(
          color: eu ? Cor.ouro : Cor.linha2,
          width: eu ? 1.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // arte à direita, sumindo pra esquerda onde fica o texto
          Positioned(
            top: 0,
            bottom: 0,
            right: 0,
            width: 230,
            child: _ArteFade(
              url: _arte(j['arte'], cid),
              alinhamento: const Alignment(0.2, -0.45),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                stops: [0.3, 0.75],
                colors: [Cor.painel, Color(0x000A1219)],
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(width: 3, color: cor.withValues(alpha: 0.85)),
          ),
          LayoutBuilder(
            builder: (context, c) {
              // celular baixo: faixa sem altura pra três linhas, o elo vai pro lado do nome da skin
              final compacto = c.maxHeight < 58;
              final eloTexto = Text(
                elo,
                maxLines: 1,
                style: TextStyle(color: Cor.apagado, fontSize: 12),
              );
              return Padding(
                padding: const EdgeInsets.fromLTRB(14, 4, 10, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  '${j['skin'] ?? j['nome_campeao'] ?? ''}'
                                      .toUpperCase(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: fonteTitulo(11, cor: Cor.ouro),
                                ),
                              ),
                              if (compacto && elo.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                eloTexto,
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: '${j['nome'] ?? ''}',
                                  style: TextStyle(
                                    color: eu ? Cor.ouroClaro : Cor.texto,
                                    fontWeight: eu
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                  ),
                                ),
                                if (tag.isNotEmpty)
                                  TextSpan(
                                    text: ' #$tag',
                                    style: TextStyle(color: Cor.apagado),
                                  ),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14),
                          ),
                          if (!compacto && elo.isNotEmpty) eloTexto,
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    _Feiticos2(
                      j: j,
                      tamanho: compacto ? 18 : 20,
                      vertical: !compacto,
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
