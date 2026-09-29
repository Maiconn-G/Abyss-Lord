class_name WorkerInvocationController
extends Node

const SUMMONED_UNIT_ID := "worker_002"

signal worker_summoned(worker: WorkerRuntime)

var _core_state: CoreState
var _definition: WorkerDefinition
var _scene: PackedScene
var _dungeon_root: Node3D
var _spawn_point: Node3D
var _deposit: ResourceDepositRuntime
var _summoned_worker: WorkerRuntime

## §26/T18: a regra de "um segundo Worker, uma vez" é histórica, e o Runtime sozinho não
## a registra — se amanhã a unidade puder deixar de existir, a existência do Node deixaria
## de ser prova. O Save grava esta flag, e ela passa a ser a guarda da invocação.
var _worker_002_summoned := false


func setup(
		core_state: CoreState,
		worker_definition: WorkerDefinition,
		worker_scene: PackedScene,
		dungeon_root: Node3D,
		spawn_point: Node3D) -> void:
	_core_state = core_state
	_definition = worker_definition
	_scene = worker_scene
	_dungeon_root = dungeon_root
	_spawn_point = spawn_point


func bind_delivery_deposit(deposit: ResourceDepositRuntime) -> void:
	_deposit = deposit


func summoned_worker() -> WorkerRuntime:
	return _summoned_worker


func worker_ever_summoned() -> bool:
	return _worker_002_summoned


## §26/T18: a flag histórica volta exatamente como o arquivo a escreveu, sem dedução. Um
## Worker002 invocado e morto depois continua `worker_002_summoned = true`, e é isso que
## trava um novo [I] numa campanha carregada — não a existência do Runtime.
func restore_second_worker_history(ever_summoned: bool) -> void:
	_worker_002_summoned = ever_summoned


## §33/§83/§95/T18: o segundo Worker que o arquivo descreve é montado, não invocado. As
## três diferenças em relação a `summon_worker` são exatamente as que §20 e §54 exigem:
## nenhuma Essência é cobrada (quem pagou foi a partida salva), nenhuma população é somada
## (o número volta pelo CoreState, §29), e nenhum `worker_summoned` é emitido — aquele
## sinal anuncia o instante da conquista, e o painel é alinhado pelo refresh da carga.
##
## §95/§100: a rota sincroniza. Load repetido encontra o Runtime da carga anterior e ajusta
## os números dele em vez de criar um terceiro Worker.
func restore_summoned_worker(
		value_health: float,
		value_level: int,
		value_experience: float,
		cargo_definition: ResourceDefinition,
		cargo_amount: int,
		unit_position: Vector3) -> bool:
	if is_instance_valid(_summoned_worker) and not _summoned_worker.is_queued_for_deletion():
		if not _summoned_worker.state.restore_persistent_state(
				value_health, value_level, value_experience,
				cargo_definition, cargo_amount):
			return false
		_summoned_worker.global_position = unit_position
		_summoned_worker.reset_transient_order()
		return true
	var state := WorkerState.new(_definition, SUMMONED_UNIT_ID)
	if not state.restore_persistent_state(
			value_health, value_level, value_experience, cargo_definition, cargo_amount):
		return false
	var worker := _scene.instantiate() as WorkerRuntime
	worker.setup(_definition, state)
	worker.set_resource_deposit(_deposit)
	_dungeon_root.add_child(worker)
	worker.global_position = unit_position
	worker.reset_transient_order()
	_summoned_worker = worker
	return true


## §95/T18: um Save anterior à invocação não tem segundo Worker. Libertar o Runtime sem
## emitir nada é o que impede a UI de celebrar uma conquista que a campanha carregada
## nunca teve; Population e Essência voltam pelos números do CoreState.
func remove_summoned_worker() -> void:
	if _summoned_worker != null and is_instance_valid(_summoned_worker):
		_summoned_worker.reset_transient_order()
		_summoned_worker.queue_free()
	_summoned_worker = null


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("summon_worker"):
		summon_worker()


func summon_worker() -> bool:
	if _worker_002_summoned:
		return false
	if not _core_state.can_add_population(1):
		return false
	if _core_state.essence < _definition.summon_essence_cost:
		return false

	var worker := _scene.instantiate() as WorkerRuntime
	worker.setup(_definition, WorkerState.new(_definition, SUMMONED_UNIT_ID))
	worker.set_resource_deposit(_deposit)
	# A validação acima espelha exatamente as guardas de consume_essence() e
	# can_add_population(), então nenhum destes dois passos pode falhar aqui.
	_core_state.consume_essence(_definition.summon_essence_cost)
	_core_state.try_add_population(1)
	_dungeon_root.add_child(worker)
	worker.global_position = _spawn_point.global_position
	_summoned_worker = worker
	_worker_002_summoned = true
	worker_summoned.emit(worker)
	return true
