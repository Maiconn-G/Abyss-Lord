class_name SurfaceIncursionController
extends Node

## Tarefa 23 — a primeira Incursão da Superfície (GDD §58.1). É a segunda origem de
## invasão do jogo: não criaturas do fundo atraídas pelo Núcleo, mas uma guilda humana que
## entra para saquear e recuar.
##
## Por que um controller próprio e não um segundo modo do InvasionController: a primeira
## invasão é a regra histórica do MVP (duas Feras, vitória, Cristal, derrota pelo Núcleo) e
## o Save V1–V4 a descreve exatamente assim. A incursão tem outro gatilho (Notoriedade),
## outro objetivo (o Depósito, não o Núcleo), outro desfecho (fuga com saque, sem derrota e
## sem Cristal). Os dois controllers não se conhecem e não viraram "sistema de ondas".
##
## O que este controller é dono:
## * da Notoriedade da campanha — quem soma cada fato é ele, e os números moram aqui;
## * do ciclo NOT_STARTED → PREPARATION → ACTIVE → ENDED da primeira incursão;
## * dos dois Saqueadores de Guilda e do destino do saque deles.

enum IncursionState { NOT_STARTED, PREPARATION, ACTIVE, ENDED }

const RAIDER_COUNT := 2
## A superfície nota o Núcleo quando a Notoriedade chega aqui (GDD §58.1).
const NOTORIETY_THRESHOLD := 20
## Os fatos que a Tarefa 23 transforma em Notoriedade. São poucos e são desta tarefa; o
## dia em que houver uma tabela de fatos, eles viram dado — antes disso seriam infra para
## três números.
const NOTORIETY_CORE_LEVEL_TWO := 20
const NOTORIETY_RAIDER_SLAIN := 5
const NOTORIETY_RAIDER_ESCAPED := 10
const RAIDER_ID_PREFIX := "raider_"

## Os 120 s de aviso são o valor de produção; o harness encurta esta mesma variável.
@export var preparation_duration: float = 120.0

signal preparation_started(duration: float)
signal preparation_time_changed(remaining: float, duration: float)
signal incursion_started(raiders: Array)
signal active_raiders_changed(current: int)
signal incursion_ended(repelled: int, escaped: int)

var _definition: RaiderDefinition
var _scene: PackedScene
var _dungeon_root: Node3D
var _stockpile: ResourceStockpileState
var _deposit: Node3D
var _entrances: Array[Node3D] = []
var _notoriety: NotorietyState
var _core_state: CoreState
var _resources_by_id: Dictionary = {}

var _state: IncursionState = IncursionState.NOT_STARTED
var _raiders: Array[RaiderRuntime] = []
var _preparation_time_remaining := 0.0
var _displayed_second := 0
var _repelled := 0
var _escaped := 0
var _restoring := false


func _ready() -> void:
	set_process(false)


## Tudo por injeção na raiz de composição. Nenhum lookup, nenhum grupo varrido.
func setup(
		definition: RaiderDefinition,
		raider_scene: PackedScene,
		dungeon_root: Node3D,
		stockpile: ResourceStockpileState,
		deposit: Node3D,
		entrances: Array,
		notoriety: NotorietyState,
		core_state: CoreState) -> void:
	_definition = definition
	_scene = raider_scene
	_dungeon_root = dungeon_root
	_stockpile = stockpile
	_deposit = deposit
	_entrances.assign(entrances)
	_notoriety = notoriety
	_core_state = core_state
	_resources_by_id.clear()
	for resource in definition.loot_priority:
		if resource != null:
			_resources_by_id[resource.resource_id] = resource
	notoriety.notoriety_changed.connect(_on_notoriety_changed)
	core_state.evolved.connect(_on_core_evolved)


func incursion_state() -> IncursionState:
	return _state


func notoriety() -> NotorietyState:
	return _notoriety


func raider_definition() -> RaiderDefinition:
	return _definition


func raiders() -> Array[RaiderRuntime]:
	return _raiders


func active_raiders() -> int:
	return _raiders.size()


func preparation_time_remaining() -> float:
	return _preparation_time_remaining


func repelled_count() -> int:
	return _repelled


func escaped_count() -> int:
	return _escaped


## O Núcleo Nv.2 é o primeiro fato que a superfície percebe. `evolved` só é emitido pela
## evolução real — a carga restaura o nível sem esse sinal —, então a Notoriedade nunca é
## somada duas vezes pelo mesmo marco.
func _on_core_evolved(old_level: int, new_level: int) -> void:
	if old_level < 2 and new_level >= 2:
		_notoriety.add(NOTORIETY_CORE_LEVEL_TWO)


func _on_notoriety_changed(_current: int, _maximum: int) -> void:
	if _restoring:
		return
	_evaluate_trigger()


## A única porta da preparação é a Notoriedade no limiar, com a incursão ainda por vir.
func _evaluate_trigger() -> void:
	if _state == IncursionState.NOT_STARTED and _notoriety.value >= NOTORIETY_THRESHOLD:
		begin_preparation()


func begin_preparation() -> bool:
	if _state != IncursionState.NOT_STARTED:
		return false
	_state = IncursionState.PREPARATION
	_preparation_time_remaining = preparation_duration
	_displayed_second = _displayed_second_of(_preparation_time_remaining)
	preparation_started.emit(preparation_duration)
	preparation_time_changed.emit(_preparation_time_remaining, preparation_duration)
	set_process(true)
	return true


## Contagem por delta, nunca por Timer — igual para 30 Hz e 120 Hz.
func _process(delta: float) -> void:
	if _state != IncursionState.PREPARATION:
		set_process(false)
		return
	_preparation_time_remaining = maxf(_preparation_time_remaining - delta, 0.0)
	var second := _displayed_second_of(_preparation_time_remaining)
	if second != _displayed_second:
		_displayed_second = second
		preparation_time_changed.emit(_preparation_time_remaining, preparation_duration)
	if _preparation_time_remaining <= 0.0:
		start_incursion()


## A largada aceita PREPARATION (o fluxo normal) e NOT_STARTED (harness), e só uma vez.
func start_incursion() -> bool:
	if _state != IncursionState.NOT_STARTED and _state != IncursionState.PREPARATION:
		return false
	set_process(false)
	_preparation_time_remaining = 0.0
	for index in RAIDER_COUNT:
		var raider := _create_raider(index, raider_id_of(index), _entrance_of(index))
		raider.begin_raid()
	_state = IncursionState.ACTIVE
	incursion_started.emit(_raiders.duplicate())
	active_raiders_changed.emit(_raiders.size())
	return true


static func raider_id_of(index: int) -> String:
	return RAIDER_ID_PREFIX + "%03d" % (index + 1)


static func raider_index_of(raider_id: String) -> int:
	return raider_id.substr(RAIDER_ID_PREFIX.length()).to_int() - 1


## Um único ponto de criação de saqueador: a largada e a carga passam por aqui.
func _create_raider(index: int, raider_id: String, position: Vector3) -> RaiderRuntime:
	var raider := _scene.instantiate() as RaiderRuntime
	raider.name = "Raider%03d" % (index + 1)
	raider.setup(_definition, RaiderState.new(_definition, raider_id))
	_dungeon_root.add_child(raider)
	raider.global_position = position
	raider.bind_raid(_stockpile, _deposit.global_position, _entrance_of(index))
	raider.enemy_died.connect(_on_raider_slain)
	raider.raider_escaped.connect(_on_raider_escaped)
	_raiders.append(raider)
	return raider


func _entrance_of(index: int) -> Vector3:
	return _entrances[index % _entrances.size()].global_position


## Morto no domínio: o saque que ele carregava volta ao estoque — o Depósito recupera o que
## o cadáver tinha nos bolsos. A superfície fica sabendo de uma guilda que não voltou.
func _on_raider_slain(enemy: EnemyRuntime) -> void:
	var raider := enemy as RaiderRuntime
	if raider == null or not _raiders.has(raider):
		return
	var loot := raider.raider_state().drop_loot()
	for resource_id in loot:
		var resource := _resources_by_id.get(StringName(resource_id)) as ResourceDefinition
		if resource != null:
			_stockpile.add_resource(resource, int(loot[resource_id]))
	_raiders.erase(raider)
	_repelled += 1
	_notoriety.add(NOTORIETY_RAIDER_SLAIN)
	_after_raider_left()


## Fugiu para a superfície: o saque está perdido — saiu do estoque no momento do roubo e não
## volta. Quem escapa conta o que viu, e a Notoriedade sobe mais do que por uma morte.
func _on_raider_escaped(raider: RaiderRuntime) -> void:
	if not _raiders.has(raider):
		return
	_raiders.erase(raider)
	_escaped += 1
	_notoriety.add(NOTORIETY_RAIDER_ESCAPED)
	_after_raider_left()


func _after_raider_left() -> void:
	active_raiders_changed.emit(_raiders.size())
	if _state == IncursionState.ACTIVE and _raiders.is_empty():
		_state = IncursionState.ENDED
		incursion_ended.emit(_repelled, _escaped)


## O ciclo volta como dado, não como replay: nenhum sinal de largada ou de desfecho é
## reemitido, nenhum saque é cobrado de novo e a Notoriedade volta exatamente como estava.
## Registros são validados por inteiro antes de qualquer mutação.
##
## Uma campanha carregada em NOT_STARTED com a Notoriedade já no limiar (o caso de um save
## V4 migrado no Nv.2) abre a preparação ao fim da carga: é a mesma regra viva do gatilho, e
## não um evento inventado.
func restore_surface(
		notoriety_value: int,
		value_state: IncursionState,
		remaining: float,
		raider_records: Array,
		repelled: int,
		escaped: int) -> bool:
	if value_state < IncursionState.NOT_STARTED or value_state > IncursionState.ENDED:
		return false
	if remaining < 0.0 or repelled < 0 or escaped < 0:
		return false
	if notoriety_value < 0 or notoriety_value > NotorietyState.MAXIMUM:
		return false
	var seen: Array[String] = []
	for record in raider_records:
		if not _is_restorable_record(record, seen):
			return false
		seen.append(String(record["raider_id"]))
	_restoring = true
	_clear_raiders()
	_notoriety.restore(notoriety_value)
	_state = value_state
	_repelled = repelled
	_escaped = escaped
	_preparation_time_remaining = remaining if value_state == IncursionState.PREPARATION else 0.0
	_displayed_second = _displayed_second_of(_preparation_time_remaining)
	set_process(value_state == IncursionState.PREPARATION)
	if value_state == IncursionState.ACTIVE:
		for record in raider_records:
			_spawn_restored_raider(record)
	_restoring = false
	if value_state == IncursionState.PREPARATION:
		preparation_started.emit(preparation_duration)
		preparation_time_changed.emit(_preparation_time_remaining, preparation_duration)
	active_raiders_changed.emit(_raiders.size())
	_evaluate_trigger()
	return true


func _is_restorable_record(record: Variant, seen: Array[String]) -> bool:
	if not (record is Dictionary):
		return false
	var raider_id := String(record.get("raider_id", ""))
	var index := raider_index_of(raider_id) if raider_id.begins_with(RAIDER_ID_PREFIX) else -1
	if index < 0 or index >= RAIDER_COUNT or raider_id != raider_id_of(index):
		return false
	if seen.has(raider_id):
		return false
	var health := float(record.get("health", -1.0))
	if health <= 0.0 or health > _definition.max_health:
		return false
	var phase := int(record.get("phase", -1))
	if phase < RaiderState.Phase.APPROACH or phase > RaiderState.Phase.RETREAT:
		return false
	var loot: Variant = record.get("loot")
	if not (loot is Dictionary):
		return false
	var total := 0
	for resource_id in loot:
		if not _resources_by_id.has(StringName(resource_id)) or int(loot[resource_id]) <= 0:
			return false
		total += int(loot[resource_id])
	if total > _definition.loot_capacity:
		return false
	return record.get("position") is Vector3


func _spawn_restored_raider(record: Dictionary) -> void:
	var raider_id := String(record["raider_id"])
	var raider := _create_raider(raider_index_of(raider_id), raider_id, record["position"])
	raider.state.restore_health(float(record["health"]))
	raider.raider_state().restore_raid(int(record["phase"]), record["loot"] as Dictionary)
	raider.begin_raid()


func _clear_raiders() -> void:
	for raider in _raiders:
		if is_instance_valid(raider):
			raider.stand_down()
			raider.queue_free()
	_raiders.clear()


func _displayed_second_of(remaining: float) -> int:
	return int(ceilf(remaining))
