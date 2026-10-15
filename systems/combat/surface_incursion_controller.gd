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
## * do ciclo NOT_STARTED → PREPARATION → ACTIVE → ENDED das incursões;
## * dos Saqueadores de Guilda e do destino do saque deles.
##
## T25: a superfície não esquece. Depois de cada incursão vem uma calmaria (ENDED com relógio),
## e ao fim dela a próxima guilda começa a preparação. O tamanho da guilda é lido da
## Notoriedade no instante da largada: quanto mais a superfície sabe, maior o grupo.

enum IncursionState { NOT_STARTED, PREPARATION, ACTIVE, ENDED }

## T25: a guilda cresce com a Notoriedade, de 2 a 5 saqueadores (ver `guild_size_for`).
const FIRST_GUILD_SIZE := 2
const MAX_GUILD_SIZE := 5
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
## T25: a calmaria entre uma incursão e a preparação da próxima.
@export var cooldown_duration: float = 90.0

signal preparation_started(duration: float)
signal preparation_time_changed(remaining: float, duration: float)
signal incursion_started(raiders: Array)
signal active_raiders_changed(current: int)
signal incursion_ended(repelled: int, escaped: int)
## T24: o desfecho de cada saqueador, para quem observa a superfície de fora (a Guarda
## Decapitada mede o mérito do Regente por eles). Emitidos também por saqueadores restaurados.
signal raider_repelled(raider: RaiderRuntime)
signal raider_fled(raider: RaiderRuntime)
## T25: o relógio da calmaria, um emit por segundo de tela.
signal cooldown_time_changed(remaining: float, duration: float)

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
## T25: quantas incursões já foram largadas, o tamanho da atual (ou da última) e quanto falta
## de calmaria. Os três são estado e vão para o Save.
var _incursion_number := 0
var _guild_size := 0
var _cooldown_remaining := 0.0


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


func incursion_number() -> int:
	return _incursion_number


func guild_size() -> int:
	return _guild_size


func cooldown_remaining() -> float:
	return _cooldown_remaining


## T25: o tamanho da guilda pela faixa de Notoriedade (GDD §13): até 40 vêm 2, até 60 vêm 3,
## até 80 vêm 4, e uma potência notada pela superfície recebe 5.
static func guild_size_for(notoriety_value: int) -> int:
	if notoriety_value <= 40:
		return FIRST_GUILD_SIZE
	if notoriety_value <= 60:
		return 3
	if notoriety_value <= 80:
		return 4
	return MAX_GUILD_SIZE


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


## Contagem por delta, nunca por Timer — igual para 30 Hz e 120 Hz. T25: o mesmo relógio conta
## a calmaria depois de cada incursão; ao fim dela, a próxima guilda começa a preparação.
func _process(delta: float) -> void:
	if _state == IncursionState.ENDED:
		_process_cooldown(delta)
		return
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


func _process_cooldown(delta: float) -> void:
	_cooldown_remaining = maxf(_cooldown_remaining - delta, 0.0)
	var second := _displayed_second_of(_cooldown_remaining)
	if second != _displayed_second:
		_displayed_second = second
		cooldown_time_changed.emit(_cooldown_remaining, cooldown_duration)
	if _cooldown_remaining <= 0.0:
		_state = IncursionState.NOT_STARTED
		begin_preparation()


## A largada aceita PREPARATION (o fluxo normal) e NOT_STARTED (harness). T25: cada largada é
## uma incursão nova — o número sobe, o tamanho da guilda é lido da Notoriedade agora e o
## desfecho da anterior é zerado.
func start_incursion() -> bool:
	if _state != IncursionState.NOT_STARTED and _state != IncursionState.PREPARATION:
		return false
	set_process(false)
	_preparation_time_remaining = 0.0
	_incursion_number += 1
	_guild_size = guild_size_for(_notoriety.value)
	_repelled = 0
	_escaped = 0
	for index in _guild_size:
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
	raider_repelled.emit(raider)
	_after_raider_left()


## Fugiu para a superfície: o saque está perdido — saiu do estoque no momento do roubo e não
## volta. Quem escapa conta o que viu, e a Notoriedade sobe mais do que por uma morte.
func _on_raider_escaped(raider: RaiderRuntime) -> void:
	if not _raiders.has(raider):
		return
	_raiders.erase(raider)
	_escaped += 1
	_notoriety.add(NOTORIETY_RAIDER_ESCAPED)
	raider_fled.emit(raider)
	_after_raider_left()


func _after_raider_left() -> void:
	active_raiders_changed.emit(_raiders.size())
	if _state == IncursionState.ACTIVE and _raiders.is_empty():
		_state = IncursionState.ENDED
		_cooldown_remaining = cooldown_duration
		_displayed_second = _displayed_second_of(_cooldown_remaining)
		set_process(true)
		incursion_ended.emit(_repelled, _escaped)
		cooldown_time_changed.emit(_cooldown_remaining, cooldown_duration)


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
		escaped: int,
		number := 0,
		size := 0,
		cooldown := 0.0) -> bool:
	if value_state < IncursionState.NOT_STARTED or value_state > IncursionState.ENDED:
		return false
	if remaining < 0.0 or repelled < 0 or escaped < 0:
		return false
	if number < 0 or size < 0 or size > MAX_GUILD_SIZE or cooldown < 0.0:
		return false
	if notoriety_value < 0 or notoriety_value > NotorietyState.MAXIMUM:
		return false
	var seen: Array[String] = []
	for record in raider_records:
		if not _is_restorable_record(record, seen, size):
			return false
		seen.append(String(record["raider_id"]))
	_restoring = true
	_clear_raiders()
	_guild_size = size
	_notoriety.restore(notoriety_value)
	_state = value_state
	_repelled = repelled
	_escaped = escaped
	_incursion_number = number
	_cooldown_remaining = cooldown if value_state == IncursionState.ENDED else 0.0
	_preparation_time_remaining = remaining if value_state == IncursionState.PREPARATION else 0.0
	_displayed_second = _displayed_second_of(
			_cooldown_remaining if value_state == IncursionState.ENDED
			else _preparation_time_remaining)
	set_process(value_state == IncursionState.PREPARATION or value_state == IncursionState.ENDED)
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


func _is_restorable_record(record: Variant, seen: Array[String], size: int) -> bool:
	if not (record is Dictionary):
		return false
	var raider_id := String(record.get("raider_id", ""))
	var index := raider_index_of(raider_id) if raider_id.begins_with(RAIDER_ID_PREFIX) else -1
	if index < 0 or index >= size or raider_id != raider_id_of(index):
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
