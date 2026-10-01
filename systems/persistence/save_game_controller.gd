class_name SaveGameController
extends Node

## Tarefa 18 — a persistência da campanha. O arquivo não é uma fotografia da SceneTree:
## ele é a fotografia do domínio (§3/§158). Por isso este controller lê States, resolve
## identidades semânticas contra as Definitions que GameMain injetou e grava números. Ele
## nunca grava Node, caminho de cena, seleção, ordem de movimento, texto de HUD ou máximo
## derivado de Definition (§3/§24/§122/§123/§124).
##
## §10/§11: um controller central é justificado porque persistência cruza todos os
## sistemas, mas ele não é Autoload, não é SaveManager e não descobrem nada sozinhos: cada
## dependência chega por parâmetro na composition root.
##
## §67: a regra de ouro da carga é validar por inteiro antes de tocar em um único número.
## Nenhum caminho deste arquivo aplica "metade de um JSON".

signal save_succeeded(path: String)
signal load_succeeded(path: String)
signal operation_failed(operation: String, reason: String)

## §6/§108: o caminho de produção é `user://`. Testes injetam outro caminho (§107) e o
## Save nunca escreve em `res://`.
const DEFAULT_PRIMARY_PATH := "user://campaign_save.json"

const SAVE_OPERATION := "save"
const LOAD_OPERATION := "load"

## §45: a chave tem um único dono — o contrato em CampaignSnapshot.
const KEY_INVASION_STATE := CampaignSnapshot.KEY_STATE

var _core: CoreRuntime
var _core_state: CoreState
var _crystal: AbyssalCrystalState
var _stockpile: ResourceStockpileState
var _dungeon: Node3D
var _selection: SelectionController
var _construction: ConstructionController
var _invocation: WorkerInvocationController
var _recruitment: SoldierRecruitmentController
var _invasion: InvasionController
var _evolution: CoreEvolutionController

## §16/§71: a whitelist. As Definitions e cenas com que a campanha foi montada são as
## únicas materiais que um load pode usar; um `unit_type_id` desconhecido morre na
## validação, nunca vira argumento de `load()`.
var _worker_definition: WorkerDefinition
var _soldier_definition: SoldierDefinition
var _enemy_definition: EnemyDefinition
var _nest_definition: NestDefinition
var _barracks_definition: BarracksDefinition
## §61/T20: a Definition da Mina entra na whitelist como material de restauração. O que o
## arquivo diz é `production_elapsed`; o intervalo com que se confere esse número é daqui,
## e caminho de cena nunca vem do JSON — a cena da Mina pertence ao ConstructionController,
## que é quem a instancia em `restore_mine()`.
var _mine_definition: MineDefinition
## §61/T21: a Definition da Fazenda entra na whitelist como material de restauração. O que o
## arquivo diz é `production_elapsed`; a faixa com que se confere esse número é daqui, e
## caminho de cena nunca vem do JSON — a cena da Fazenda pertence ao ConstructionController,
## que é quem a instancia em `restore_fungal_farm()`.
var _fungal_farm_definition: FungalFarmDefinition
var _rock_scene: PackedScene
var _pile_scene: PackedScene
var _core_definitions_by_level: Dictionary = {}
var _definitions_by_resource_id: Dictionary = {}

## §38/§39: o livro-razão das Rochas. Uma Rocha escavada já saiu da SceneTree, então a
## varredura de Nodes vivos não basta para saber o que o mundo ainda tem. O ledger nasce
## quando GameMain apresenta as Rochas canônicas e guarda a Definition, a posição original
## e o State — que continua vivo mesmo depois de o Runtime se ir.
var _rock_ledger: Dictionary = {}

var _primary_path := DEFAULT_PRIMARY_PATH
var _is_loading := false
## §64: o motivo da última recusa de leitura. Serve para a mensagem do fallback dizer o
## que estava errado no primário, e nada além disso.
var _last_read_reason := ""


## §11: tudo por injeção. Nenhuma busca de Node, nenhum grupo varrido, nenhum singleton.
func setup(
		core: CoreRuntime,
		core_state: CoreState,
		crystal: AbyssalCrystalState,
		stockpile: ResourceStockpileState,
		dungeon: Node3D,
		selection: SelectionController,
		construction: ConstructionController,
		invocation: WorkerInvocationController,
		recruitment: SoldierRecruitmentController,
		invasion: InvasionController,
		evolution: CoreEvolutionController) -> void:
	_core = core
	_core_state = core_state
	_crystal = crystal
	_stockpile = stockpile
	_dungeon = dungeon
	_selection = selection
	_construction = construction
	_invocation = invocation
	_recruitment = recruitment
	_invasion = invasion
	_evolution = evolution


func bind_restore_materials(
		worker_definition: WorkerDefinition,
		soldier_definition: SoldierDefinition,
		enemy_definition: EnemyDefinition,
		nest_definition: NestDefinition,
		barracks_definition: BarracksDefinition,
		mine_definition: MineDefinition,
		fungal_farm_definition: FungalFarmDefinition,
		core_definitions: Array,
		resource_definitions: Array,
		rock_scene: PackedScene,
		pile_scene: PackedScene) -> void:
	_worker_definition = worker_definition
	_soldier_definition = soldier_definition
	_enemy_definition = enemy_definition
	_nest_definition = nest_definition
	_barracks_definition = barracks_definition
	_mine_definition = mine_definition
	_fungal_farm_definition = fungal_farm_definition
	_rock_scene = rock_scene
	_pile_scene = pile_scene
	for definition in core_definitions:
		var core_definition := definition as CoreDefinition
		if core_definition != null:
			_core_definitions_by_level[core_definition.level] = core_definition
	for definition in resource_definitions:
		var resource_definition := definition as ResourceDefinition
		if resource_definition != null:
			_definitions_by_resource_id[String(resource_definition.resource_id)] \
					= resource_definition


## §107: o caminho é configurável justamente para o teste não escrever no save do jogador.
func configure_save_path(path: String) -> void:
	_primary_path = path


func save_path() -> String:
	return _primary_path


func backup_path() -> String:
	return _primary_path.get_basename() + ".bak"


func temporary_path() -> String:
	return _primary_path.get_basename() + ".tmp"


## §55/§56: as duas ações vivem no InputMap do projeto; aqui só existe `is_action_pressed`,
## nunca keycode comparado à mão. Ctrl+S e Ctrl+L são combinações que nenhum comando de
## gameplay usa, e a suíte de persistência prova que a letra S continua sendo da câmera.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("save_game"):
		save_campaign()
	elif event.is_action_pressed("load_game"):
		load_campaign()


## §39: a Rocha canônica é registrada ao montar a campanha. O State criado aqui é o mesmo
## que o Runtime usa, e é dele que o Save lê o trabalho restante — depois de o Node ser
## liberado, sobra o State, e é ele que responde pela Rocha.
func register_rock(rock: RockRuntime) -> void:
	var state := RockState.new(rock.definition, rock.rock_id)
	rock.setup(rock.definition, state)
	rock.resource_drop_requested.connect(spawn_resource_pile)
	_rock_ledger[rock.rock_id] = {
		"rock": rock,
		"definition": rock.definition,
		"position": rock.global_position,
		"state": state,
	}


## §42/§43: o monte criado pela escavação e o monte restaurado do arquivo são o mesmo
## caminho — Runtime novo, State novo, id semântico derivado da Rocha de origem.
func spawn_resource_pile(
		resource: ResourceDefinition,
		amount: int,
		world_position: Vector3,
		source_id: String) -> void:
	var pile := _pile_scene.instantiate() as ResourcePileRuntime
	pile.position = Vector3(world_position.x, 0.0, world_position.z)
	_dungeon.add_child(pile)
	pile.setup(resource, ResourcePileState.new(resource, source_id + "_drop", amount))


# ============================================================== Leitura da campanha


## §2: o snapshot é construído no momento do save, por varredura. Não existe snapshot
## mantido por frame (§129), e nenhum campo derivado entra no arquivo (§123/§124/§125).
func snapshot_campaign() -> Dictionary:
	return {
		CampaignSnapshot.SECTION_CORE: _core_record(),
		CampaignSnapshot.SECTION_PROGRESSION: {
			CampaignSnapshot.KEY_CRYSTAL: {CampaignSnapshot.KEY_AMOUNT: _crystal.amount},
		},
		CampaignSnapshot.SECTION_ECONOMY: {
			CampaignSnapshot.KEY_STOCKPILE: _stockpile_record(),
		},
		CampaignSnapshot.SECTION_UNITS: _units_record(),
		CampaignSnapshot.SECTION_CONSTRUCTIONS: _constructions_record(),
		CampaignSnapshot.SECTION_WORLD: _world_record(),
		CampaignSnapshot.SECTION_INVASION: _invasion_record(),
	}


func _core_record() -> Dictionary:
	return {
		"core_id": CampaignSnapshot.CORE_ID,
		CampaignSnapshot.KEY_LEVEL: _core_state.level,
		CampaignSnapshot.KEY_INTEGRITY: _core_state.integrity,
		CampaignSnapshot.KEY_ESSENCE: _core_state.essence,
		CampaignSnapshot.KEY_POPULATION: _core_state.population,
		CampaignSnapshot.KEY_CAPACITY_BONUS: _core_state.population_capacity_bonus,
	}


func _stockpile_record() -> Dictionary:
	var recorded: Dictionary = {}
	var amounts: Dictionary = _stockpile.snapshot_amounts()
	for resource_id in amounts:
		var stored := int(amounts[resource_id])
		if stored > 0:
			recorded[String(resource_id)] = stored
	return recorded


func _units_record() -> Dictionary:
	var workers: Array = []
	for child in _dungeon.get_children():
		var runtime := child as WorkerRuntime
		if runtime != null and not runtime.is_queued_for_deletion():
			workers.append(_worker_record(runtime))
	return {
		CampaignSnapshot.KEY_WORKERS: workers,
		CampaignSnapshot.KEY_SECOND_SUMMONED: _invocation.worker_ever_summoned(),
		CampaignSnapshot.KEY_SOLDIER: _soldier_record(),
	}


## §23/§24/§25: o que o Worker é, onde ele está e o que ele carrega. A ordem que ele ia
## cumprir é transitória (§4) e fica fora do arquivo.
func _worker_record(worker: WorkerRuntime) -> Dictionary:
	var carried: ResourceDefinition = worker.state.carried_resource
	return {
		CampaignSnapshot.KEY_UNIT_ID: worker.state.unit_id,
		CampaignSnapshot.KEY_UNIT_TYPE_ID: String(worker.definition.unit_type_id),
		CampaignSnapshot.KEY_HEALTH: worker.state.health,
		CampaignSnapshot.KEY_LEVEL: worker.state.level,
		CampaignSnapshot.KEY_EXPERIENCE: worker.state.experience,
		CampaignSnapshot.KEY_POSITION:
				CampaignSnapshot.encode_position(worker.global_position),
		CampaignSnapshot.KEY_CARRIED_RESOURCE:
				String(carried.resource_id) if carried != null else null,
		CampaignSnapshot.KEY_CARRIED_AMOUNT: worker.state.carried_amount,
	}


## §27/§28: `recruited` é a regra histórica e `alive` é a entidade. Morto continua
## recrutado, e é isso que impede `R` de liberar um segundo Soldado numa campanha carregada.
func _soldier_record() -> Dictionary:
	var soldier := _valid_recruit()
	if soldier == null:
		return {
			CampaignSnapshot.KEY_RECRUITED: _recruitment.ever_recruited(),
			CampaignSnapshot.KEY_ALIVE: false,
		}
	return {
		CampaignSnapshot.KEY_RECRUITED: true,
		CampaignSnapshot.KEY_ALIVE: true,
		CampaignSnapshot.KEY_UNIT_ID: soldier.state.unit_id,
		CampaignSnapshot.KEY_UNIT_TYPE_ID: String(soldier.definition.unit_type_id),
		CampaignSnapshot.KEY_HEALTH: soldier.state.health,
		CampaignSnapshot.KEY_LEVEL: soldier.state.level,
		CampaignSnapshot.KEY_EXPERIENCE: soldier.state.experience,
		CampaignSnapshot.KEY_POSITION:
				CampaignSnapshot.encode_position(soldier.global_position),
	}


## §30/§31/§34: existe, o id semântico, o trabalho restante e a posição. Conclusão é
## derivada de `remaining_work <= 0` (§123) e por isso não há bool duplicado.
##
## §62/T20: a Mina entra na mesma seção. Ela é uma obra, e o que a diferencia é o relógio.
## §62/T21: a Fazenda Fúngica entra pela mesma regra — obra com relógio. A Essência que ela
## gasta por ciclo NÃO é campo do arquivo: o saldo de Essência já é `campaign.core.essence`.
func _constructions_record() -> Dictionary:
	return {
		CampaignSnapshot.SECTION_NEST:
				_site_record(_construction.nest(), CampaignSnapshot.NEST_ID, "nest_id"),
		CampaignSnapshot.SECTION_BARRACKS:
				_site_record(_construction.barracks(), CampaignSnapshot.BARRACKS_ID,
						"barracks_id"),
		CampaignSnapshot.SECTION_MINE: _mine_record(_construction.mine()),
		CampaignSnapshot.SECTION_FUNGAL_FARM:
				_fungal_farm_record(_construction.fungal_farm()),
	}


## §49/§50/T20: o arquivo guarda `production_elapsed`, porque é estado temporal real da
## campanha. Não guarda intervalo, montante nem recurso produzido — os três vêm da
## MineDefinition, e duplicá-los criaria duas verdades sobre a mesma Mina.
##
## A regra §50 é aplicada na escrita: obra incompleta não tem relógio, então o número que
## sai para o arquivo é 0.0. Assim o documento que este controller produz já é o documento
## que o validador espera, sem depender de normalização na leitura.
func _mine_record(mine: MineRuntime) -> Dictionary:
	if mine == null or mine.is_queued_for_deletion():
		return {CampaignSnapshot.KEY_EXISTS: false}
	var mine_state := mine.state as MineState
	var recorded: Dictionary = {
		CampaignSnapshot.KEY_EXISTS: true,
		"mine_id": CampaignSnapshot.MINE_ID,
		CampaignSnapshot.KEY_REMAINING_WORK: mine_state.remaining_work,
		CampaignSnapshot.KEY_POSITION: CampaignSnapshot.encode_position(mine.global_position),
	}
	var elapsed := 0.0
	if mine.is_completed():
		elapsed = mine_state.production_elapsed
	recorded[CampaignSnapshot.KEY_PRODUCTION_ELAPSED] = elapsed
	return recorded


## §49/§50/T21: a mesma regra da Mina para a Fazenda — o arquivo guarda `production_elapsed`,
## porque é estado temporal real da campanha. Intervalo, montante, recurso produzido e custo
## de Essência vêm da FungalFarmDefinition, e duplicá-los criaria duas verdades sobre a mesma
## Fazenda. O custo de Essência em particular JÁ está no arquivo, em `core.essence`: gravar o
## custo por ciclo não é gravar saldo, e gravar saldo uma segunda vez seria duplicar.
##
## A regra §50 é aplicada na escrita: obra incompleta não tem relógio, então o número que sai
## para o arquivo é 0.0.
func _fungal_farm_record(farm: FungalFarmRuntime) -> Dictionary:
	if farm == null or farm.is_queued_for_deletion():
		return {CampaignSnapshot.KEY_EXISTS: false}
	var farm_state := farm.state as FungalFarmState
	var recorded: Dictionary = {
		CampaignSnapshot.KEY_EXISTS: true,
		"fungal_farm_id": CampaignSnapshot.FUNGAL_FARM_ID,
		CampaignSnapshot.KEY_REMAINING_WORK: farm_state.remaining_work,
		CampaignSnapshot.KEY_POSITION: CampaignSnapshot.encode_position(farm.global_position),
	}
	var elapsed := 0.0
	if farm.is_completed():
		elapsed = farm_state.production_elapsed
	recorded[CampaignSnapshot.KEY_PRODUCTION_ELAPSED] = elapsed
	return recorded


func _site_record(site: ConstructionRuntime, instance_id: String, id_field: String) -> Dictionary:
	if site == null or site.is_queued_for_deletion():
		return {CampaignSnapshot.KEY_EXISTS: false}
	return {
		CampaignSnapshot.KEY_EXISTS: true,
		id_field: instance_id,
		CampaignSnapshot.KEY_REMAINING_WORK: site.state.remaining_work,
		CampaignSnapshot.KEY_POSITION: CampaignSnapshot.encode_position(site.global_position),
	}


func _world_record() -> Dictionary:
	var rocks: Array = []
	for rock_id in _rock_ledger:
		var entry: Dictionary = _rock_ledger[rock_id]
		var state: RockState = entry["state"]
		rocks.append({
			CampaignSnapshot.KEY_ROCK_ID: rock_id,
			CampaignSnapshot.KEY_REMAINING_WORK: state.remaining_work,
			CampaignSnapshot.KEY_EXCAVATED: state.is_excavated(),
		})
	var piles: Array = []
	for child in _dungeon.get_children():
		var pile := child as ResourcePileRuntime
		if pile == null or pile.is_queued_for_deletion():
			continue
		# §44: monte sem recurso não é estado de campanha — ele já está indo embora.
		if pile.state.is_depleted():
			continue
		piles.append({
			CampaignSnapshot.KEY_PILE_ID: pile.state.pile_id,
			CampaignSnapshot.KEY_RESOURCE_ID: String(pile.definition.resource_id),
			CampaignSnapshot.KEY_AMOUNT: pile.state.amount,
			CampaignSnapshot.KEY_POSITION: CampaignSnapshot.encode_position(pile.global_position),
		})
	return {CampaignSnapshot.KEY_ROCKS: rocks, CampaignSnapshot.KEY_PILES: piles}


## §45/§46/§48: o ciclo de vida em texto legível, o segundo exato da preparação e só os
## invasores que ainda respiram. Alvo de combate é transitório e fica de fora.
func _invasion_record() -> Dictionary:
	var state := _invasion.invasion_state()
	var invaders: Array = []
	# §45/§99/T18: quem decide se há invasor no arquivo é o ciclo de vida, não a varredura
	# de Nodes. Na DEFEAT as Feras continuam em cena, mas em stance terminal, e gravá-las
	# produziria a campanha impossível que `validate_campaign` recusa. O snapshot descreve
	# o estado do domínio, e fora de ACTIVE o domínio não tem exército inimigo em campo.
	if state == InvasionController.InvasionState.ACTIVE:
		for enemy in _invasion.invaders():
			if not is_instance_valid(enemy) or enemy.is_queued_for_deletion() \
					or enemy.state.is_dead():
				continue
			invaders.append({
				CampaignSnapshot.KEY_INVADER_ID: enemy.state.enemy_id,
				CampaignSnapshot.KEY_ENEMY_TYPE_ID: String(enemy.definition.enemy_type_id),
				CampaignSnapshot.KEY_HEALTH: enemy.state.health,
				CampaignSnapshot.KEY_POSITION:
						CampaignSnapshot.encode_position(enemy.global_position),
			})
	return {
		KEY_INVASION_STATE: invasion_state_name(_invasion.invasion_state()),
		CampaignSnapshot.KEY_PREPARATION_REMAINING: _invasion.preparation_time_remaining(),
		CampaignSnapshot.KEY_INVADERS: invaders,
	}


func _valid_recruit() -> SoldierRuntime:
	var soldier := _recruitment.soldier()
	if soldier == null or not is_instance_valid(soldier) or soldier.is_queued_for_deletion():
		return null
	return soldier


func invasion_state_name(value: int) -> String:
	match value:
		InvasionController.InvasionState.NOT_STARTED:
			return "NOT_STARTED"
		InvasionController.InvasionState.PREPARATION:
			return "PREPARATION"
		InvasionController.InvasionState.ACTIVE:
			return "ACTIVE"
		InvasionController.InvasionState.VICTORY:
			return "VICTORY"
		InvasionController.InvasionState.DEFEAT:
			return "DEFEAT"
	return ""


func invasion_state_of(name: String) -> int:
	match name:
		"NOT_STARTED":
			return InvasionController.InvasionState.NOT_STARTED
		"PREPARATION":
			return InvasionController.InvasionState.PREPARATION
		"ACTIVE":
			return InvasionController.InvasionState.ACTIVE
		"VICTORY":
			return InvasionController.InvasionState.VICTORY
		"DEFEAT":
			return InvasionController.InvasionState.DEFEAT
	return -1


# ==================================================================== Validação


## §67/§69/§70: a validação completa de uma campanha — estrutura primeiro, depois as
## faixas que só existem contra as Definitions injetadas, por fim as invariantes do
## domínio (§29). Devolve String vazio quando se pode aplicar, e o motivo da recusa
## quando não se pode. Salvar passa por aqui também: um arquivo inconsistente não chega
## ao disco.
func validate_campaign(campaign: Dictionary) -> String:
	var reason := CampaignSnapshot.validate_document(
			CampaignSnapshot.build_document(campaign, {}))
	if not reason.is_empty():
		return reason
	reason = _validate_core_bounds(campaign)
	if not reason.is_empty():
		return reason
	reason = _validate_unit_types(campaign)
	if not reason.is_empty():
		return reason
	reason = _validate_construction_bounds(campaign)
	if not reason.is_empty():
		return reason
	reason = _validate_world_ids(campaign)
	if not reason.is_empty():
		return reason
	reason = _validate_invasion_records(campaign)
	if not reason.is_empty():
		return reason
	return _validate_population_consistency(campaign)


## §70: nada acima do que a Definition daquele nível permite existir.
func _validate_core_bounds(campaign: Dictionary) -> String:
	var core: Dictionary = campaign[CampaignSnapshot.SECTION_CORE]
	# §13/T18: o dicionário de níveis é indexed por int e o JSON devolve float — sem este
	# `int()` o Nv.1 salvo seria lido como "level desconhecido: 1.0".
	var definition := _core_definitions_by_level.get(
			int(core[CampaignSnapshot.KEY_LEVEL])) as CoreDefinition
	if definition == null:
		return "level de Núcleo desconhecido: %s" % [core[CampaignSnapshot.KEY_LEVEL]]
	if core[CampaignSnapshot.KEY_INTEGRITY] > definition.max_integrity:
		return "integrity acima do máximo do Nv.%d" % core[CampaignSnapshot.KEY_LEVEL]
	if core[CampaignSnapshot.KEY_ESSENCE] > definition.max_essence:
		return "essence acima do máximo do Nv.%d" % core[CampaignSnapshot.KEY_LEVEL]
	var capacity := definition.population_capacity \
			+ int(core[CampaignSnapshot.KEY_CAPACITY_BONUS])
	if core[CampaignSnapshot.KEY_POPULATION] > capacity:
		return "population acima da capacidade efetiva %d" % capacity
	return ""


## §71: o id de tipo só vale se for o da Definition que a campanha usa. Não há `load()` de
## caminho arbitrário, não há "dragon_admin" e não há unidade sem tipo conhecido.
func _validate_unit_types(campaign: Dictionary) -> String:
	var units: Dictionary = campaign[CampaignSnapshot.SECTION_UNITS]
	var seen_ids: Array = []
	for entry in units[CampaignSnapshot.KEY_WORKERS] as Array:
		var worker := entry as Dictionary
		if worker[CampaignSnapshot.KEY_UNIT_ID] in seen_ids:
			return "worker duplicado no arquivo: %s" % worker[CampaignSnapshot.KEY_UNIT_ID]
		seen_ids.append(worker[CampaignSnapshot.KEY_UNIT_ID])
		if worker[CampaignSnapshot.KEY_UNIT_TYPE_ID] != String(_worker_definition.unit_type_id):
			return "unit_type_id de Worker desconhecido: %s" \
					% worker[CampaignSnapshot.KEY_UNIT_TYPE_ID]
		if float(worker[CampaignSnapshot.KEY_HEALTH]) > _worker_definition.max_health:
			return "%s com vida acima do máximo" % worker[CampaignSnapshot.KEY_UNIT_ID]
		var cargo_id: Variant = worker[CampaignSnapshot.KEY_CARRIED_RESOURCE]
		if cargo_id != null and not _definitions_by_resource_id.has(cargo_id):
			return "carried_resource desconhecida: %s" % [cargo_id]
		if int(worker[CampaignSnapshot.KEY_CARRIED_AMOUNT]) > _worker_definition.carry_capacity:
			return "%s carrega mais que a capacidade" % worker[CampaignSnapshot.KEY_UNIT_ID]
	var soldier: Dictionary = units[CampaignSnapshot.KEY_SOLDIER]
	if not soldier[CampaignSnapshot.KEY_ALIVE]:
		return ""
	if soldier[CampaignSnapshot.KEY_UNIT_TYPE_ID] != String(_soldier_definition.unit_type_id):
		return "unit_type_id do Soldado desconhecido: %s" % soldier[CampaignSnapshot.KEY_UNIT_TYPE_ID]
	if soldier[CampaignSnapshot.KEY_HEALTH] > _soldier_definition.max_health:
		return "soldier com vida acima do máximo"
	return ""


func _validate_construction_bounds(campaign: Dictionary) -> String:
	var constructions: Dictionary = campaign[CampaignSnapshot.SECTION_CONSTRUCTIONS]
	for pair in [[CampaignSnapshot.SECTION_NEST, _nest_definition],
			[CampaignSnapshot.SECTION_BARRACKS, _barracks_definition]]:
		var site: Dictionary = constructions[pair[0]]
		if not site[CampaignSnapshot.KEY_EXISTS]:
			continue
		var definition := pair[1] as ConstructionDefinition
		if definition == null:
			return "a campanha não tem Definition para %s" % pair[0]
		if site[CampaignSnapshot.KEY_REMAINING_WORK] > definition.work_required:
			return "%s com trabalho acima do exigido" % pair[0]
	var mine_reason := _validate_mine_clock(
			constructions[CampaignSnapshot.SECTION_MINE] as Dictionary)
	if not mine_reason.is_empty():
		return mine_reason
	return _validate_fungal_farm_clock(
			constructions[CampaignSnapshot.SECTION_FUNGAL_FARM] as Dictionary)


## §50/§51/T20: as duas invariantes do relógio da Mina. Obra incompleta não tem produção
## andando, e obra completa tem relógio estritamente dentro de um intervalo — o que passa
## do intervalo já virou minério e foi entregue ao estoque, então não é mais estado.
## O intervalo é lido da MineDefinition injetada (§61), nunca do arquivo.
func _validate_mine_clock(site: Dictionary) -> String:
	if not site[CampaignSnapshot.KEY_EXISTS]:
		return ""
	if _mine_definition == null:
		return "a campanha não tem Definition para mine"
	var remaining := float(site[CampaignSnapshot.KEY_REMAINING_WORK])
	var elapsed := float(site[CampaignSnapshot.KEY_PRODUCTION_ELAPSED])
	if remaining > _mine_definition.work_required:
		return "mine com trabalho acima do exigido"
	if remaining > 0.0 and elapsed > 0.0:
		return "mine incompleta com relógio de produção"
	if remaining <= 0.0 and elapsed >= _mine_definition.production_interval:
		return "mine com relógio acima do intervalo de produção"
	return ""


## §50/§51/T21: as duas invariantes do relógio da Fazenda são as mesmas da Mina — obra
## incompleta não tem produção andando, e obra completa tem relógio dentro de um intervalo.
## A diferença é o topo da faixa: a Mina exige `elapsed < interval` (strict), porque um ciclo
## inteiro acumulado já teria virado minério; a Fazenda aceita `elapsed <= interval`
## (inclusive), porque §17 define que um ciclo pronto **parado esperando Essência** é um
## estado legítimo da campanha. O intervalo é lido da Definition injetada, nunca do arquivo.
func _validate_fungal_farm_clock(site: Dictionary) -> String:
	if not site[CampaignSnapshot.KEY_EXISTS]:
		return ""
	if _fungal_farm_definition == null:
		return "a campanha não tem Definition para fungal_farm"
	var remaining := float(site[CampaignSnapshot.KEY_REMAINING_WORK])
	var elapsed := float(site[CampaignSnapshot.KEY_PRODUCTION_ELAPSED])
	if remaining > _fungal_farm_definition.work_required:
		return "fungal_farm com trabalho acima do exigido"
	if remaining > 0.0 and elapsed > 0.0:
		return "fungal_farm incompleta com relógio de produção"
	if remaining <= 0.0 and elapsed > _fungal_farm_definition.production_interval:
		return "fungal_farm com relógio acima do intervalo de produção"
	return ""


## §38/§71/§106: toda Rocha do arquivo tem de ser uma Rocha canônica registrada, com
## trabalho dentro da própria Definition, e o estoque só conhece recurso que existe.
func _validate_world_ids(campaign: Dictionary) -> String:
	var world: Dictionary = campaign[CampaignSnapshot.SECTION_WORLD]
	var listed: Array = []
	for rock in world[CampaignSnapshot.KEY_ROCKS] as Array:
		var rock_id := String(rock[CampaignSnapshot.KEY_ROCK_ID])
		if not _rock_ledger.has(rock_id):
			return "rock_id desconhecido: %s" % rock_id
		listed.append(rock_id)
		var definition: RockDefinition = _rock_ledger[rock_id]["definition"]
		if rock[CampaignSnapshot.KEY_REMAINING_WORK] > definition.work_required:
			return "%s com trabalho acima do exigido" % rock_id
	# §38: o arquivo também não pode esquecer Rocha que a campanha tem.
	if listed.size() != _rock_ledger.size():
		return "world.rocks não cobre as Rochas canônicas da campanha"
	for pile in world[CampaignSnapshot.KEY_PILES] as Array:
		if not _definitions_by_resource_id.has(pile[CampaignSnapshot.KEY_RESOURCE_ID]):
			return "resource_id de monte desconhecido: %s" % pile[CampaignSnapshot.KEY_RESOURCE_ID]
	var stockpile: Dictionary = campaign[CampaignSnapshot.SECTION_ECONOMY][
			CampaignSnapshot.KEY_STOCKPILE]
	for resource_id in stockpile:
		if not _definitions_by_resource_id.has(resource_id):
			return "resource_id de estoque desconhecido: %s" % resource_id
	return ""


func _validate_invasion_records(campaign: Dictionary) -> String:
	var invasion: Dictionary = campaign[CampaignSnapshot.SECTION_INVASION]
	var state := invasion_state_of(String(invasion[KEY_INVASION_STATE]))
	if state < 0:
		return "estado de invasão desconhecido: %s" % invasion[KEY_INVASION_STATE]
	var invaders: Array = invasion[CampaignSnapshot.KEY_INVADERS]
	if state != InvasionController.InvasionState.ACTIVE and not invaders.is_empty():
		return "%s não pode ter invasor em campo" % invasion[KEY_INVASION_STATE]
	if state == InvasionController.InvasionState.ACTIVE and invaders.is_empty():
		return "ACTIVE sem invasor é uma campanha impossível"
	if invaders.size() > InvasionController.INVADER_COUNT:
		return "mais invasores do que a primeira invasão tem"
	if state != InvasionController.InvasionState.PREPARATION \
			and invasion[CampaignSnapshot.KEY_PREPARATION_REMAINING] > 0.0:
		return "tempo de preparação guardado fora de PREPARATION"
	for invader in invaders:
		if invader[CampaignSnapshot.KEY_ENEMY_TYPE_ID] != String(_enemy_definition.enemy_type_id):
			return "enemy_type_id desconhecido: %s" % invader[CampaignSnapshot.KEY_ENEMY_TYPE_ID]
		if invader[CampaignSnapshot.KEY_HEALTH] > _enemy_definition.max_health:
			return "%s com vida acima do máximo" % invader[CampaignSnapshot.KEY_INVADER_ID]
	return ""


## §29: Population é o número do Núcleo, e as unidades próprias vivas são a conta dele.
## As duas metades têm de fechar — se não fecham, o arquivo é inconsistente e a resposta
## é recusar, nunca "corrigir" um número quieto.
func _validate_population_consistency(campaign: Dictionary) -> String:
	var core: Dictionary = campaign[CampaignSnapshot.SECTION_CORE]
	var units: Dictionary = campaign[CampaignSnapshot.SECTION_UNITS]
	var expected := (units[CampaignSnapshot.KEY_WORKERS] as Array).size()
	if units[CampaignSnapshot.KEY_SOLDIER][CampaignSnapshot.KEY_ALIVE]:
		expected += 1
	if core[CampaignSnapshot.KEY_POPULATION] != expected:
		return "population %s não bate com %d unidade(s) própria(s)" % [
				core[CampaignSnapshot.KEY_POPULATION], expected]
	return ""


# ========================================================================= Save


func save_campaign() -> bool:
	if _is_loading:
		# §57: durante uma carga o mundo é reescrito passo a passo; salvar no meio seria
		# gravar uma campanha pela metade.
		return false
	var campaign := snapshot_campaign()
	var reason := validate_campaign(campaign)
	if not reason.is_empty():
		_fail(SAVE_OPERATION, reason)
		return false
	var text := CampaignSnapshot.to_text(
			CampaignSnapshot.build_document(campaign, _metadata()))
	var temporary := temporary_path()
	if not _write_text(temporary, text):
		_fail(SAVE_OPERATION, "falha ao escrever %s" % temporary)
		return false
	# §62: o temporário é relido e validado antes de qualquer troca. Um JSON que não
	# sobrevive à própria escrita não encosta no save bom.
	var reread: Variant = CampaignSnapshot.parse_document(_read_text(temporary))
	var check := CampaignSnapshot.validate_document(reread)
	if not check.is_empty():
		DirAccess.remove_absolute(temporary)
		_fail(SAVE_OPERATION, "o arquivo temporário não passou na validação: %s" % check)
		return false
	var primary := _primary_path
	var backup := backup_path()
	if FileAccess.file_exists(primary):
		if DirAccess.copy_absolute(primary, backup) != OK:
			DirAccess.remove_absolute(temporary)
			_fail(SAVE_OPERATION, "falha ao preservar o backup em %s" % backup)
			return false
		DirAccess.remove_absolute(primary)
	if DirAccess.rename_absolute(temporary, primary) != OK:
		DirAccess.remove_absolute(temporary)
		_fail(SAVE_OPERATION, "falha ao publicar %s" % primary)
		return false
	save_succeeded.emit(primary)
	print("SaveGameController: campanha salva em %s" % primary)
	return true


## §72/§73: metadado é informação de cabeçalho. Nenhum jogo depende dele para carregar, e
## versionar o formato é papel de `save_version` (§6), não de hash de commit.
func _metadata() -> Dictionary:
	return {
		"saved_at_unix": Time.get_unix_time_from_system(),
		"engine_version": str(Engine.get_version_info().get("string", "")),
	}


# ========================================================================= Load


func load_campaign() -> bool:
	if _is_loading:
		return false
	_is_loading = true
	var chosen := _primary_path
	# §58: arquivo que não existe não é corrupção — é "nada para carregar", e o mundo em
	# curso continua intacto.
	if not FileAccess.file_exists(_primary_path):
		_is_loading = false
		_fail(LOAD_OPERATION, "nenhum arquivo de campanha em %s" % _primary_path)
		return false
	var document := _read_document(_primary_path)
	if document.is_empty():
		var broken := _last_read_reason
		document = _read_document(backup_path())
		if document.is_empty():
			# §66: primário e backup ruins — a campanha em curso continua intocada.
			_is_loading = false
			_fail(LOAD_OPERATION, "campanha e backup ilegíveis (%s)" % broken)
			return false
		# §64: o fallback é dito em voz alta, nunca silencioso.
		chosen = backup_path()
		print("SaveGameController: save primário corrompido, usando backup %s" % chosen)
	var campaign: Dictionary = document[CampaignSnapshot.ROOT_CAMPAIGN]
	var reason := validate_campaign(campaign)
	if not reason.is_empty():
		# §67/§68: recusar é não tocar em nada.
		_is_loading = false
		_fail(LOAD_OPERATION, reason)
		return false
	_apply(campaign)
	_is_loading = false
	load_succeeded.emit(chosen)
	print("SaveGameController: campanha carregada de %s" % chosen)
	return true


## §62/§64: leitura + parse + validação estrutural num passo só. Devolve Dictionary vazio
## para ausente, ilegível ou estruturalmente ruim, e guarda o motivo da última recusa.
## Um documento válido nunca é vazio: `campaign` tem sempre as sete seções (§69).
##
## §53/§55/§70/T20: este é o único ponto em que a versão do arquivo é conhecida antes de
## o mundo ser tocado, então é aqui que a migração acontece. A sequência é a do contrato:
## validar contra o schema da versão declarada, migrar, validar o resultado como V2. Nada
## é aplicado antes, e um V1 que migra para um V2 ruim é recusado com o mundo intacto.
func _read_document(path: String) -> Dictionary:
	_last_read_reason = ""
	if not FileAccess.file_exists(path):
		_last_read_reason = "arquivo ausente"
		return {}
	var parsed: Variant = CampaignSnapshot.parse_document(_read_text(path))
	var reason := CampaignSnapshot.validate_document(parsed)
	if not reason.is_empty():
		_last_read_reason = reason
		return {}
	var migrated := CampaignSnapshot.migrate_to_current(parsed as Dictionary)
	reason = CampaignSnapshot.validate_document(migrated)
	if not reason.is_empty():
		_last_read_reason = reason
		return {}
	return migrated


func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text


func _write_text(path: String, text: String) -> bool:
	var directory := DirAccess.open("user://")
	if directory != null and not directory.make_dir_recursive(path.get_base_dir()):
		if not directory.dir_exists(path.get_base_dir()):
			return false
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	# §62: o flush é o que separa "escrevi no buffer" de "o disco tem o arquivo".
	file.flush()
	file.close()
	return true


func _fail(operation: String, reason: String) -> void:
	print("SaveGameController: %s recusado — %s" % [operation, reason])
	operation_failed.emit(operation, reason)


# ================================================================== Restauração


## §74: a ordem implementada. Validação já fechou (§67), então aqui só se aplica.
## 1. input de persistência bloqueado (`_is_loading`, no chamador)
## 2. snapshot validado (no chamador)
## 3. seleção e ordens transitórias limpas
## 4. ciclo de vida atual parado e esvaziado
## 5. montes do chão limpos (serão reconstruídos pelo arquivo)
## 6. Núcleo: Definition pelo nível + os números salvos
## 7. Cristal
## 8. Estoque
## 9. Rochas
## 10. Montes de recurso
## 11. Ninho, Quartel e Mina
## 12. Workers
## 13. Soldado
## 14. Invasion
## 15. Evolução derivada
## 16. refresh dos painéis (no `load_succeeded` da composition root)
## 17. input liberado (no chamador)
func _apply(campaign: Dictionary) -> void:
	var world: Dictionary = campaign[CampaignSnapshot.SECTION_WORLD]
	var progression: Dictionary = campaign[CampaignSnapshot.SECTION_PROGRESSION]
	var crystal: Dictionary = progression[CampaignSnapshot.KEY_CRYSTAL]
	_selection.reset_transient_input()
	_invasion.restore_lifecycle(InvasionController.InvasionState.NOT_STARTED, 0.0, [])
	_clear_piles()
	_restore_core(campaign)
	_crystal.restore(int(crystal[CampaignSnapshot.KEY_AMOUNT]))
	_restore_stockpile(campaign)
	_restore_rocks(world[CampaignSnapshot.KEY_ROCKS] as Array)
	_restore_piles(world[CampaignSnapshot.KEY_PILES] as Array)
	_restore_constructions(campaign)
	_restore_units(campaign)
	_restore_invasion(campaign)
	_evolution.restore_progression(
			campaign[CampaignSnapshot.SECTION_INVASION][KEY_INVASION_STATE] == "VICTORY")


## §18/§19: o Núcleo que já está em cena é restaurado — não se recria um segundo Núcleo.
## A Definition vem do nível gravado, então Integrity máxima, Essência máxima e taxa de
## geração voltam como dados de 2026-09-29, e não como números copiados do arquivo.
func _restore_core(campaign: Dictionary) -> void:
	var core: Dictionary = campaign[CampaignSnapshot.SECTION_CORE]
	var definition: CoreDefinition = _core_definitions_by_level[int(core[CampaignSnapshot.KEY_LEVEL])]
	_core_state.restore_persistent_state(
			definition,
			float(core[CampaignSnapshot.KEY_INTEGRITY]),
			float(core[CampaignSnapshot.KEY_ESSENCE]),
			int(core[CampaignSnapshot.KEY_POPULATION]),
			int(core[CampaignSnapshot.KEY_CAPACITY_BONUS]))
	_core.restore_level_view(definition)


## §22/§78: o estoque troca de conteúdo de uma vez, com sinal por recurso já no valor
## final. Não é `add_resource` em loop, que contaria transações de gameplay.
func _restore_stockpile(campaign: Dictionary) -> void:
	var amounts: Dictionary = {}
	var stockpile: Dictionary = campaign[CampaignSnapshot.SECTION_ECONOMY][
			CampaignSnapshot.KEY_STOCKPILE]
	for resource_id in stockpile:
		amounts[_definitions_by_resource_id[resource_id]] = int(stockpile[resource_id])
	_stockpile.replace_contents(amounts)


func _restore_rocks(rocks: Array) -> void:
	var by_id: Dictionary = {}
	for record in rocks:
		by_id[String(record[CampaignSnapshot.KEY_ROCK_ID])] = record
	for rock_id in _rock_ledger:
		var entry: Dictionary = _rock_ledger[rock_id]
		var record: Dictionary = by_id[rock_id]
		var remaining := float(record[CampaignSnapshot.KEY_REMAINING_WORK])
		# §85/T18: o ledger guarda o Node canônico, e a Rocha escavada deixou de ser um Node
		# vivo. Fazer `as RockRuntime` sobre essa referência pendurada aborta a função inteira
		# no meio do laço — que é exatamente a meia aplicação que §67 proíbe. A vida é medida
		# na Variant, sem cast; o cast só acontece no Node que ainda existe.
		var stored: Variant = entry["rock"]
		var alive := stored != null and is_instance_valid(stored)
		if alive:
			alive = not (stored as RockRuntime).is_queued_for_deletion()
		if record[CampaignSnapshot.KEY_EXCAVATED]:
			# §40/§86: Rocha paga no arquivo não reaparece no mundo.
			if alive:
				(stored as RockRuntime).queue_free()
			entry["rock"] = null
			(entry["state"] as RockState).restore_remaining_work(0.0)
			continue
		var runtime: RockRuntime = null
		if not alive:
			# §41/§85: uma Rocha que a partida em curso já havia escavado volta como o
			# Runtime novo da cena canônica, na posição original do ledger. O State antigo
			# é trocado por um novo: o Node libertado continua conectado ao dele, e two
			# donos para o mesmo `excavated` seria erro de carga.
			runtime = _create_rock(String(rock_id), entry["definition"] as RockDefinition)
			entry["rock"] = runtime
			entry["position"] = runtime.global_position
		else:
			runtime = stored as RockRuntime
			runtime.global_position = entry["position"]
		(entry["state"] as RockState).restore_remaining_work(remaining)


func _create_rock(rock_id: String, definition: RockDefinition) -> RockRuntime:
	var rock := _rock_scene.instantiate() as RockRuntime
	rock.rock_id = rock_id
	_dungeon.add_child(rock)
	var state := RockState.new(definition, rock_id)
	_rock_ledger[rock_id]["state"] = state
	rock.setup(definition, state)
	rock.resource_drop_requested.connect(spawn_resource_pile)
	return rock


func _clear_piles() -> void:
	for child in _dungeon.get_children():
		if child is ResourcePileRuntime:
			child.queue_free()


func _restore_piles(piles: Array) -> void:
	for record in piles:
		spawn_resource_pile(
				_definitions_by_resource_id[String(record[CampaignSnapshot.KEY_RESOURCE_ID])],
				int(record[CampaignSnapshot.KEY_AMOUNT]),
				CampaignSnapshot.decode_position(record[CampaignSnapshot.KEY_POSITION]),
				String(record[CampaignSnapshot.KEY_PILE_ID]).trim_suffix("_drop"))


## §32/§33/§36: a obra volta montada, com o trabalho restante do arquivo. Nenhuma
## conclusão é reemitida, então o bônus populacional do Ninho pronto não é reaplicado —
## ele já veio nos números do CoreState.
func _restore_constructions(campaign: Dictionary) -> void:
	var constructions: Dictionary = campaign[CampaignSnapshot.SECTION_CONSTRUCTIONS]
	_restore_site(constructions[CampaignSnapshot.SECTION_NEST] as Dictionary,
			_construction.restore_nest)
	_restore_site(constructions[CampaignSnapshot.SECTION_BARRACKS] as Dictionary,
			_construction.restore_barracks)
	_restore_mine(constructions[CampaignSnapshot.SECTION_MINE] as Dictionary)
	_restore_fungal_farm(constructions[CampaignSnapshot.SECTION_FUNGAL_FARM] as Dictionary)


## §63/§64/T20: a Mina tem rota própria porque tem um quarto número — o relógio de
## produção — que as outras obras não têm. A ausência dela desmonta a obra sem cobrar e
## sem emitir conquista; a presença dela devolve trabalho e elapsed exatamente como foram
## gravados, e é `restore_mine()` que decide se o processo de produção liga.
func _restore_mine(site: Dictionary) -> void:
	if not bool(site.get(CampaignSnapshot.KEY_EXISTS, false)):
		_construction.restore_mine(false, 0.0, Vector3.ZERO, 0.0)
		return
	_construction.restore_mine(true,
			float(site[CampaignSnapshot.KEY_REMAINING_WORK]),
			CampaignSnapshot.decode_position(site[CampaignSnapshot.KEY_POSITION]),
			float(site[CampaignSnapshot.KEY_PRODUCTION_ELAPSED]))


## §63/§64/T21: a Fazenda tem rota própria pela mesma razão da Mina — o relógio de produção.
## A ausência dela desmonta a obra sem cobrar e sem emitir conquista; a presença dela devolve
## trabalho e elapsed exatamente como foram gravados, e é `restore_fungal_farm()` que decide
## se o processo de produção liga.
func _restore_fungal_farm(site: Dictionary) -> void:
	if not bool(site.get(CampaignSnapshot.KEY_EXISTS, false)):
		_construction.restore_fungal_farm(false, 0.0, Vector3.ZERO, 0.0)
		return
	_construction.restore_fungal_farm(true,
			float(site[CampaignSnapshot.KEY_REMAINING_WORK]),
			CampaignSnapshot.decode_position(site[CampaignSnapshot.KEY_POSITION]),
			float(site[CampaignSnapshot.KEY_PRODUCTION_ELAPSED]))


func _restore_site(site: Dictionary, restore: Callable) -> void:
	if not bool(site.get(CampaignSnapshot.KEY_EXISTS, false)):
		restore.call(false, 0.0, Vector3.ZERO)
		return
	restore.call(true,
			float(site[CampaignSnapshot.KEY_REMAINING_WORK]),
			CampaignSnapshot.decode_position(site[CampaignSnapshot.KEY_POSITION]))


func _restore_units(campaign: Dictionary) -> void:
	var units: Dictionary = campaign[CampaignSnapshot.SECTION_UNITS]
	var records: Array = units[CampaignSnapshot.KEY_WORKERS] as Array
	for record in records:
		_restore_scene_worker(record as Dictionary)
	_restore_second_worker(units[CampaignSnapshot.KEY_SECOND_SUMMONED], records)
	var soldier: Dictionary = units[CampaignSnapshot.KEY_SOLDIER]
	_recruitment.restore_soldier(
			soldier[CampaignSnapshot.KEY_RECRUITED],
			soldier[CampaignSnapshot.KEY_ALIVE],
			float(soldier.get(CampaignSnapshot.KEY_HEALTH, 1.0)),
			int(soldier.get(CampaignSnapshot.KEY_LEVEL, 1)),
			float(soldier.get(CampaignSnapshot.KEY_EXPERIENCE, 0.0)),
			CampaignSnapshot.decode_position(soldier[CampaignSnapshot.KEY_POSITION])
					if soldier[CampaignSnapshot.KEY_ALIVE] else Vector3.ZERO)


## §23/§84: o Worker da cena é restaurado no próprio Runtime — Núcleo e Worker001 são da
## SceneTree canônica, e a ausência deles significa campanha corrompida, não coisa a
## recriar. O segundo Worker tem dono próprio e passa pela rota de invocação.
func _restore_scene_worker(record: Dictionary) -> void:
	var unit_id := String(record[CampaignSnapshot.KEY_UNIT_ID])
	if unit_id == CampaignSnapshot.SECOND_WORKER_ID:
		return
	var runtime := _find_worker(unit_id)
	if runtime == null:
		return
	runtime.state.restore_persistent_state(
			float(record[CampaignSnapshot.KEY_HEALTH]),
			int(record[CampaignSnapshot.KEY_LEVEL]),
			float(record[CampaignSnapshot.KEY_EXPERIENCE]),
			_cargo_of(record),
			int(record[CampaignSnapshot.KEY_CARRIED_AMOUNT]))
	runtime.global_position = CampaignSnapshot.decode_position(
			record[CampaignSnapshot.KEY_POSITION])
	runtime.reset_transient_order()


## §26/§33: `worker_002_summoned` volta como o dado que o arquivo guarda, e o Runtime só
## existe se houver registro dele. As duas metades são independentes justamente porque a
## flag histórica sobrevive à morte da unidade.
func _restore_second_worker(ever_summoned: Variant, records: Array) -> void:
	_invocation.restore_second_worker_history(bool(ever_summoned))
	var found: Dictionary = {}
	for entry in records:
		if String(entry[CampaignSnapshot.KEY_UNIT_ID]) == CampaignSnapshot.SECOND_WORKER_ID:
			found = entry as Dictionary
			break
	if found.is_empty():
		_invocation.remove_summoned_worker()
		return
	_invocation.restore_summoned_worker(
			float(found[CampaignSnapshot.KEY_HEALTH]),
			int(found[CampaignSnapshot.KEY_LEVEL]),
			float(found[CampaignSnapshot.KEY_EXPERIENCE]),
			_cargo_of(found),
			int(found[CampaignSnapshot.KEY_CARRIED_AMOUNT]),
			CampaignSnapshot.decode_position(found[CampaignSnapshot.KEY_POSITION]))


## §25: o recurso carregado é o id do arquivo resolvido contra a whitelist injetada.
func _cargo_of(record: Dictionary) -> ResourceDefinition:
	var cargo_id: Variant = record[CampaignSnapshot.KEY_CARRIED_RESOURCE]
	if cargo_id == null:
		return null
	return _definitions_by_resource_id[cargo_id] as ResourceDefinition


func _find_worker(unit_id: String) -> WorkerRuntime:
	for child in _dungeon.get_children():
		var runtime := child as WorkerRuntime
		if runtime != null and not runtime.is_queued_for_deletion() \
				and runtime.state.unit_id == unit_id:
			return runtime
	return null


## §46/§49/§51/§52: o ciclo volta pelo dado. PREPARATION retoma o segundo exato, ACTIVE
## recria só os vivos e cada um retoma ADVANCE, VICTORY e DEFEAT voltam terminais e sem
## recompensa — quem concede a chave é o `_on_invader_died` da vida real, não a carga.
func _restore_invasion(campaign: Dictionary) -> void:
	var invasion: Dictionary = campaign[CampaignSnapshot.SECTION_INVASION]
	var records: Array = []
	for invader in invasion[CampaignSnapshot.KEY_INVADERS] as Array:
		records.append({
			CampaignSnapshot.KEY_INVADER_ID: String(invader[CampaignSnapshot.KEY_INVADER_ID]),
			CampaignSnapshot.KEY_HEALTH: float(invader[CampaignSnapshot.KEY_HEALTH]),
			CampaignSnapshot.KEY_POSITION:
					CampaignSnapshot.decode_position(invader[CampaignSnapshot.KEY_POSITION]),
		})
	_invasion.restore_lifecycle(
			invasion_state_of(String(invasion[KEY_INVASION_STATE])),
			float(invasion[CampaignSnapshot.KEY_PREPARATION_REMAINING]),
			records)
