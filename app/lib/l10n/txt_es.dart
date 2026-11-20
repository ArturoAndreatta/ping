// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'txt.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class TxtEs extends Txt {
  TxtEs([String locale = 'es']) : super(locale);

  @override
  String get pagTema => 'Tema';

  @override
  String get temaAparencia => 'Apariencia';

  @override
  String get temaTexto =>
      'Los colores de la app. La ventana del PC tiene los mismos temas.';

  @override
  String get modoEscuro => 'Oscuro';

  @override
  String get modoClaro => 'Claro';

  @override
  String modoSemantica(String nome) {
    return 'Modo $nome';
  }

  @override
  String temaSemantica(String nome) {
    return 'Tema $nome';
  }

  @override
  String get temaClient => 'Client';

  @override
  String get temaBilgewater => 'Aguas Estancadas';

  @override
  String get temaSombras => 'Islas de la Sombra';

  @override
  String get temaBandopolis => 'Ciudad de Bandle';

  @override
  String get temaVazio => 'El Vacío';

  @override
  String get idiomaTitulo => 'Idioma';

  @override
  String get idiomaCabecalho => 'Idioma';

  @override
  String get idiomaTexto => 'Automático sigue el idioma del dispositivo.';

  @override
  String get idiomaAutomatico => 'Automático';

  @override
  String temaResumo(String regiao, String modo) {
    return '$regiao, $modo';
  }

  @override
  String get abaAoVivo => 'En vivo';

  @override
  String get abaHoje => 'Hoy';

  @override
  String get abaMais => 'Más';

  @override
  String get abasSemantica => 'Pestañas';

  @override
  String get hojeMinutos => 'Minutos';

  @override
  String get hojeHoras => 'Horas';

  @override
  String get hojeVazioTitulo => 'Ninguna partida hoy';

  @override
  String get hojeVazioTexto =>
      'Juega una partida y el resumen del día aparece aquí.';

  @override
  String get hojeSoRemakes => 'Solo remakes hasta ahora.';

  @override
  String get hojeTitulo => 'Hoy';

  @override
  String get hojeWinrate => 'Win rate';

  @override
  String hojeSiglaV(int n) {
    return '${n}V';
  }

  @override
  String hojeSiglaD(int n) {
    return '${n}D';
  }

  @override
  String get hojePartidas => 'Partidas';

  @override
  String get hojeMvp => 'MVP del día';

  @override
  String hojeMvpVitorias(int v, int n) {
    String _temp0 = intl.Intl.pluralLogic(
      v,
      locale: localeName,
      other: '$v victorias',
      one: '1 victoria',
    );
    return '$_temp0 de $n';
  }

  @override
  String get hojePartidasTitulo => 'Partidas';

  @override
  String get hojeRemake => 'Remake';

  @override
  String get resVitoria => 'Victoria';

  @override
  String get resDerrota => 'Derrota';

  @override
  String get maisCelular => 'Este teléfono';

  @override
  String get maisAvisos => 'Avisos';

  @override
  String get maisAvisosAtivo => 'Llegan incluso con la app cerrada.';

  @override
  String get maisAvisosInativo =>
      'Partida encontrada, tu turno y más, en el teléfono.';

  @override
  String get maisTema => 'Tema';

  @override
  String get maisSons => 'Sonidos';

  @override
  String get maisSonsTexto => 'Los sonidos del client cuando pasa algo.';

  @override
  String get voltar => 'Volver';

  @override
  String get versaoNova => '¡Versión nueva!';

  @override
  String get versaoNovaTexto => 'Actualiza antes de hacer cualquier cosa.';

  @override
  String get versaoBaixando => 'Descargando la versión nueva';

  @override
  String get versaoAtualizar => 'Actualizar ahora';

  @override
  String get x => 'Actualizar ahora';

  @override
  String get aberturaRiot => 'Abriendo el Riot Client';

  @override
  String get aberturaLeague => 'Iniciando LoL';

  @override
  String get aberturaUx => 'Cargando el client';

  @override
  String get aberturaPronto => 'Casi listo';

  @override
  String get aberturaTitulo => 'Abriendo LoL';

  @override
  String get aberturaLogin => 'Inicia sesión en el PC si te lo pide.';

  @override
  String get aberturaPronto2 => 'Listo';

  @override
  String get aberturaEsperandoLogin => 'Esperando el inicio de sesión';

  @override
  String get aberturaAberto => 'LoL abierto';

  @override
  String get aberturaQuaseLa => 'Casi listo';

  @override
  String aberturaFaltam(int s) {
    return 'Faltan ~${s}s';
  }

  @override
  String get aberturaEstimado => 'Tiempo estimado: aún aprendiendo este PC.';

  @override
  String get posTop => 'Superior';

  @override
  String get posJungle => 'Jungla';

  @override
  String get posMiddle => 'Central';

  @override
  String get posBottom => 'Tirador';

  @override
  String get posUtility => 'Soporte';

  @override
  String get posFill => 'Relleno';

  @override
  String get escolher => 'Elegir';

  @override
  String get posPrimeiraSem => 'Primera posición';

  @override
  String get posSegundaSem => 'Segunda posición';

  @override
  String get posPrimeira => 'Primera';

  @override
  String get posSegunda => 'Segunda';

  @override
  String get posSua => 'Tu posición';

  @override
  String get cartasTitulo => 'Elige tu campeón';

  @override
  String get cartasTexto => 'Toca una carta';

  @override
  String get cartasEscolher => 'Elegir carta';

  @override
  String cartasEscolherNome(String nome) {
    return 'Elegir $nome';
  }

  @override
  String get cartasSorte => 'Suerte';

  @override
  String get feiticoD => 'Hechizo D';

  @override
  String get feiticoF => 'Hechizo F';

  @override
  String get feiticosTitulo => 'Hechizos';

  @override
  String get banir => 'Vetar';

  @override
  String get travar => 'Fijar';

  @override
  String get escolhaBuscar => 'Buscar campeón';

  @override
  String get limpar => 'Borrar';

  @override
  String get escolhaNenhum => 'Ningún campeón con ese nombre.';

  @override
  String get ordemFavorito => 'Favorito';

  @override
  String get ordemNome => 'Nombre';

  @override
  String get ordemMaestria => 'Maestría';

  @override
  String get ordenarPor => 'Ordenar por';

  @override
  String get salaTitulo => 'En la sala';

  @override
  String get salaConvidar => 'Invitar amigos';

  @override
  String get salaTrocar => 'Cambiar';

  @override
  String get salaBuscar => 'Buscar partida';

  @override
  String get salaSair => 'Salir de la sala';

  @override
  String get salaLiderInicia => 'El líder de la sala inicia la cola.';

  @override
  String get salaEscolherPosicao => 'Elegir posición';

  @override
  String get salaEscolherSua => 'Elegir tu posición';

  @override
  String get salaConvidarCurto => 'Invitar';

  @override
  String get salaLider => 'Líder de la sala';

  @override
  String get salaProcurando => 'Buscando partida';

  @override
  String get salaSairFila => 'Salir de la cola';

  @override
  String get salaConvidado => 'Invitado, esperando respuesta';

  @override
  String get salaChatFechado => 'El chat aún no se ha abierto.';

  @override
  String get salaChatVazio => 'Aún no hay mensajes.';

  @override
  String salaVoce(String hh) {
    return 'Tú · $hh';
  }

  @override
  String get salaChat => 'Chat de la sala';

  @override
  String get erroConectar =>
      'No pude conectar. Revisa tu internet y abre la app de nuevo.';

  @override
  String get erroEmailEmUso => 'Ese correo ya tiene cuenta. Toca Entrar.';

  @override
  String get erroEmailInvalido => 'Ese correo no parece correcto.';

  @override
  String get erroSenhaFraca => 'La contraseña necesita al menos 6 caracteres.';

  @override
  String get erroMuitasTentativas => 'Demasiados intentos. Espera un poco.';

  @override
  String get erroSemInternet => 'Sin internet.';

  @override
  String get erroLogin => 'Correo o contraseña incorrectos.';

  @override
  String get erroGenerico => 'No salió bien. Inténtalo de nuevo.';

  @override
  String get erroGenericoNet => 'No salió bien. Revisa tu internet.';

  @override
  String get erroPreencher => 'Completa el correo y la contraseña.';

  @override
  String get erroAbrirConta => 'No pude abrir la cuenta. Revisa tu internet.';

  @override
  String get erroMandar => 'No pude enviar. Revisa tu internet.';

  @override
  String get erroPcMudo => 'El PC no respondió.';

  @override
  String get fechar => 'Cerrar';

  @override
  String get contaCriarTitulo => 'Crear cuenta Ping';

  @override
  String get contaEntrarTitulo => 'Entrar en la cuenta';

  @override
  String get contaCriarTexto =>
      'Luego entra con ella en la ventana de Ping en el PC.';

  @override
  String get contaEntrarTexto =>
      'Los PC de la cuenta aparecen en este teléfono.';

  @override
  String get contaEmail => 'Correo';

  @override
  String get contaSenha6 => 'Contraseña (6 caracteres o más)';

  @override
  String get contaSenha => 'Contraseña';

  @override
  String get contaBotaoCriar => 'Crear cuenta';

  @override
  String get contaBotaoEntrar => 'Entrar';

  @override
  String get contaJaTenho => 'Ya tengo cuenta';

  @override
  String get contaCriarNova => 'Crear cuenta nueva';

  @override
  String contaTambem(String contas) {
    return 'también $contas';
  }

  @override
  String get contaAberto => 'Abierto ahora.';

  @override
  String contaAbertoResto(String resto) {
    return 'Abierto · $resto';
  }

  @override
  String get contaToqueAbrir => 'Toca para abrir.';

  @override
  String get contaTirarQ => '¿Quitar de la cuenta?';

  @override
  String contaTirarTexto(String nome) {
    return '$nome sale de la lista. Para volver, entra de nuevo en la cuenta en su ventana de Ping.';
  }

  @override
  String get contaTirar => 'Quitar';

  @override
  String get cancelar => 'Cancelar';

  @override
  String get contaSairQ => '¿Salir de la cuenta?';

  @override
  String get contaSairTexto =>
      'Este teléfono deja de ver los PC. Siguen en la cuenta: solo vuelve a entrar.';

  @override
  String get contaSair => 'Salir';

  @override
  String get contaTitulo => 'Cuenta Ping';

  @override
  String get contaCriarLinha =>
      'El vínculo no se pierde y junta tus PC y smurfs.';

  @override
  String get contaEntrarLinha => 'Entra y mira los PC de la cuenta.';

  @override
  String contaPcsN(int n) {
    return '$n PC en esta cuenta. Toca para cambiar.';
  }

  @override
  String get contaQualquerCel => 'Entra con ella en cualquier teléfono.';

  @override
  String get contaTirarSem => 'Quitar de la cuenta';

  @override
  String get contaOutroPc => 'Otro PC';

  @override
  String get contaOutroPcTexto => 'Instala Ping en él y entra con esta cuenta.';

  @override
  String get contaSairLinha => 'Salir de la cuenta';

  @override
  String get contaSairLinhaTexto =>
      'En este teléfono. Los PC siguen en la cuenta.';

  @override
  String get criarTrocarModo => 'Cambiar modo';

  @override
  String get criarCriarSala => 'Crear sala';

  @override
  String get criarChamar => 'Llamar amigos';

  @override
  String get criarCriando => 'Creando sala...';

  @override
  String get criarPronto => 'Listo';

  @override
  String criarConvidarN(int n) {
    return 'Invitar ($n)';
  }

  @override
  String get criarPassoModo => 'Modo';

  @override
  String get criarPassoAmigos => 'Amigos';

  @override
  String get criarModosAbrir => 'Los modos aparecen cuando LoL esté abierto.';

  @override
  String get criarAtual => 'Actual';

  @override
  String get criarNenhumAmigo => 'Ningún amigo en línea en LoL ahora.';

  @override
  String get criarOnline => 'En línea ahora';

  @override
  String get criarDesmarcar => 'Desmarcar';

  @override
  String get criarMarcarTodos => 'Marcar todos';

  @override
  String get criarTudoParado => 'Todo tranquilo';

  @override
  String get criarTudoParadoTexto =>
      'Crea una sala y llama a tus amigos desde aquí.';

  @override
  String criarOnline1(String a) {
    return '$a está en línea';
  }

  @override
  String criarOnline2(String a, String b) {
    return '$a y $b están en línea';
  }

  @override
  String criarOnlineN(String a, int n) {
    return '$a y $n amigos más están en línea';
  }

  @override
  String get trocaAliado => 'tu aliado';

  @override
  String trocaCom(String nome) {
    return 'Cambiar con $nome';
  }

  @override
  String get trocaAceitar => 'Tiene que aceptar.';

  @override
  String get trocaPosicao => 'Posición';

  @override
  String get trocaPosicaoSem => 'Intercambian posiciones';

  @override
  String trocaVaiPraPos(String ganho) {
    return 'Tú vas a $ganho';
  }

  @override
  String get trocaOrdem => 'Orden de selección';

  @override
  String get trocaOrdemSem => 'Intercambian el turno de elegir';

  @override
  String trocaEscolheEm(String ganho) {
    return 'Tú eliges en $ganho';
  }

  @override
  String get trocaCampeao => 'Campeón';

  @override
  String get trocaCampeaoSem => 'Intercambian campeones';

  @override
  String trocaFicaCom(String ganho) {
    return 'Tú te quedas con $ganho';
  }

  @override
  String get trocaUmAliado => 'Un aliado';

  @override
  String get trocaPosRec => 'Intercambio de posición';

  @override
  String get trocaPosEnv => 'Posición pedida';

  @override
  String get trocaOrdemRec => 'Intercambio de orden';

  @override
  String get trocaOrdemEnv => 'Orden pedida';

  @override
  String get trocaCampRec => 'Solicitud de intercambio';

  @override
  String get trocaCampEnv => 'Intercambio pedido';

  @override
  String get trocaQuerPos => 'quiere intercambiar posición contigo';

  @override
  String get trocaQuerOrdem =>
      'quiere intercambiar el orden de selección contigo';

  @override
  String get trocaQuerCamp => 'quiere intercambiar contigo';

  @override
  String trocaRecebida(String nome, String quer) {
    return '$nome $quer.';
  }

  @override
  String trocaRecebidaFica(String nome, String quer, String fica) {
    return '$nome $quer: $fica.';
  }

  @override
  String trocaEsperando(String nome) {
    return 'Esperando a que $nome acepte.';
  }

  @override
  String trocaEsperandoFica(String nome, String fica) {
    return 'Esperando a que $nome acepte: $fica.';
  }

  @override
  String get recusar => 'Rechazar';

  @override
  String get aceitar => 'Aceptar';

  @override
  String get trocaCancelar => 'Cancelar solicitud';

  @override
  String get bancoTitulo => 'Banquillo';

  @override
  String get bancoNo => 'En el banquillo';

  @override
  String get bancoToque => 'Toca para tomar';

  @override
  String get bancoPegar => 'Tomar del banquillo';

  @override
  String bancoPegarNome(String nome) {
    return 'Tomar a $nome del banquillo';
  }

  @override
  String evRoubado(String nome) {
    return '$nome (robado)';
  }

  @override
  String get evPrimeiroAbate => 'Primera sangre';

  @override
  String evDragao(String tipo) {
    String _temp0 = intl.Intl.selectLogic(tipo, {
      'fire': 'Dragón infernal',
      'earth': 'Dragón de montaña',
      'water': 'Dragón de océano',
      'air': 'Dragón de nube',
      'hextech': 'Dragón hextech',
      'chemtech': 'Dragón quimtech',
      'elder': 'Dragón anciano',
      'other': 'Dragón',
    });
    return '$_temp0';
  }

  @override
  String get evArauto => 'Heraldo de la Grieta';

  @override
  String get evBarao => 'Barón Nashor';

  @override
  String get evVastilarvas => 'Larvas del Vacío';

  @override
  String get evAtakhan => 'Atakhan';

  @override
  String get evTorre => 'Torre';

  @override
  String get evInibidor => 'Inhibidor';

  @override
  String get evAce => 'Ace';

  @override
  String get partidaCarregando => 'Pantalla de carga';

  @override
  String get partidaCarregandoTexto =>
      'La partida empieza en cuanto todos carguen.';

  @override
  String get partidaTropasCampo => 'Súbditos en el campo';

  @override
  String partidaTropasSaem(String tempo) {
    return 'Los súbditos salen en $tempo';
  }

  @override
  String get partidaTropasNao => 'Los súbditos aún no han salido';

  @override
  String partidaVolta(String tempo) {
    return 'Reapareces en $tempo';
  }

  @override
  String partidaDe(String campeao) {
    return 'En partida con $campeao';
  }

  @override
  String get partidaEm => 'En partida';

  @override
  String get partidaSeuTime => 'Tu equipo';

  @override
  String get partidaInimigo => 'Enemigo';

  @override
  String get eloIron => 'Hierro';

  @override
  String get eloBronze => 'Bronce';

  @override
  String get eloSilver => 'Plata';

  @override
  String get eloGold => 'Oro';

  @override
  String get eloPlatinum => 'Platino';

  @override
  String get eloEmerald => 'Esmeralda';

  @override
  String get eloDiamond => 'Diamante';

  @override
  String get eloMaster => 'Maestro';

  @override
  String get eloGrandmaster => 'Gran Maestro';

  @override
  String get eloChallenger => 'Aspirante';

  @override
  String get partidaCarregandoTitulo => 'Cargando';

  @override
  String get voce => 'Tú';

  @override
  String timeN(int n) {
    return 'Equipo $n';
  }

  @override
  String get arenaBanimentos => 'Vetos';

  @override
  String get arenaJogadores => 'Jugadores';

  @override
  String arenaJaBaniram(int feitos, int total) {
    return '$feitos/$total ya vetaron';
  }

  @override
  String arenaJaEscolheram(int feitos, int total) {
    return '$feitos/$total ya eligieron';
  }

  @override
  String arenaJogadorN(int n) {
    return 'Jugador $n';
  }

  @override
  String arenaBaniu(String nome) {
    return 'Vetó a $nome';
  }

  @override
  String arenaMarcou(String nome) {
    return 'Marcó a $nome';
  }

  @override
  String get arenaBanindo => 'Vetando...';

  @override
  String get arenaNaoBaniu => 'No vetó';

  @override
  String get arenaEscondido => 'Oculto';

  @override
  String get arenaEscolhendo => 'Eligiendo...';

  @override
  String get arenaOutros => 'Otros jugadores';

  @override
  String get fimCedo => 'Partida terminada antes de tiempo';

  @override
  String get fimTitulo => 'Fin de la partida';

  @override
  String get fimColocacao => 'Puesto';

  @override
  String get fimTempo => 'Tiempo';

  @override
  String get msgMandarMensagem => 'Enviar mensaje';

  @override
  String get msgMandar => 'Enviar';

  @override
  String msgNovas(int n) {
    return 'Mensajes ($n nuevos)';
  }

  @override
  String get msgTitulo => 'Mensajes';

  @override
  String get msgConversas => 'Conversaciones';

  @override
  String msgVoceDois(String texto) {
    return 'Tú: $texto';
  }

  @override
  String msgLinhaSem(String nome, int n) {
    return '$nome, $n mensajes nuevos';
  }

  @override
  String msgPrimeira(String nome) {
    return 'Envía el primer mensaje a $nome.';
  }

  @override
  String msgPara(String nome) {
    return 'Mensaje para $nome';
  }

  @override
  String get msgOffline => 'Desconectado';

  @override
  String get avisosLigado => 'Activado: llega incluso con la app cerrada.';

  @override
  String get avisosChega => 'Llega incluso con la app cerrada.';

  @override
  String get avisosNegado => 'Rechazado en los ajustes del teléfono.';

  @override
  String get avisosTelaInicio =>
      'Añade la app a la pantalla de inicio para activarlo.';

  @override
  String get avisosConferindo => 'Comprobando...';

  @override
  String get avisosSemSuporte => 'Este navegador no recibe avisos.';

  @override
  String get avisosAvisar => 'Avisar en este teléfono';

  @override
  String get avisosMesmoNoPc => 'Incluso si estás en el PC';

  @override
  String get avisosMesmoNoPcTexto => 'Avisa mientras estás en el PC.';

  @override
  String get avisosOQue => 'Qué avisar';

  @override
  String get avisosErroMudar => 'No pude cambiar el aviso en este teléfono.';

  @override
  String get avisosErroSalvar => 'No se guardó. Revisa tu internet.';

  @override
  String get runasFaltaPrim => 'camino principal';

  @override
  String get runasFaltaPedra => 'piedra angular';

  @override
  String get runasFaltaRunasPrim => 'runas del principal';

  @override
  String get runasFaltaSec => 'camino secundario';

  @override
  String get runasFaltaRunasSec => '2 runas del secundario';

  @override
  String get runasFaltaFrag => 'fragmentos';

  @override
  String get runasSalvar => 'Guardar y usar';

  @override
  String runasFalta(String item) {
    return 'Falta: $item';
  }

  @override
  String runasSem(String nome) {
    return 'Runas: $nome';
  }

  @override
  String get runasPaginaNovaNome => 'Página nueva';

  @override
  String get runasTitulo => 'Runas';

  @override
  String get runasNovaPagina => 'Página nueva';

  @override
  String get runasEditarPagina => 'Editar página';

  @override
  String get runasVoltar => 'Volver a las páginas';

  @override
  String get runasSemPagina => 'Todavía no tienes una página de runas.';

  @override
  String get runasSemEspaco =>
      'No hay espacio para una página nueva: edita una de las tuyas.';

  @override
  String get runasIncompleta => 'Incompleta';

  @override
  String runasPaginaSem(String nome) {
    return '$nome, en uso';
  }

  @override
  String get runasEmUso => 'En uso';

  @override
  String get runasPrincipal => 'Principal';

  @override
  String get runasEscolhaCaminho => 'Elige un camino para empezar.';

  @override
  String get runasSecundaria => 'Secundario';

  @override
  String get runasEscolhaPrincipal => 'Elige primero el principal.';

  @override
  String get runasEscolhaSecundario => 'Elige el camino secundario.';

  @override
  String get runasFragmentos => 'Fragmentos';

  @override
  String get runasNomePagina => 'Nombre de la página';

  @override
  String get runasToque => 'Toca una runa para ver qué hace.';

  @override
  String get selChat => 'Chat de selección';

  @override
  String get selSairQ => '¿Salir de la selección?';

  @override
  String get selSairTexto => 'Sales de la partida, como en SALIR de LoL.';

  @override
  String get selSair => 'Salir';

  @override
  String get selFicar => 'Quedarme';

  @override
  String get selSemChroma => 'No tienes cromas de esta skin';

  @override
  String get selChroma => 'Cromas';

  @override
  String get selChromaSem => 'Croma que no tienes';

  @override
  String get selAramCaos => 'ARAM: Caos';

  @override
  String get selBanimentos => 'Vetos';

  @override
  String get selEscolhas => 'Selecciones';

  @override
  String get selPlanejamento => 'Planificación';

  @override
  String get selFinalizacao => 'Finalización';

  @override
  String get selComecando => 'Empezando';

  @override
  String get selTitulo => 'Selección de campeón';

  @override
  String get selBoaPartida => '¡Buena partida!';

  @override
  String get selEscolhaCarta => 'Elige una carta';

  @override
  String get selEscolhaPreparacao => 'Elige tu preparación';

  @override
  String get selSorteando => 'Sorteando campeones';

  @override
  String get selSuaVezBanir => 'Tu turno de vetar';

  @override
  String get selSuaVezEscolher => 'Tu turno de elegir';

  @override
  String get selPrepareSe => 'Prepárate, los vetos están por abrir';

  @override
  String get selEsperandoBanirem => 'Esperando a que los demás veten';

  @override
  String get selEscolhaSkin => 'Elige tu skin';

  @override
  String get selEsperandoEscolherem => 'Esperando a que los demás elijan';

  @override
  String get selDeclare => 'Declara tu campeón';

  @override
  String get selEsperandoBans => 'Esperando los vetos';

  @override
  String get selTodosEscolheram => 'Todos han elegido';

  @override
  String get selVezTime => 'Turno de tu equipo';

  @override
  String get selVezInimigo => 'Turno del equipo enemigo';

  @override
  String get selEsperando => 'Esperando';

  @override
  String get selBanaCampeao => '¡Veta un campeón!';

  @override
  String get selEscolhaCampeao => '¡Elige tu campeón!';

  @override
  String get selEscolhaPreparacaoEx => '¡Elige tu preparación!';

  @override
  String selChatSem(int n) {
    return 'Chat, $n nuevos';
  }

  @override
  String get selChatCurto => 'Chat';

  @override
  String get selTimeInimigos => 'Tu equipo';

  @override
  String get selInimigos => 'Enemigos';

  @override
  String get selBans => 'Vetos';

  @override
  String get selNenhum => 'Ninguno';

  @override
  String get selBanPulado => 'Veto omitido';

  @override
  String get selAliado => 'Aliado';

  @override
  String selInimigoN(int n) {
    return 'Enemigo $n';
  }

  @override
  String selQuer(String nome) {
    return 'Quiere a $nome';
  }

  @override
  String selPedirTroca(String nome) {
    return 'Pedir intercambio a $nome';
  }

  @override
  String get selBanindo => 'Vetando';

  @override
  String get selEscolhendo => 'Eligiendo';

  @override
  String get selSairSem => 'Salir de la selección';

  @override
  String get selSairBotao => 'Salir';

  @override
  String get dicaTelaInicio =>
      'Consejo: añade la app a la pantalla de inicio (Compartir > Añadir). Desde el icono, vuelve a entrar con tu cuenta.';

  @override
  String get mainConectando => 'Conectando';

  @override
  String get mainUmInstante => 'Solo un momento.';

  @override
  String get mainFaltaPc => 'Falta el PC';

  @override
  String mainFaltaPcTexto(String conta) {
    return 'En la ventana de Ping en el PC, abre Cuenta y entra con $conta. Aparece aquí al instante.';
  }

  @override
  String get mainEstaConta => 'esta cuenta';

  @override
  String get mainPcConectado => 'PC conectado';

  @override
  String get mainPcSemSinal => 'PC sin señal';

  @override
  String get mainPingCelular => 'Ping en el teléfono';

  @override
  String get mainEntreTexto =>
      'Entra con la misma cuenta Ping de la ventana del PC. ¿No tienes? Créala aquí y entra con ella en el PC, en Cuenta.';

  @override
  String get mainOutraConta => 'Entrar con otra cuenta';

  @override
  String get mainEsperandoPc => 'Esperando al PC';

  @override
  String get mainEsperandoPcTexto =>
      'Ping envía la primera señal en unos segundos.';

  @override
  String get mainPcSemSinalTexto =>
      'El PC está apagado, sin internet o con Ping cerrado.';

  @override
  String get mainFechandoLolTexto =>
      'LoL y el Riot Client se están cerrando en el PC.';

  @override
  String get mainLolFechado => 'LoL cerrado';

  @override
  String get mainLolFechadoTexto =>
      'Abre LoL en el PC para seguirlo desde aquí.';

  @override
  String get mainAbrirLol => 'Abrir LoL';

  @override
  String get mainEntreFila => 'Entra en la cola en el PC y síguelo desde aquí.';

  @override
  String get mainSelecao => 'Selección de campeón';

  @override
  String get mainSelecaoTexto => 'Pronto podrás elegir el campeón desde aquí.';

  @override
  String get mainPartidaAcabou => 'La partida ha terminado.';

  @override
  String mainEstimado(String tempo) {
    return 'Estimado $tempo';
  }

  @override
  String get mainAceita => 'Partida aceptada';

  @override
  String get mainAceitaTexto => 'Esperando a los demás jugadores.';

  @override
  String get mainRecusada => 'Partida rechazada';

  @override
  String get mainRecusadaTexto => 'Rechazaste esta partida.';

  @override
  String get maisPartida => 'Partida encontrada';

  @override
  String get mainEncontrada => 'Partida encontrada';

  @override
  String get mainAceitarQ => '¿Aceptar?';

  @override
  String get mainFecharRiotQ => '¿Cerrar el Riot Client?';

  @override
  String get mainFecharLolQ => '¿Cerrar LoL?';

  @override
  String get mainFecharRiotTexto => 'El Riot Client se cierra en el PC.';

  @override
  String get mainFecharFilaTexto =>
      'Sales de la cola y LoL se cierra en el PC, junto con el Riot Client.';

  @override
  String get mainFecharLolTexto =>
      'LoL se cierra en el PC, junto con el Riot Client.';

  @override
  String get mainFechar => 'Cerrar';

  @override
  String get mainFecharRiot => 'Cerrar el Riot Client';

  @override
  String get mainFecharLol => 'Cerrar LoL';

  @override
  String get mainLigarSons => 'Activar sonidos';

  @override
  String get mainDesligarSons => 'Desactivar sonidos';

  @override
  String get mainFechandoLol => 'Cerrando LoL';

  @override
  String get criarConvidado => 'Invitado';

  @override
  String runasEditarNome(String nome) {
    return 'Editar $nome';
  }

  @override
  String selSkinSem(String nome) {
    return '$nome, no la tienes';
  }

  @override
  String get runaUma => 'Runa';

  @override
  String get avisoFilaN => 'Entró en la cola';

  @override
  String get avisoFilaT => 'Cuando tú o el líder de la sala entra en la cola.';

  @override
  String get avisoPartidaN => 'Partida encontrada';

  @override
  String get avisoPartidaT => 'Cuando la cola encuentra partida.';

  @override
  String get avisoVezN => 'Tu turno';

  @override
  String get avisoVezT => 'Cuando es tu turno de elegir o vetar.';

  @override
  String get avisoTrocaN => 'Solicitud de intercambio';

  @override
  String get avisoTrocaT =>
      'Cuando un aliado pide un intercambio en la selección.';

  @override
  String get avisoConviteN => 'Invitación a una sala';

  @override
  String get avisoConviteT => 'Cuando alguien te invita a una sala.';

  @override
  String get avisoMensagemN => 'Mensajes';

  @override
  String get avisoMensagemT =>
      'Mensaje de un amigo en el chat privado o de la sala.';

  @override
  String get avisoLolProntoN => 'LoL abierto';

  @override
  String get avisoLolProntoT =>
      'Cuando el LoL que abriste desde el teléfono está listo.';

  @override
  String get avisoFimN => 'Fin de la partida';

  @override
  String get avisoFimT => 'Victoria o derrota, con tu marcador.';

  @override
  String get avisoResumoN => 'Resumen del día';

  @override
  String get avisoResumoT => 'Cuando cierras LoL.';
}
