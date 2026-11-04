part of 'main.dart';

// Arena 3x6 (gameMode CHERRY). O que as capturas reais mostram: 18 jogadores em 6 times de 3 (as células 0-2, 3-5,
// 6-8...; o seu time é o que tem a sua célula, os outros vêm sem nome), ban e pick simultâneos (todo mundo com a vez
// em andamento ao mesmo tempo), campeão repetido vale, o client esconde o campeão de quem ainda não quer mostrar
// (`oculto`). Sem runa, troca de campeão nem banco; o par de feitiço é sempre Fuga + Flash e só dá pra inverter D e F.

bool _ehArena(Map sel) => sel['arena'] == true;

/// Estamos na fase de banir (alguém ainda tem ban em andamento).
bool _banindoArena(List<Map> meu) => meu.any((m) => m['vez'] == 'ban');

int _timeArena(Map m) => ((m['cell'] as num?)?.toInt() ?? 0) ~/ 3;

/// Os jogadores em times de 3, o seu primeiro (o resto na ordem das células).
List<List<Map>> _timesArena(List<Map> meu) {
  final por = <int, List<Map>>{};
  for (final m in meu) {
    por.putIfAbsent(_timeArena(m), () => []).add(m);
  }
  final chaves = por.keys.toList()..sort();
  final meuTime = meu.where((m) => m['eu'] == true).map(_timeArena).firstOrNull;
  if (meuTime != null && chaves.remove(meuTime)) chaves.insert(0, meuTime);
  return [for (final k in chaves) por[k]!];
}

/// Quadro dos 6 times de 3: o seu em cima, em linhas grandes, e os outros em cartões menores em [colunas] colunas.
/// Cada jogador mostra o campeão (marcado ou travado), o ban e quem ainda está escolhendo.
class _QuadroArena extends StatelessWidget {
  const _QuadroArena({required this.sel, required this.colunas});
  final Map sel;
  final int colunas;

  @override
  Widget build(BuildContext context) {
    String nome(int id) => _nomeCampeao(sel['nomes'], id);
    final meu = ((sel['meu'] as List?) ?? const []).cast<Map>();
    final banindo = _banindoArena(meu);
    bool feito(Map m) =>
        banindo ? m['ban_travado'] == true : m['travado'] == true;
    final total = meu.where(feito).length;
    final times = _timesArena(meu);
    Widget carta(Map m, int atraso) => _Entrada(
      key: ValueKey('arena-${m['cell']}'),
      chave: 'arena-${m['cell']}',
      atraso: atraso,
      child: _CartaArenaSel(
        m: m,
        nome: nome,
        n: ((m['cell'] as num?)?.toInt() ?? 0) + 1,
        banindo: banindo,
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 0, 2, 6),
          child: Row(
            children: [
              Text(
                banindo ? 'BANIMENTOS' : 'JOGADORES',
                style: fonteTitulo(
                  11,
                  cor: banindo ? Cor.vermelho : Cor.apagado,
                ),
              ),
              const Spacer(),
              if (meu.isNotEmpty)
                Text(
                  banindo
                      ? '$total/${meu.length} já baniram'
                      : '$total/${meu.length} já escolheram',
                  style: TextStyle(color: Cor.apagado, fontSize: 12),
                ),
            ],
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, c) {
              const gap = 6.0;
              final larg = (c.maxWidth - gap * (colunas - 1)) / colunas;
              final outros = times.skip(1).toList();
              final linhas = (outros.length / colunas).ceil();
              Widget outro(int idx) => _BlocoTimeArena(
                titulo: 'TIME ${idx + 2}',
                feitos: outros[idx].where(feito).length,
                total: outros[idx].length,
                children: [
                  for (final (i, m) in outros[idx].indexed)
                    SizedBox(
                      height: 40,
                      child: carta(m, (idx + 1) * 60 + i * 20),
                    ),
                ],
              );
              return RepaintBoundary(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (times.isNotEmpty)
                        _BlocoTimeArena(
                          titulo: 'SEU TIME',
                          destaque: true,
                          feitos: times[0].where(feito).length,
                          total: times[0].length,
                          children: [
                            for (final (i, m) in times[0].indexed)
                              SizedBox(height: 56, child: carta(m, i * 30)),
                          ],
                        ),
                      for (var l = 0; l < linhas; l++) ...[
                        const SizedBox(height: gap),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (var k = 0; k < colunas; k++) ...[
                              if (k > 0) const SizedBox(width: gap),
                              SizedBox(
                                width: larg,
                                child: l * colunas + k < outros.length
                                    ? outro(l * colunas + k)
                                    : null,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Um time de 3 no quadro da seleção: título com quantos já terminaram e os 3 jogadores embaixo.
class _BlocoTimeArena extends StatelessWidget {
  const _BlocoTimeArena({
    required this.titulo,
    required this.feitos,
    required this.total,
    required this.children,
    this.destaque = false,
  });
  final String titulo;
  final int feitos;
  final int total;
  final bool destaque;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(5),
    decoration: BoxDecoration(
      borderRadius: Raio.r2,
      color: destaque ? Cor.ouro.withValues(alpha: 0.04) : null,
      border: Border.all(
        color: destaque ? Cor.ouro.withValues(alpha: 0.45) : Cor.linha2,
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(3, 0, 3, 5),
          child: Row(
            children: [
              if (destaque) ...[
                Losango(cor: Cor.ouro, tamanho: 6),
                const SizedBox(width: 6),
              ],
              Text(
                titulo,
                style: fonteTitulo(
                  10.5,
                  cor: destaque ? Cor.ouro : Cor.apagado,
                ),
              ),
              const Spacer(),
              Text(
                '$feitos/$total',
                style: TextStyle(
                  color: feitos == total ? Cor.teal : Cor.apagado,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        for (final (i, f) in children.indexed) ...[
          if (i > 0) const SizedBox(height: 4),
          f,
        ],
      ],
    ),
  );
}

class _CartaArenaSel extends StatelessWidget {
  const _CartaArenaSel({
    required this.m,
    required this.nome,
    required this.n,
    required this.banindo,
  });
  final Map m;
  final String Function(int) nome;
  final int n;
  final bool banindo;

  @override
  Widget build(BuildContext context) {
    final cid = (m['campeao'] as num?)?.toInt() ?? 0;
    final intencao = (m['intencao'] as num?)?.toInt() ?? 0;
    final ban = (m['ban'] as num?)?.toInt() ?? 0;
    final banTravado = m['ban_travado'] == true;
    final travado = m['travado'] == true;
    final vez = '${m['vez'] ?? ''}';
    final eu = m['eu'] == true;
    final oculto = m['oculto'] == true && cid == 0;
    final jogador = eu
        ? 'Você'
        : '${m['nome'] ?? ''}'.isEmpty
        ? 'Jogador $n'
        : '${m['nome']}';
    var linha = '';
    var corLinha = Cor.apagado;
    var italico = false;
    if (banindo) {
      if (ban > 0 && banTravado) {
        linha = 'Baniu ${nome(ban)}';
        corLinha = Cor.vermelho;
      } else if (ban > 0) {
        linha = 'Marcou ${nome(ban)}';
        italico = true;
      } else if (vez == 'ban') {
        linha = 'Banindo...';
      } else if (banTravado) {
        linha = 'Não baniu';
      }
    } else if (cid > 0) {
      linha = nome(cid);
      corLinha = travado ? Cor.texto : Cor.apagado;
      italico = !travado;
    } else if (intencao > 0) {
      linha = nome(intencao);
      italico = true;
    } else if (oculto) {
      linha = 'Escondido';
      italico = true;
    } else if (vez == 'pick') {
      linha = 'Escolhendo...';
    }
    final feito = banindo ? banTravado : travado;
    return LayoutBuilder(
      builder: (context, c) {
        // cartão estreito (deitado, 3 colunas): sem reticências nem o visto, a borda já diz quem terminou
        final estreito = c.maxWidth < 135;
        final lado = (c.maxHeight - 12).clamp(24.0, 42.0);
        final Widget retrato;
        if (oculto) {
          retrato = _CampeaoFechado(tamanho: lado);
        } else {
          // na fase de banir o retrato é o ban (riscado quando travou); depois, o campeão com o ban de canto
          final id = banindo ? ban : (cid > 0 ? cid : intencao);
          retrato = _IconeCamp(
            id: id,
            tamanho: lado,
            banido: banindo && id > 0 && banTravado,
            fraco: id > 0 && (banindo ? !banTravado : !travado),
            destaque: eu,
            corBorda: vez.isNotEmpty ? Cor.ouro : null,
          );
        }
        return AnimatedContainer(
          duration: _dur(context, 300),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            borderRadius: Raio.r1,
            color: eu
                ? Cor.ouro.withValues(alpha: 0.10)
                : (vez.isNotEmpty
                      ? Cor.ouro.withValues(alpha: 0.05)
                      : Cor.painel),
            border: Border.all(
              color: eu
                  ? Cor.ouro.withValues(alpha: 0.8)
                  : (feito ? Cor.teal.withValues(alpha: 0.45) : Cor.linha2),
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: lado,
                height: lado,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    retrato,
                    if (ban > 0 && !banindo)
                      Positioned(
                        right: -4,
                        bottom: -4,
                        child: _IconeCamp(
                          id: ban,
                          tamanho: lado * 0.46,
                          banido: true,
                          fraco: !banTravado,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            jogador,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: estreito ? 12 : 12.5,
                              color: eu ? Cor.ouroClaro : Cor.texto,
                            ),
                          ),
                        ),
                        if (feito && !estreito) ...[
                          const SizedBox(width: 4),
                          Icon(Icons.check_rounded, size: 13, color: Cor.teal),
                        ],
                      ],
                    ),
                    if (linha.isNotEmpty)
                      Text(
                        linha,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: corLinha,
                          fontSize: estreito ? 11 : 11.5,
                          fontStyle: italico
                              ? FontStyle.italic
                              : FontStyle.normal,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Campeão que o client esconde (ainda não é pra mostrar): cartão fechado com cadeado.
class _CampeaoFechado extends StatelessWidget {
  const _CampeaoFechado({required this.tamanho});
  final double tamanho;

  @override
  Widget build(BuildContext context) => Container(
    width: tamanho,
    height: tamanho,
    decoration: BoxDecoration(
      borderRadius: Raio.r1,
      color: Cor.painel2,
      border: Border.all(color: Cor.ouroEscuro.withValues(alpha: 0.7)),
    ),
    child: Icon(
      Icons.lock_outline_rounded,
      size: tamanho * 0.48,
      color: Cor.ouroEscuro,
    ),
  );
}

/// Em pé, na sua vez e nas skins: os 6 times de 3 em miniaturas (o campeão, ou o ban na fase de banir), o seu primeiro.
class _FaixaArena extends StatelessWidget {
  const _FaixaArena({required this.sel});
  final Map sel;

  @override
  Widget build(BuildContext context) {
    final meu = ((sel['meu'] as List?) ?? const []).cast<Map>();
    final banindo = _banindoArena(meu);
    final times = _timesArena(meu);
    return LayoutBuilder(
      builder: (context, c) {
        const gap = 3.0, entre = 8.0, porLinha = 3;
        final largTime = (c.maxWidth - entre * (porLinha - 1)) / porLinha;
        // miniatura = (largura do time - borda e recuo - 2 vãos) / 3
        final lado = ((largTime - 10 - gap * 2) / 3).floorToDouble().clamp(
          20.0,
          34.0,
        );
        Widget mini(Map m) {
          final cid = (m['campeao'] as num?)?.toInt() ?? 0;
          final intencao = (m['intencao'] as num?)?.toInt() ?? 0;
          final ban = (m['ban'] as num?)?.toInt() ?? 0;
          if (m['oculto'] == true && cid == 0 && !banindo) {
            return _CampeaoFechado(tamanho: lado);
          }
          final id = banindo ? ban : (cid > 0 ? cid : intencao);
          return _IconeCamp(
            id: id,
            tamanho: lado,
            banido: banindo && id > 0 && m['ban_travado'] == true,
            fraco: banindo ? m['ban_travado'] != true : m['travado'] != true,
            destaque: m['eu'] == true,
          );
        }

        Widget time(List<Map> t, bool meuTime) => Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            borderRadius: Raio.r1,
            border: Border.all(
              color: meuTime ? Cor.ouro.withValues(alpha: 0.5) : Cor.linha2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (i, m) in t.indexed) ...[
                if (i > 0) const SizedBox(width: gap),
                KeyedSubtree(
                  key: ValueKey('mini-${m['cell']}'),
                  child: mini(m),
                ),
              ],
            ],
          ),
        );

        final linhas = (times.length / porLinha).ceil();
        return RepaintBoundary(
          child: Column(
            children: [
              for (var l = 0; l < linhas; l++) ...[
                if (l > 0) const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var k = 0; k < porLinha; k++)
                      if (l * porLinha + k < times.length) ...[
                        if (k > 0) const SizedBox(width: entre),
                        KeyedSubtree(
                          key: ValueKey('time-${l * porLinha + k}'),
                          child: time(
                            times[l * porLinha + k],
                            l * porLinha + k == 0,
                          ),
                        ),
                      ],
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Tela de carregamento da Arena: os 18 jogadores em tamanho normal numa lista que rola, você primeiro. O seu time
/// e os times que dá pra confirmar (`time` do PC: premade de 3) ficam em blocos separados; quem não dá pra agrupar
/// vem junto no fim. Em pé uma faixa por jogador (rola pra baixo); deitado as cartas lado a lado (rola pro lado).
class _CarregamentoArena extends StatelessWidget {
  const _CarregamentoArena({required this.con});
  final Conexao con;

  @override
  Widget build(BuildContext context) {
    final c = con.estado['carregamento'] as Map;
    final jogadores = _time(c['jogadores']);
    final fila = '${c['fila'] ?? ''}';
    final deitado = _deitado(context);
    final topo = SizedBox(
      height: 22,
      child: Row(
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
      ),
    );

    // blocos seguidos com o mesmo `time` (sem `time` = os outros jogadores)
    final blocos = <(int?, List<(int, Map)>)>[];
    for (final (i, j) in jogadores.indexed) {
      final t = (j['time'] as num?)?.toInt();
      if (blocos.isEmpty || blocos.last.$1 != t) blocos.add((t, []));
      blocos.last.$2.add((i, j));
    }
    // nenhum time conhecido (PC antigo): uma lista só, sem rótulo
    final semGrupos = blocos.every((b) => b.$1 == null);
    String rotulo((int?, List<(int, Map)>) b) => switch (b.$1) {
      0 => 'SEU TIME',
      final int t => 'TIME ${t + 1}',
      null => 'OUTROS JOGADORES',
    };

    Widget entrada(int i, Widget filho) => _Entrada(
      key: ValueKey('carga-arena-$i'),
      chave: 'carga-arena-$i-${jogadores[i]['campeao']}',
      atraso: math.min(i, 8) * 40,
      child: filho,
    );
    Widget titulo(String texto, {required bool seu, required int n}) => Padding(
      padding: const EdgeInsets.fromLTRB(2, 0, 2, 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (seu) ...[
            Losango(cor: Cor.ouro, tamanho: 6),
            const SizedBox(width: 6),
          ],
          Text(
            texto,
            style: fonteTitulo(11, cor: seu ? Cor.ouro : Cor.apagado),
          ),
          const SizedBox(width: 8),
          Text('$n', style: TextStyle(color: Cor.apagado, fontSize: 11)),
        ],
      ),
    );

    final Widget lista;
    if (deitado) {
      lista = LayoutBuilder(
        builder: (context, c) {
          // a carta em pé como a do jogo: a largura segue a altura (descontando a linha do título do bloco)
          final alt = c.maxHeight - (semGrupos ? 0 : 24);
          final larg = math.min(alt * 0.68, 230.0);
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (k, b) in blocos.indexed) ...[
                  if (k > 0) const SizedBox(width: 22),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!semGrupos)
                        titulo(rotulo(b), seu: b.$1 == 0, n: b.$2.length),
                      Row(
                        children: [
                          for (final (m, (i, j)) in b.$2.indexed) ...[
                            if (m > 0) const SizedBox(width: 8),
                            SizedBox(
                              width: larg,
                              height: alt,
                              child: entrada(i, _CartaArena(j: j)),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ],
              ],
            ),
          );
        },
      );
    } else {
      lista = SingleChildScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (k, b) in blocos.indexed) ...[
              if (k > 0) const SizedBox(height: 18),
              if (!semGrupos) titulo(rotulo(b), seu: b.$1 == 0, n: b.$2.length),
              for (final (m, (i, j)) in b.$2.indexed) ...[
                if (m > 0) const SizedBox(height: 6),
                SizedBox(
                  height: 78,
                  child: entrada(
                    i,
                    _Faixa(
                      j: j,
                      cor: j['eu'] == true
                          ? Cor.teal
                          : (b.$1 == null ? Cor.linha2 : Cor.ouroEscuro),
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        topo,
        const SizedBox(height: 8),
        Expanded(child: RepaintBoundary(child: lista)),
      ],
    );
  }
}

/// Carta de um jogador na tela de carregamento da Arena: arte da skin, campeão e Riot ID.
class _CartaArena extends StatelessWidget {
  const _CartaArena({required this.j});
  final Map j;

  @override
  Widget build(BuildContext context) {
    final eu = j['eu'] == true;
    final cid = (j['campeao'] as num?)?.toInt() ?? 0;
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
                  blurRadius: 12,
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
            alinhamento: const Alignment(0, -0.5),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.4, 0.78, 1],
                colors: [
                  Cor.fundo.withValues(alpha: 0.0),
                  Cor.fundo.withValues(alpha: 0.85),
                  Cor.fundo.withValues(alpha: 0.98),
                ],
              ),
            ),
          ),
          if (eu)
            Align(
              alignment: Alignment.topCenter,
              child: Container(
                height: 2,
                color: Cor.teal.withValues(alpha: 0.8),
              ),
            ),
          Positioned(
            left: 6,
            right: 6,
            bottom: 8,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${j['nome_campeao'] ?? ''}'.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: fonteTitulo(10, cor: Cor.ouro),
                ),
                const SizedBox(height: 1),
                Text(
                  eu ? 'Você' : '${j['nome'] ?? ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: eu ? Cor.ouroClaro : Cor.texto,
                    fontSize: 12.5,
                    fontWeight: eu ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
