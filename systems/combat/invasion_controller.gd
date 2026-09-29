class_name InvasionController
extends Node

enum InvasionState { NOT_STARTED, PREPARATION, ACTIVE, VICTORY, DEFEAT }

## §30: a primeira invasão é exatamente isto — duas Feras Cavernosas da mesma
## Definition, uma largada, um desfecho. Não existe fila de largadas nem fábrica de
## inimigos: só uma criatura conhecida, criada por quem detém o ciclo de vida.
const INVADER_COUNT := 2

## §3/T13: os 60 s de aviso são o valor de produção e moram todos aqui. O harness
## encurta essa mesma variável (§16/T13); nenhuma tecla de produção pula o timer.
@export var preparation_duration: float = 60.0

## §19/T17: a recompensa da primeira invasão é uma linha escrita aqui, e não um
## `RewardDefinition` nem um RewardManager. A escolha é deliberada: existe uma invasão,
## um desfecho vitorioso e uma chave. No dia em que houver uma segunda recompensa, aí
## sim o número vira dado — antes disso seria infraestrutura para um caso só.
const FIRST_VICTORY_CRYSTAL_REWARD := 1

signal invasion_started(invaders: Array)
signal invasion_victory
signal invasion_defeat
signal active_invaders_changed(current: int)
signal preparation_started(duration: float)
signal preparation_time_changed(remaining: float, duration: float)

var _definition: EnemyDefinition
var _scene: PackedScene
var _dungeon_root: Node3D
var _core: CoreRuntime
var _abyssal_crystal: AbyssalCrystalState
var _spawn_points: Array[Node3D] = []
var _invaders: Array[EnemyRuntime] = []
var _state: InvasionState = InvasionState.NOT_STARTED
var _active_invaders := 0
var _preparation_time_remaining := 0.0
var _displayed_second := 0


func _ready() -> void:
	# §5/§79/T13: nenhum Timer node e nenhum loop permanente. O countdown acorda
	# quando a preparação começa e dorme em qualquer outro estado.
	set_process(false)


## §28: tudo que o ciclo de vida precisa chega por parâmetro. Nenhum lookup global,
## nenhum grupo varrido, nenhum autoload.
func setup(
		definition: EnemyDefinition,
		enemy_scene: PackedScene,
		dungeon_root: Node3D,
		core: CoreRuntime,
		spawn_points: Array) -> void:
	_definition = definition
	_scene = enemy_scene
	_dungeon_root = dungeon_root
	_core = core
	_spawn_points.assign(spawn_points)


## §17/§18/T17: o dono do ciclo de vida passa a conhecer o registro de conquista do
## domínio. A assinatura de `setup` não mudou — os harnesses da Tarefa 12 e da Tarefa 13
## continuam ligados em três/quatro argumentos e simplesmente não têm Cristal nenhum,
## que é o retrato exato de uma partida sem vitória.
func bind_abyssal_crystal_state(crystal: AbyssalCrystalState) -> void:
	_abyssal_crystal = crystal


func invasion_state() -> InvasionState:
	return _state


func active_invaders() -> int:
	return _active_invaders


func invaders() -> Array[EnemyRuntime]:
	return _invaders


## §4/T13: quanto falta. Fora de PREPARATION o valor é 0 — não existe contagem
## parada por aí esperando para ser retomada.
func preparation_time_remaining() -> float:
	return _preparation_time_remaining


## §6/§8/T13: o Ninho concluído é o gatilho da partida normal e o F é o atalho de
## teste (§14/T13). Os dois entram por aqui, e aqui só existe uma porta: NOT_STARTED.
## Chegar de novo em PREPARATION não reinicia nada, e depois da largada não há o que
## preparar — a invasão da Tarefa 12 continua sendo uma só.
func begin_preparation() -> bool:
	if _state != InvasionState.NOT_STARTED:
		return false
	_state = InvasionState.PREPARATION
	_preparation_time_remaining = preparation_duration
	_displayed_second = _displayed_second_of(_preparation_time_remaining)
	preparation_started.emit(preparation_duration)
	preparation_time_changed.emit(_preparation_time_remaining, preparation_duration)
	set_process(true)
	return true


## §5/§79/T13: contagem por delta, nunca por Timer de um segundo nem por cadeia de
## awaits. É isso que torna o countdown igual para 30 Hz e 120 Hz (§40/T13).
func _process(delta: float) -> void:
	if _state != InvasionState.PREPARATION:
		set_process(false)
		return
	_preparation_time_remaining = maxf(_preparation_time_remaining - delta, 0.0)
	# §10/T13: o tempo interno é float contínuo, mas o HUD só precisa saber quando o
	# segundo exibido vira. Um emit por segundo de tela, não duzentos por frame.
	var second := _displayed_second_of(_preparation_time_remaining)
	if second != _displayed_second:
		_displayed_second = second
		preparation_time_changed.emit(_preparation_time_remaining, preparation_duration)
	if _preparation_time_remaining <= 0.0:
		# §12/T13: chegou a hora de usar exatamente a largada que já existia.
		start_invasion()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("start_invasion"):
		# §14/T13: o F deixou de soltar as Feras. Ele abre a preparação, e em qualquer
		# outro estado do ciclo não tem efeito nenhum (§15/T13).
		begin_preparation()


## §12/§13/T13: a largada em si é a mesma da Tarefa 12. Ela aceita o NOT_STARTED que
## sempre aceitou (harness e chamada direta) e a PREPARATION do fluxo anunciado, e a
## guarda de estado continua garantindo uma única emissão de invasion_started.
func start_invasion() -> bool:
	if _state != InvasionState.NOT_STARTED and _state != InvasionState.PREPARATION:
		return false
	set_process(false)
	_preparation_time_remaining = 0.0
	for index in INVADER_COUNT:
		# §35: cada invasor tem o próprio State; a única coisa compartilhada é a
		# Definition, que nunca guarda número mutável.
		_create_invader(index, "invader_%03d" % (index + 1),
				_spawn_points[index].global_position)
		_active_invaders += 1
	_connect_core_destroyed()
	_state = InvasionState.ACTIVE
	invasion_started.emit(_invaders.duplicate())
	active_invaders_changed.emit(_active_invaders)
	return true


func _on_invader_died(_defeated: EnemyRuntime) -> void:
	if _state != InvasionState.ACTIVE:
		return
	_active_invaders -= 1
	active_invaders_changed.emit(_active_invaders)
	# §36: vitória só existe com o Núcleo de pé. Derrubar as duas Feras depois de
	# Zero não ressuscita ninguém — e não entrega ganho algum (§41).
	if _active_invaders == 0:
		_state = InvasionState.VICTORY
		# §16/§20/§23/T17: a marca fica no domínio no instante em que a vitória
		# acontece. Uma vez só, porque a linha acima já tirou o ciclo de ACTIVE e
		# qualquer callback redundante que chegar depois morre na guarda do topo deste
		# método. E sem pilha no mapa: o Cristal é um contador do Núcleo, não um item
		# que um Worker precise carregar até o Depósito.
		if _abyssal_crystal != null:
			_abyssal_crystal.add(FIRST_VICTORY_CRYSTAL_REWARD)
		invasion_victory.emit()


## §45/§49/§75/T18: o ciclo de vida volta como dado, não como replay. Nada aqui chama
## `begin_preparation` nem `start_invasion`, e nada emite `invasion_victory` ou
## `invasion_defeat` — são os dois sinais que concedem o Cristal (§51/§54/T18), e
## reemiti-los numa carga daria de novo uma conquista que o arquivo já registra. A
## contagem restaurada sai pelo sinal de número.
##
## §46/§47: PREPARATION volta com o segundo exato do arquivo. Não se reseta para 60 e o
## tempo com o jogo fechado não é simulado.
##
## §49/§50/§81: em ACTIVE renasce só quem estava vivo, e cada Fera recebe
## `start_invasion(core)` porque marchar sobre o Núcleo é o estado da campanha, não uma
## ordem transitória do jogador.
##
## §52: DEFEAT é terminal — sem invasores recriados, sem nova PREPARATION.
##
## §67: os registros são validados por inteiro antes de qualquer mutação. Se um deles não
## fecha, a campanha em curso não é tocada.
func restore_lifecycle(
		value_state: InvasionState,
		remaining: float,
		invader_records: Array) -> bool:
	if value_state < InvasionState.NOT_STARTED or value_state > InvasionState.DEFEAT:
		return false
	if remaining < 0.0:
		return false
	var known_ids: Array[String] = []
	for index in INVADER_COUNT:
		known_ids.append("invader_%03d" % (index + 1))
	var seen_ids: Array[String] = []
	for record in invader_records:
		if not _is_restorable_record(record, known_ids, seen_ids):
			return false
		seen_ids.append(record["invader_id"])
	_clear_invaders()
	_state = value_state
	_active_invaders = 0
	_preparation_time_remaining = remaining if value_state == InvasionState.PREPARATION else 0.0
	_displayed_second = _displayed_second_of(_preparation_time_remaining)
	set_process(value_state == InvasionState.PREPARATION)
	if value_state == InvasionState.PREPARATION:
		preparation_started.emit(preparation_duration)
		preparation_time_changed.emit(_preparation_time_remaining, preparation_duration)
		return true
	if value_state != InvasionState.ACTIVE:
		return true
	for record in invader_records:
		_spawn_restored_invader(record)
		_active_invaders += 1
	_connect_core_destroyed()
	active_invaders_changed.emit(_active_invaders)
	return true


## §50/T18: um registro só é restaurável se a identidade é canônica, se ela não se repete
## e se a vida está na faixa de um invasor vivo. O `enemy_id` é lido do arquivo e resolve
## a Definition canônica daqui — não existe `load()` de caminho vindo do Save (§16/§71).
func _is_restorable_record(record: Variant, known_ids: Array[String], seen_ids: Array[String]) -> bool:
	if not (record is Dictionary):
		return false
	var invader_id := String(record.get("invader_id", ""))
	if not known_ids.has(invader_id) or seen_ids.has(invader_id):
		return false
	var health := float(record.get("health", -1.0))
	if health <= 0.0 or health > _definition.max_health:
		return false
	return record.get("position") is Vector3


func _spawn_restored_invader(record: Dictionary) -> void:
	var invader_id := String(record["invader_id"])
	var enemy := _create_invader(known_invader_index(invader_id), invader_id,
			record["position"])
	enemy.state.restore_health(float(record["health"]))


## §32/§92/T12 + §49/T18: um único ponto de criação de criatura no ciclo inteiro. A largada
## e a carga passam por aqui justamente para que restaurar uma campanha não invente uma
## segunda maneira de nascer Fera — nome do Node, State próprio, posição, escuta da morte,
## ordem de marcha e registro no exército são sempre os mesmos cinco passos.
func _create_invader(index: int, invader_id: String, position: Vector3) -> EnemyRuntime:
	var enemy := _scene.instantiate() as EnemyRuntime
	enemy.name = "Invader%03d" % (index + 1)
	enemy.setup(_definition, EnemyState.new(_definition, invader_id))
	_dungeon_root.add_child(enemy)
	enemy.global_position = position
	enemy.enemy_died.connect(_on_invader_died)
	_invaders.append(enemy)
	# §42: o alvo estratégico é entregue por referência direta.
	enemy.start_invasion(_core)
	return enemy


## §14/T18: a posição canônica de um registro não decide o nome do Node — quem deriva o
## índice é o id semântico, que é a identidade estável do Save.
func known_invader_index(invader_id: String) -> int:
	return invader_id.substr("invader_".length()).to_int() - 1


func _clear_invaders() -> void:
	for enemy in _invaders:
		if is_instance_valid(enemy):
			enemy.stand_down()
			enemy.queue_free()
	_invaders.clear()


## §132/T18: `destroyed` é conexão de carga, não de largada — num load repetido o mesmo
## CoreState continuaria vivo e o connection duplicada falharia. O guardado é a forma
## honesta de dizer "quem detém o ciclo já escuta a morte do Núcleo".
func _connect_core_destroyed() -> void:
	var destroyed := _core.core_state().destroyed
	if not destroyed.is_connected(_on_core_destroyed):
		destroyed.connect(_on_core_destroyed)


func _on_core_destroyed() -> void:
	if _state != InvasionState.ACTIVE:
		return
	_state = InvasionState.DEFEAT
	for enemy in _invaders:
		if is_instance_valid(enemy):
			enemy.stand_down()
	# §23: o Núcleo não sai da árvore — apenas o estado mudaria isso, e ele é do
	# CoreState, não daqui.
	invasion_defeat.emit()


## §11/T13: o segundo que o HUD vai mostrar. ceil() é a política que faz 59.9 s ainda
## aparecerem como 60 e garante que o "0" nunca fica na tela antes do ataque.
func _displayed_second_of(remaining: float) -> int:
	return int(ceilf(remaining))
