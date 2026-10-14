class_name WorkerExpansionController
extends Node

## Tarefa 22 — a primeira expansão populacional por Biomassa. Depois do Nv.2, o Núcleo
## aprende a dar corpo a um servo com a matéria viva que a Fazenda Fúngica produz: o terceiro
## Trabalhador custa Biomassa (corpo) e Essência (alma).
##
## Por que um controller próprio e não mais um caminho no WorkerInvocationController: a
## invocação do segundo Worker é a regra histórica do MVP (D1 — "1 inicial + 1 invocável"),
## guardada por uma flag que o Save já conhece. A expansão é progressão pós-Nv.2 com outra
## porta (nível do Núcleo) e outro preço (Biomassa no estoque genérico). Misturar as duas
## num controller só exigiria um branch por unidade dentro dele. Os dois controllers não
## se conhecem, não compartilham roster e não viram "sistema de população".
##
## O que este controller NÃO é: fila de invocação, roster, spawner genérico ou receita
## configurável de N unidades. Ele invoca exatamente uma unidade — worker_003 — uma vez.

## A identidade semântica do terceiro Worker. É contrato do Save, exatamente como o
## SUMMONED_UNIT_ID do segundo.
const EXPANSION_UNIT_ID := "worker_003"

## As portas, na ordem em que são conferidas. O painel lê a primeira que está fechada.
enum Gate { READY, ALREADY_SUMMONED, CORE_LEVEL, CAPACITY, BIOMASS, ESSENCE }

signal worker_expanded(worker: WorkerRuntime)

var _core_state: CoreState
var _stockpile: ResourceStockpileState
var _worker_definition: WorkerDefinition
var _expansion: WorkerExpansionDefinition
var _scene: PackedScene
var _dungeon_root: Node3D
var _spawn_point: Node3D
var _deposit: ResourceDepositRuntime
var _expanded_worker: WorkerRuntime

## A regra "um terceiro Worker, uma vez" é histórica: um worker_003 invocado e morto
## continua tendo existido. Como no segundo Worker, a flag — e não a existência do Node —
## é a guarda da invocação, e é ela que o Save grava.
var _worker_003_summoned := false


## Tudo por injeção, na raiz de composição. Nada é procurado na árvore.
func setup(
		core_state: CoreState,
		stockpile: ResourceStockpileState,
		worker_definition: WorkerDefinition,
		expansion_definition: WorkerExpansionDefinition,
		worker_scene: PackedScene,
		dungeon_root: Node3D,
		spawn_point: Node3D) -> void:
	_core_state = core_state
	_stockpile = stockpile
	_worker_definition = worker_definition
	_expansion = expansion_definition
	_scene = worker_scene
	_dungeon_root = dungeon_root
	_spawn_point = spawn_point


func bind_delivery_deposit(deposit: ResourceDepositRuntime) -> void:
	_deposit = deposit


func expansion_definition() -> WorkerExpansionDefinition:
	return _expansion


func expanded_worker() -> WorkerRuntime:
	return _expanded_worker


func worker_ever_expanded() -> bool:
	return _worker_003_summoned


## A primeira porta fechada, na ordem de conferência. READY quando todas estão abertas.
## É a mesma sequência que `summon_expansion_worker()` exige — o painel não tem regra
## própria, só lê esta.
func gate() -> Gate:
	if _worker_003_summoned:
		return Gate.ALREADY_SUMMONED
	if _core_state.level < _expansion.required_core_level:
		return Gate.CORE_LEVEL
	if not _core_state.can_add_population(1):
		return Gate.CAPACITY
	if _stockpile.get_amount(_expansion.biomass_resource.resource_id) < _expansion.biomass_cost:
		return Gate.BIOMASS
	if _core_state.essence < _expansion.essence_cost:
		return Gate.ESSENCE
	return Gate.READY


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("summon_expansion_worker"):
		summon_expansion_worker()


## A transação inteira é validada antes de qualquer escrita: todas as portas de `gate()`
## espelham exatamente as guardas de `consume_resource`, `consume_essence` e
## `try_add_population`, então nenhum dos três passos de cobrança pode falhar no meio e
## deixar a campanha com Biomassa paga e sem servo.
func summon_expansion_worker() -> bool:
	if gate() != Gate.READY:
		return false
	var worker := _scene.instantiate() as WorkerRuntime
	worker.setup(_worker_definition, WorkerState.new(_worker_definition, EXPANSION_UNIT_ID))
	worker.set_resource_deposit(_deposit)
	_stockpile.consume_resource(_expansion.biomass_resource, _expansion.biomass_cost)
	_core_state.consume_essence(_expansion.essence_cost)
	_core_state.try_add_population(1)
	_dungeon_root.add_child(worker)
	worker.global_position = _spawn_point.global_position
	_expanded_worker = worker
	_worker_003_summoned = true
	worker_expanded.emit(worker)
	return true


## A flag histórica volta exatamente como o arquivo a escreveu, sem dedução.
func restore_expansion_history(ever_summoned: bool) -> void:
	_worker_003_summoned = ever_summoned


## O terceiro Worker que o arquivo descreve é montado, não invocado: nenhuma Biomassa nem
## Essência é cobrada (quem pagou foi a partida salva), nenhuma população é somada (o número
## volta pelo CoreState) e nenhum `worker_expanded` é emitido. Load repetido encontra o
## Runtime da carga anterior e ajusta os números dele em vez de criar um quarto Worker.
func restore_expanded_worker(
		value_health: float,
		value_level: int,
		value_experience: float,
		cargo_definition: ResourceDefinition,
		cargo_amount: int,
		unit_position: Vector3) -> bool:
	if is_instance_valid(_expanded_worker) and not _expanded_worker.is_queued_for_deletion():
		if not _expanded_worker.state.restore_persistent_state(
				value_health, value_level, value_experience,
				cargo_definition, cargo_amount):
			return false
		_expanded_worker.global_position = unit_position
		_expanded_worker.reset_transient_order()
		return true
	var state := WorkerState.new(_worker_definition, EXPANSION_UNIT_ID)
	if not state.restore_persistent_state(
			value_health, value_level, value_experience, cargo_definition, cargo_amount):
		return false
	var worker := _scene.instantiate() as WorkerRuntime
	worker.setup(_worker_definition, state)
	worker.set_resource_deposit(_deposit)
	_dungeon_root.add_child(worker)
	worker.global_position = unit_position
	worker.reset_transient_order()
	_expanded_worker = worker
	return true


## Um Save sem terceiro Worker liberta o Runtime sem emitir nada.
func remove_expanded_worker() -> void:
	if _expanded_worker != null and is_instance_valid(_expanded_worker):
		_expanded_worker.reset_transient_order()
		_expanded_worker.queue_free()
	_expanded_worker = null
