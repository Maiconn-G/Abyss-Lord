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
		var enemy := _scene.instantiate() as EnemyRuntime
		enemy.name = "Invader%03d" % (index + 1)
		# §35: cada invasor tem o próprio State; a única coisa compartilhada é a
		# Definition, que nunca guarda número mutável.
		enemy.setup(_definition, EnemyState.new(_definition, "invader_%03d" % (index + 1)))
		_dungeon_root.add_child(enemy)
		enemy.global_position = _spawn_points[index].global_position
		enemy.enemy_died.connect(_on_invader_died)
		_invaders.append(enemy)
		_active_invaders += 1
		# §42: o alvo estratégico é entregue por referência direta.
		enemy.start_invasion(_core)
	_core.core_state().destroyed.connect(_on_core_destroyed)
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
