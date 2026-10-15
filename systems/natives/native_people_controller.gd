class_name NativePeopleController
extends Node

## Tarefa 24 — o primeiro Povo Nativo: a Guarda Decapitada (GDD §51.1). O domínio herdado
## não estava vazio; atrás do Selo Antigo sobreviveu a guarda do antigo Regente, e ela não
## aceita automaticamente um humano no trono.
##
## Este controller é dono de tudo que é desse povo:
## * do Selo Antigo — desperta com o Núcleo Nv.2 e é rompido por Trabalhadores, como obra;
## * da Legitimidade da Guarda e dos atos que a movem (pedidos cumpridos, saqueadores
##   mortos ou fugidos, o Guardião caído);
## * dos pedidos, em ordem, e do juramento que o povo presta ao chegar em "leal";
## * do Guardião Decapitado que o juramento entrega.
##
## O que ele NÃO é: sistema genérico de facções, de diplomacia ou de reputação. É um povo,
## com regras escritas para ele. O segundo povo é o dia de discutir o que é comum.

const SEAL_ID := "ancient_seal_001"
const GUARDIAN_ID := "guardian_001"

enum RequestGate { NOT_DISCOVERED, ALL_FULFILLED, INSUFFICIENT, READY }

signal seal_awakened(seal: AncientSealRuntime)
signal people_discovered
signal request_fulfilled(index: int)
signal oath_sworn(guardian: SoldierRuntime)
signal guardian_fallen

var _core_state: CoreState
var _stockpile: ResourceStockpileState
var _definition: NativePeopleDefinition
var _seal_scene: PackedScene
var _guardian_scene: PackedScene
var _dungeon_root: Node3D
var _seal_point: Node3D
var _guardian_point: Node3D
var _legitimacy := LegitimacyState.new()

var _seal: AncientSealRuntime
var _guardian: SoldierRuntime
var _discovered := false
var _requests_fulfilled := 0
var _oath_sworn := false
var _restoring := false


## Tudo por injeção, na raiz de composição.
func setup(
		core_state: CoreState,
		stockpile: ResourceStockpileState,
		definition: NativePeopleDefinition,
		seal_scene: PackedScene,
		guardian_scene: PackedScene,
		dungeon_root: Node3D,
		seal_point: Node3D,
		guardian_point: Node3D) -> void:
	_core_state = core_state
	_stockpile = stockpile
	_definition = definition
	_seal_scene = seal_scene
	_guardian_scene = guardian_scene
	_dungeon_root = dungeon_root
	_seal_point = seal_point
	_guardian_point = guardian_point
	core_state.evolved.connect(_on_core_evolved)
	_legitimacy.legitimacy_changed.connect(_on_legitimacy_changed)
	if core_state.level >= definition.required_core_level:
		_awaken_seal()


## A Guarda observa a superfície: quem mata saqueador no domínio dela ganha mérito, quem
## deixa saqueador fugir com o saque perde.
func bind_incursion(incursion: SurfaceIncursionController) -> void:
	incursion.raider_repelled.connect(_on_raider_repelled)
	incursion.raider_fled.connect(_on_raider_fled)


func definition() -> NativePeopleDefinition:
	return _definition


func legitimacy() -> LegitimacyState:
	return _legitimacy


func seal() -> AncientSealRuntime:
	return _seal


func guardian() -> SoldierRuntime:
	return _guardian


func is_discovered() -> bool:
	return _discovered


func requests_fulfilled() -> int:
	return _requests_fulfilled


func has_sworn_oath() -> bool:
	return _oath_sworn


## Quanto do selo já foi rompido (0 sem selo). É o número que o Save grava.
func seal_work_done() -> float:
	if _seal == null or not is_instance_valid(_seal):
		return 0.0
	return _definition.seal_definition.work_required - _seal.state.remaining_work


# ============================================================== o selo e a descoberta


func _on_core_evolved(_old_level: int, new_level: int) -> void:
	if new_level >= _definition.required_core_level:
		_awaken_seal()


func _awaken_seal() -> void:
	if _seal != null and is_instance_valid(_seal):
		return
	_seal = _seal_scene.instantiate() as AncientSealRuntime
	_seal.name = "AncientSeal001"
	_dungeon_root.add_child(_seal)
	_seal.global_position = _seal_point.global_position
	_seal.setup(_definition.seal_definition,
			ConstructionState.new(_definition.seal_definition, SEAL_ID))
	_seal.state.construction_completed.connect(_on_seal_broken)
	if not _restoring:
		seal_awakened.emit(_seal)


## Rompido o selo, a Guarda está diante do novo Regente. A desconfiança inicial vem da
## Definition; nada de juramento ainda.
func _on_seal_broken() -> void:
	if _discovered or _restoring:
		return
	_discovered = true
	people_discovered.emit()
	_legitimacy.add(_definition.starting_legitimacy)


# ================================================================== os pedidos


func current_request() -> NativeRequestDefinition:
	if not _discovered or _requests_fulfilled >= _definition.requests.size():
		return null
	return _definition.requests[_requests_fulfilled]


func request_gate() -> RequestGate:
	if not _discovered:
		return RequestGate.NOT_DISCOVERED
	var request := current_request()
	if request == null:
		return RequestGate.ALL_FULFILLED
	if _stockpile.get_amount(request.resource.resource_id) < request.amount:
		return RequestGate.INSUFFICIENT
	return RequestGate.READY


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("fulfill_native_request"):
		fulfill_request()


## A entrega é atômica: a porta espelha a guarda de `consume_resource`, e só então a
## Legitimidade sobe e o pedido seguinte se abre.
func fulfill_request() -> bool:
	if request_gate() != RequestGate.READY:
		return false
	var request := current_request()
	_stockpile.consume_resource(request.resource, request.amount)
	var index := _requests_fulfilled
	_requests_fulfilled += 1
	request_fulfilled.emit(index)
	_legitimacy.add(request.legitimacy_gain)
	return true


# ============================================================ mérito e juramento


func _on_raider_repelled(_raider: RaiderRuntime) -> void:
	if _discovered:
		_legitimacy.add(_definition.legitimacy_per_raider_slain)


func _on_raider_fled(_raider: RaiderRuntime) -> void:
	if _discovered:
		_legitimacy.remove(_definition.legitimacy_per_raider_fled)


## Cruzar o limiar presta o juramento, uma vez. O juramento é histórico: se a Legitimidade
## cair depois, ele continua prestado — o que o povo retira é a confiança, não a palavra.
func _on_legitimacy_changed(current: int, _maximum: int) -> void:
	if _restoring or not _discovered or _oath_sworn:
		return
	if current >= _definition.oath_threshold:
		_swear_oath()


func _swear_oath() -> void:
	_oath_sworn = true
	var guardian := _spawn_guardian(_guardian_point.global_position)
	oath_sworn.emit(guardian)


## O Guardião é um Soldado de verdade — selecionável, comandável, atacável —, mas não é
## invocado pelo Núcleo: ele é um súdito da Guarda, e por isso não ocupa população.
func _spawn_guardian(position: Vector3) -> SoldierRuntime:
	var guardian := _guardian_scene.instantiate() as SoldierRuntime
	guardian.name = "DecapitatedGuardian001"
	guardian.setup(_definition.guardian_definition,
			SoldierState.new(_definition.guardian_definition, GUARDIAN_ID))
	_dungeon_root.add_child(guardian)
	guardian.global_position = position
	guardian.soldier_died.connect(_on_guardian_died)
	_guardian = guardian
	return guardian


## Sacrificar um membro do povo em batalha custa Legitimidade (GDD §51.1).
func _on_guardian_died(_fallen: SoldierRuntime) -> void:
	_guardian = null
	guardian_fallen.emit()
	_legitimacy.remove(_definition.legitimacy_per_guardian_fallen)


# ================================================================== restauração


## O povo volta como dado: nenhum `seal_awakened`, `people_discovered`, `request_fulfilled`
## ou `oath_sworn` é reemitido, nenhum recurso é cobrado de novo e a Legitimidade volta
## exatamente como estava. O selo existe se o nível do Núcleo o desperta; o Guardião existe
## se o arquivo o descreve vivo. Faixas são validadas antes de qualquer mutação.
func restore_natives(
		core_level: int,
		work_done: float,
		legitimacy_value: int,
		fulfilled: int,
		oath: bool,
		guardian_record: Dictionary) -> bool:
	var seal_work := _definition.seal_definition.work_required
	if work_done < 0.0 or work_done > seal_work:
		return false
	if fulfilled < 0 or fulfilled > _definition.requests.size():
		return false
	if legitimacy_value < 0 or legitimacy_value > LegitimacyState.MAXIMUM:
		return false
	var guardian_alive := bool(guardian_record.get("alive", false))
	if guardian_alive:
		var health := float(guardian_record.get("health", -1.0))
		if health <= 0.0 or health > _definition.guardian_definition.max_health:
			return false
	_restoring = true
	_clear_world()
	_discovered = work_done >= seal_work
	_requests_fulfilled = fulfilled
	_oath_sworn = oath
	if core_level >= _definition.required_core_level:
		_awaken_seal()
		_seal.state.restore_remaining_work(seal_work - work_done)
		_seal.refresh_visual()
	if guardian_alive:
		var guardian := _spawn_guardian(guardian_record["position"])
		guardian.state.restore_persistent_state(
				float(guardian_record["health"]),
				int(guardian_record.get("level", 1)),
				float(guardian_record.get("experience", 0.0)))
	_legitimacy.restore(legitimacy_value)
	_restoring = false
	return true


func _clear_world() -> void:
	if _seal != null and is_instance_valid(_seal):
		_seal.queue_free()
	_seal = null
	if _guardian != null and is_instance_valid(_guardian):
		_guardian.reset_transient_order()
		_guardian.queue_free()
	_guardian = null
