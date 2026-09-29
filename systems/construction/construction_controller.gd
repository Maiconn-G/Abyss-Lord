class_name ConstructionController
extends Node

signal nest_built(nest: NestRuntime)
signal nest_completed(nest: NestRuntime)
signal barracks_built(barracks: BarracksRuntime)
signal barracks_completed(barracks: BarracksRuntime)

const NEST_INSTANCE_ID := "nest_001"
const BARRACKS_INSTANCE_ID := "barracks_001"

var _stockpile: ResourceStockpileState
var _definition: NestDefinition
var _scene: PackedScene
var _build_point: Node3D
var _dungeon_root: Node3D
var _core_state: CoreState
var _nest: NestRuntime
var _barracks_definition: BarracksDefinition
var _barracks_scene: PackedScene
var _barracks_build_point: Node3D
var _barracks: BarracksRuntime


func setup(
		stockpile_state: ResourceStockpileState,
		nest_definition: NestDefinition,
		nest_scene: PackedScene,
		build_point: Node3D,
		dungeon_root: Node3D,
		barracks_definition: BarracksDefinition = null,
		barracks_scene: PackedScene = null,
		barracks_build_point: Node3D = null) -> void:
	_stockpile = stockpile_state
	_definition = nest_definition
	_scene = nest_scene
	_build_point = build_point
	_dungeon_root = dungeon_root
	_barracks_definition = barracks_definition
	_barracks_scene = barracks_scene
	_barracks_build_point = barracks_build_point


func bind_core_state(core_state: CoreState) -> void:
	_core_state = core_state


func nest() -> NestRuntime:
	return _nest


func barracks() -> BarracksRuntime:
	return _barracks


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("build_nest"):
		build_nest()
	elif event.is_action_pressed("build_barracks"):
		build_barracks()


func build_nest() -> bool:
	if _nest != null:
		return false
	if not _consume_build_cost(_definition):
		return false
	# §23/T15: quem sabe que o Ninho usa NestState é a própria rota do Ninho. O type
	# switch "definition is BarracksDefinition" desapareceu junto com o _make_state.
	_nest = _instantiate_site(
			_scene, _definition, NestState.new(_definition, NEST_INSTANCE_ID),
			_build_point.global_position) as NestRuntime
	_nest.state.construction_completed.connect(_on_nest_completed.bind(_nest))
	nest_built.emit(_nest)
	return true


func build_barracks() -> bool:
	if _barracks != null or _barracks_definition == null:
		return false
	if not _consume_build_cost(_barracks_definition):
		return false
	_barracks = _instantiate_site(_barracks_scene, _barracks_definition,
			BarracksState.new(_barracks_definition, BARRACKS_INSTANCE_ID),
			_barracks_build_point.global_position) as BarracksRuntime
	_barracks.state.construction_completed.connect(_on_barracks_completed.bind(_barracks))
	barracks_built.emit(_barracks)
	return true


## §36/§31/T18: o Ninho que o arquivo descreve é montado, não construído. A cena entra na
## árvore com o State já no número salvo e sem consumo de estoque — quem pagou o custo foi
## a partida anterior, e o Save não cobra duas vezes. `construction_completed` continua
## conectado porque uma obra incompleta pode ser terminada depois do load: conclusão aí é
## gameplay novo, não efeito de carga. O bônus populacional de um Ninho já pronto não é
## reaplicado porque ele vive no CoreState e volta pelo State, não por este sinal.
func restore_nest(
		exists: bool,
		remaining_work: float,
		site_position: Vector3) -> bool:
	if not exists:
		_remove_site(_nest)
		_nest = null
		return true
	if _definition == null:
		return false
	if is_instance_valid(_nest) and not _nest.is_queued_for_deletion():
		if not _nest.state.restore_remaining_work(remaining_work):
			return false
		_nest.global_position = site_position
		return true
	var state := NestState.new(_definition, NEST_INSTANCE_ID)
	if not state.restore_remaining_work(remaining_work):
		return false
	_nest = _instantiate_site(
			_scene, _definition, state, site_position) as NestRuntime
	_nest.state.construction_completed.connect(_on_nest_completed.bind(_nest))
	nest_built.emit(_nest)
	return true


## §36/T18: a mesma regra do Ninho para o Quartel, sem abstração compartilhada de tipo —
## as duas rotas continuam explícitas e cada uma conhece o próprio State.
func restore_barracks(
		exists: bool,
		remaining_work: float,
		site_position: Vector3) -> bool:
	if not exists:
		_remove_site(_barracks)
		_barracks = null
		return true
	if _barracks_definition == null:
		return false
	if is_instance_valid(_barracks) and not _barracks.is_queued_for_deletion():
		if not _barracks.state.restore_remaining_work(remaining_work):
			return false
		_barracks.global_position = site_position
		return true
	var state := BarracksState.new(_barracks_definition, BARRACKS_INSTANCE_ID)
	if not state.restore_remaining_work(remaining_work):
		return false
	_barracks = _instantiate_site(
			_barracks_scene, _barracks_definition, state, site_position) as BarracksRuntime
	_barracks.state.construction_completed.connect(_on_barracks_completed.bind(_barracks))
	barracks_built.emit(_barracks)
	return true


## §95/§100/T18: a rota de carga é de sincronização, não de "criar se não houver". Load
## repetido encontra o Runtime do load anterior e ajusta o trabalho restante em vez de
## recusar, e `exists = false` remove a obra que a partida construiu depois do save. A
## remoção não emite conclusão: liberar sem sinal é o que impede o bônus populacional de
## ser aplicado duas vezes, porque o número certo já veio do CoreState.
func _remove_site(site: ConstructionRuntime) -> void:
	if site != null and is_instance_valid(site):
		site.queue_free()


# O consumo é atômico porque ResourceStockpileState.consume_resource() só desconta
# quando o saldo cobre o custo inteiro.
# §17/T15: a assinatura agora é tipada — custo e recurso vêm da ConstructionDefinition,
# então o controller não precisa mais de parâmetro sem tipo para ler os dois campos.
func _consume_build_cost(definition: ConstructionDefinition) -> bool:
	return _stockpile.consume_resource(definition.build_resource, definition.build_cost)


## §22/T15: helper genérico de montagem — cena, Definition, State e o ponto onde a obra
## nasce. Ele escolhe nada: quem decide que Ninho usa NestState e Quartel usa BarracksState
## são as rotas explícitas de cada tipo. Não há Factory nem Registry.
##
## §36/T18: o último parámetro deixou de ser o Marker3D da cena e passou a ser a posição.
## Na partida ele continua vindo do build point; no load ele vem do arquivo, porque a obra
## restaurada reocupa o lugar exato que o Save registrou.
func _instantiate_site(
		scene: PackedScene,
		definition: ConstructionDefinition,
		state: ConstructionState,
		site_position: Vector3) -> ConstructionRuntime:
	var site := scene.instantiate() as ConstructionRuntime
	_dungeon_root.add_child(site)
	site.global_position = site_position
	site.setup(definition, state)
	return site


func _on_nest_completed(nest: NestRuntime) -> void:
	_core_state.add_population_capacity_bonus(_definition.population_capacity_bonus)
	nest_completed.emit(nest)


func _on_barracks_completed(barracks: BarracksRuntime) -> void:
	barracks_completed.emit(barracks)
