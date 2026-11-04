part of 'main.dart';

/// Página Tema (abre por cima da lista da aba Mais, como Avisos): o modo (escuro ou claro) e a região (a do
/// client ou uma de Runeterra), cada cartão já nas cores do tema que ele escolhe, no modo em uso.
class _PaginaTemas extends StatelessWidget {
  const _PaginaTemas({super.key, required this.aoVoltar, this.base = 0});
  final VoidCallback aoVoltar;
  final double base;

  @override
  Widget build(BuildContext context) {
    final deitado = _deitado(context);
    return _Rolavel(
      base: base,
      largura: deitado ? 900 : 520,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Voltar(aoTocar: aoVoltar, titulo: 'Tema'),
          const SizedBox(height: 10),
          _Entrada(
            chave: 'tema-grade',
            // o cartão da página se refaz com o tema (as cores do Cartao e do título mudam junto)
            child: ListenableBuilder(
              listenable: Temas.mudou,
              builder: (_, _) => Cartao(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('APARÊNCIA', style: fonteTitulo(13)),
                    const SizedBox(height: 4),
                    Text(
                      'As cores do app. O painel do PC tem os mesmos temas.',
                      style: TextStyle(color: Cor.apagado, fontSize: 13.5),
                    ),
                    const SizedBox(height: 14),
                    _SeletorModo(claro: Temas.claro.value),
                    const SizedBox(height: 14),
                    _GradeTemas(
                      atual: Temas.id.value,
                      claro: Temas.claro.value,
                      colunas: deitado ? 4 : 2,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Escuro ou claro: vale pra região escolhida. O realce desliza pro lado tocado.
class _SeletorModo extends StatelessWidget {
  const _SeletorModo({required this.claro});
  final bool claro;

  @override
  Widget build(BuildContext context) {
    Widget opcao(bool deste, IconData icone, String nome) {
      final ligado = deste == claro;
      final cor = ligado ? Cor.ouroClaro : Cor.apagado;
      return Expanded(
        child: Semantics(
          button: true,
          selected: ligado,
          label: 'Modo $nome',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (ligado) return;
              som.tocar('clique');
              Temas.escolherModo(deste);
            },
            child: SizedBox(
              height: 44,
              child: ExcludeSemantics(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedRotation(
                      turns: ligado ? 0 : -0.06,
                      duration: _dur(context, 400),
                      curve: curvaSaida,
                      child: Icon(icone, size: 17, color: cor),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      nome.toUpperCase(),
                      style: TextStyle(
                        color: cor,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.9,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        border: Border.all(color: Cor.linha2),
        borderRadius: Raio.r2,
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedAlign(
              alignment: claro ? Alignment.centerRight : Alignment.centerLeft,
              duration: _dur(context, 280),
              curve: curvaSaida,
              child: FractionallySizedBox(
                widthFactor: 0.5,
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Cor.ouro.withValues(alpha: 0.12),
                    borderRadius: Raio.r1,
                    border: Border.all(color: Cor.ouroEscuro),
                  ),
                ),
              ),
            ),
          ),
          Row(
            children: [
              opcao(false, Icons.dark_mode_outlined, 'Escuro'),
              opcao(true, Icons.light_mode_outlined, 'Claro'),
            ],
          ),
        ],
      ),
    );
  }
}

class _GradeTemas extends StatelessWidget {
  const _GradeTemas({
    required this.atual,
    required this.claro,
    required this.colunas,
  });
  final String atual;
  final bool claro;
  final int colunas;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      const folga = 10.0;
      final largura = (c.maxWidth - folga * (colunas - 1)) / colunas;
      return Wrap(
        spacing: folga,
        runSpacing: folga,
        children: [
          for (final t in temasApp)
            SizedBox(
              key: ValueKey('tema-${t.id}'),
              width: largura,
              child: _CartaoTema(
                tema: t,
                paleta: t.paleta(claro),
                escolhido: t.id == atual,
              ),
            ),
        ],
      );
    },
  );
}

/// Um tema: fundo e fio no próprio tema, quatro losangos (destaque, segundo destaque, superfície, texto)
/// e o nome. O escolhido ganha borda e brilho na cor do tema.
class _CartaoTema extends StatefulWidget {
  const _CartaoTema({
    required this.tema,
    required this.paleta,
    required this.escolhido,
  });
  final TemaApp tema;
  final Paleta paleta;
  final bool escolhido;

  @override
  State<_CartaoTema> createState() => _CartaoTemaState();
}

class _CartaoTemaState extends State<_CartaoTema> {
  bool _apertado = false;

  void _apertar(bool v) {
    if (v != _apertado) setState(() => _apertado = v);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tema;
    final p = widget.paleta;
    final ligado = widget.escolhido;
    Widget losango(Color cor, {bool contorno = false}) => Transform.rotate(
      angle: 0.7853981634,
      child: Container(
        width: 11,
        height: 11,
        decoration: BoxDecoration(
          color: cor,
          borderRadius: Raio.r1,
          border: contorno ? Border.all(color: p.linha2) : null,
        ),
      ),
    );
    return Semantics(
      button: true,
      selected: ligado,
      label: 'Tema ${t.nome}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _apertar(true),
        onTapCancel: () => _apertar(false),
        onTapUp: (_) => _apertar(false),
        onTap: () {
          if (ligado) return;
          som.tocar('clique');
          Temas.escolher(t.id);
        },
        child: AnimatedScale(
          scale: _apertado ? 0.96 : 1,
          duration: _dur(context, 120),
          curve: curvaSaida,
          child: AnimatedContainer(
            duration: _dur(context, 220),
            curve: curvaSaida,
            decoration: BoxDecoration(
              color: p.fundo,
              borderRadius: Raio.r2,
              border: Border.all(
                color: ligado ? Cor.ouro : p.linha2,
                width: ligado ? 1.5 : 1,
              ),
              boxShadow: [
                if (ligado)
                  BoxShadow(
                    color: Cor.ouro.withValues(alpha: 0.28),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
              ],
            ),
            child: ClipRRect(
              borderRadius: Raio.r2,
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    height: 2,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [p.ouroEscuro, p.ouro, p.ouroEscuro],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            losango(p.ouro),
                            const SizedBox(width: 9),
                            losango(p.teal),
                            const SizedBox(width: 9),
                            losango(p.painel2, contorno: true),
                            const SizedBox(width: 9),
                            losango(p.texto),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          t.nome.toUpperCase(),
                          maxLines: 2,
                          style: fonteTitulo(12, cor: p.ouroClaro),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    right: 10,
                    top: 14,
                    child: AnimatedScale(
                      scale: ligado ? 1 : 0,
                      duration: _dur(context, 280),
                      curve: curvaSaida,
                      child: Transform.rotate(
                        angle: 0.7853981634,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Cor.ouro,
                            borderRadius: Raio.r1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
