class_name CampaignSnapshot
extends RefCounted

## Tarefa 18 — §6/§7/§9/§69: o contrato do arquivo de campanha. Esta classe sabe a forma
## do JSON, os nomes das seções e o que é um valor estruturalmente sadio; ela não conhece
## Domain, não lê Definition nenhuma e não toca em Node. Quem resolve identidades e faixa
## contra os máximos do domínio é o SaveGameController, dono da whitelist (§16/§70).
##
## §13: aqui só entram Dictionary, Array, String, int, float, bool e null. Vector3 é
## codificado como três números explícitos e reconstruído na carga — nunca se grava um
## Resource, um Node ou um caminho de arquivo escolhido pelo Save.

const SAVE_FORMAT := "abyss_lord_campaign"
## §7: a única versão existente. §8: arquivo de outra versão é recusado sem adivinhação.
const SAVE_VERSION := 1

const ROOT_FORMAT := "format"
const ROOT_VERSION := "save_version"
const ROOT_METADATA := "metadata"
const ROOT_CAMPAIGN := "campaign"

## §140: as sete seções do documento, todas obrigatórias (§69).
const SECTION_CORE := "core"
const SECTION_PROGRESSION := "progression"
const SECTION_ECONOMY := "economy"
const SECTION_UNITS := "units"
const SECTION_CONSTRUCTIONS := "constructions"
const SECTION_WORLD := "world"
const SECTION_INVASION := "invasion"

## §30/§34: as duas obras têm chave e id próprios, e o arquivo os nomeia por inteiro.
const SECTION_NEST := "nest"
const SECTION_BARRACKS := "barracks"

const INVASION_STATE_NAMES: Array[String] = [
	"NOT_STARTED", "PREPARATION", "ACTIVE", "VICTORY", "DEFEAT"]

## §14: as identidades semânticas da campanha. Nada aqui é instance_id de Node.
const CORE_ID := "main_core"
const FIRST_WORKER_ID := "worker_001"
const SECOND_WORKER_ID := "worker_002"
const SOLDIER_ID := "soldier_001"
const NEST_ID := "nest_001"
const BARRACKS_ID := "barracks_001"

## §17/§21/§30/§37/§48: os nomes de campo, uma única vez.
const KEY_LEVEL := "level"
const KEY_INTEGRITY := "integrity"
const KEY_ESSENCE := "essence"
const KEY_POPULATION := "population"
const KEY_CAPACITY_BONUS := "population_capacity_bonus"
const KEY_CRYSTAL := "abyssal_crystal"
const KEY_AMOUNT := "amount"
const KEY_STOCKPILE := "stockpile"
const KEY_WORKERS := "workers"
const KEY_SECOND_SUMMONED := "worker_002_summoned"
const KEY_SOLDIER := "soldier"
const KEY_RECRUITED := "recruited"
const KEY_ALIVE := "alive"
const KEY_UNIT_ID := "unit_id"
const KEY_UNIT_TYPE_ID := "unit_type_id"
const KEY_HEALTH := "health"
const KEY_EXPERIENCE := "experience"
const KEY_POSITION := "position"
const KEY_CARRIED_RESOURCE := "carried_resource"
const KEY_CARRIED_AMOUNT := "carried_amount"
const KEY_EXISTS := "exists"
const KEY_REMAINING_WORK := "remaining_work"
const KEY_ROCKS := "rocks"
const KEY_ROCK_ID := "rock_id"
const KEY_EXCAVATED := "excavated"
const KEY_PILES := "piles"
const KEY_PILE_ID := "pile_id"
const KEY_RESOURCE_ID := "resource_id"
const KEY_STATE := "state"
const KEY_PREPARATION_REMAINING := "preparation_time_remaining"
const KEY_INVADERS := "invaders"
const KEY_INVADER_ID := "invader_id"
const KEY_ENEMY_TYPE_ID := "enemy_type_id"


## §6: o envelope. `metadata` é informativo (§72) e nunca é requisito de gameplay.
static func build_document(campaign: Dictionary, metadata: Dictionary) -> Dictionary:
	return {
		ROOT_FORMAT: SAVE_FORMAT,
		ROOT_VERSION: SAVE_VERSION,
		ROOT_METADATA: metadata,
		ROOT_CAMPAIGN: campaign,
	}


static func parse_document(text: String) -> Variant:
	var json := JSON.new()
	if json.parse(text) != OK:
		return null
	return json.data


## Escrita humana: o arquivo do jogador é lível em um editor de texto (§110), por isso o
## recuo faz parte do formato e não é só um detalhe de debug.
static func to_text(document: Dictionary) -> String:
	return JSON.stringify(document, "  ")


static func encode_position(point: Vector3) -> Array:
	return [point.x, point.y, point.z]


## §24: a posição volta exatamente como foi medida, inclusive o Y do solo.
static func decode_position(value: Variant) -> Vector3:
	var coordinates := value as Array
	return Vector3(float(coordinates[0]), float(coordinates[1]), float(coordinates[2]))


## §67/§69: a validação estrutural inteira, antes de qualquer mutação. Devolve String
## vazio quando o documento é aceitável e o motivo da recusa otherwise — é essa frase que
## chega em `operation_failed` (§60) e no console.
static func validate_document(document: Variant) -> String:
	if not (document is Dictionary):
		return "a raiz do arquivo não é um Dictionary"
	var root := document as Dictionary
	if root.get(ROOT_FORMAT) != SAVE_FORMAT:
		return "format desconhecido: %s" % [root.get(ROOT_FORMAT)]
	if not is_supported_version(root.get(ROOT_VERSION)):
		return "save_version não suportado: %s" % [root.get(ROOT_VERSION)]
	var metadata: Variant = root.get(ROOT_METADATA)
	if not (metadata is Dictionary):
		return "metadata não é um Dictionary"
	if not (root.get(ROOT_CAMPAIGN) is Dictionary):
		return "campaign não é um Dictionary"
	var campaign := root[ROOT_CAMPAIGN] as Dictionary
	for section in [SECTION_CORE, SECTION_PROGRESSION, SECTION_ECONOMY, SECTION_UNITS,
			SECTION_CONSTRUCTIONS, SECTION_WORLD, SECTION_INVASION]:
		if not (campaign.get(section) is Dictionary):
			return "seção obrigatória ausente ou inválida: %s" % section
	var reason := _validate_core(campaign)
	if not reason.is_empty():
		return reason
	reason = _validate_progression(campaign)
	if not reason.is_empty():
		return reason
	reason = _validate_economy(campaign)
	if not reason.is_empty():
		return reason
	reason = _validate_units(campaign)
	if not reason.is_empty():
		return reason
	reason = _validate_constructions(campaign)
	if not reason.is_empty():
		return reason
	reason = _validate_world(campaign)
	if not reason.is_empty():
		return reason
	return _validate_invasion(campaign)


## §8: só a versão 1 existe. Uma migration não é implementada antes de haver v2 (§119).
static func is_supported_version(value: Variant) -> bool:
	return _is_integral(value) and int(value) == SAVE_VERSION


static func _validate_core(campaign: Dictionary) -> String:
	var core := campaign[SECTION_CORE] as Dictionary
	if core.get("core_id") != CORE_ID:
		return "core_id desconhecido: %s" % [core.get("core_id")]
	if not _is_int(core, KEY_LEVEL) or not _is_number(core, KEY_INTEGRITY) \
			or not _is_number(core, KEY_ESSENCE) or not _is_int(core, KEY_POPULATION) \
			or not _is_int(core, KEY_CAPACITY_BONUS):
		return "core tem campo ausente ou de tipo errado"
	if core[KEY_INTEGRITY] < 0.0 or core[KEY_ESSENCE] < 0.0 \
			or core[KEY_POPULATION] < 0 or core[KEY_CAPACITY_BONUS] < 0:
		return "core tem valor negativo"
	return ""


static func _validate_progression(campaign: Dictionary) -> String:
	var crystal: Variant = (campaign[SECTION_PROGRESSION] as Dictionary).get(KEY_CRYSTAL)
	if not (crystal is Dictionary):
		return "progression.abyssal_crystal está ausente"
	var crystal_section := crystal as Dictionary
	if not _is_int(crystal_section, KEY_AMOUNT) or crystal_section[KEY_AMOUNT] < 0:
		return "progression.abyssal_crystal.amount precisa ser um inteiro não negativo"
	return ""


## §22: o estoque é um mapa de resource_id → quantidade. Zero é ausência, não saldo.
static func _validate_economy(campaign: Dictionary) -> String:
	var stockpile: Variant = (campaign[SECTION_ECONOMY] as Dictionary).get(KEY_STOCKPILE)
	if not (stockpile is Dictionary):
		return "economy.stockpile está ausente"
	var amounts := stockpile as Dictionary
	for resource_id in amounts:
		if not (resource_id is String):
			return "economy.stockpile tem chave que não é resource_id"
		if not _is_int(amounts, String(resource_id)) or amounts[resource_id] < 0:
			return "economy.stockpile.%s precisa ser um inteiro não negativo" % resource_id
	return ""


## §23/§25/§26/§27/§28: os registros de unidade. O Worker da cena é a identidade que a
## campanha sempre tem — §84 não recria Núcleo nem Worker001, portanto um arquivo sem ele
## é campanha corrompida, não partida nova.
static func _validate_units(campaign: Dictionary) -> String:
	var units := campaign[SECTION_UNITS] as Dictionary
	if not _is_array(units, KEY_WORKERS) or not _is_bool(units, KEY_SECOND_SUMMONED) \
			or not (units.get(KEY_SOLDIER) is Dictionary):
		return "units precisa de workers, worker_002_summoned e soldier"
	var has_scene_worker := false
	for worker in units[KEY_WORKERS] as Array:
		var reason := _validate_worker(worker)
		if not reason.is_empty():
			return reason
		if (worker as Dictionary)[KEY_UNIT_ID] == FIRST_WORKER_ID:
			has_scene_worker = true
	if not has_scene_worker:
		return "units não registra %s" % FIRST_WORKER_ID
	return _validate_soldier(units[KEY_SOLDIER] as Dictionary)


static func _validate_worker(worker: Variant) -> String:
	if not (worker is Dictionary):
		return "workers tem entrada que não é um registro"
	var entry := worker as Dictionary
	if entry.get(KEY_UNIT_ID) != FIRST_WORKER_ID and entry.get(KEY_UNIT_ID) != SECOND_WORKER_ID:
		return "unit_id de Worker desconhecido: %s" % [entry.get(KEY_UNIT_ID)]
	if not _is_string(entry, KEY_UNIT_TYPE_ID) or not _is_number(entry, KEY_HEALTH) \
			or not _is_int(entry, KEY_LEVEL) or not _is_number(entry, KEY_EXPERIENCE) \
			or not _is_position(entry) or not _is_int(entry, KEY_CARRIED_AMOUNT):
		return "%s tem campo ausente ou de tipo errado" % entry.get(KEY_UNIT_ID)
	var cargo: Variant = entry.get(KEY_CARRIED_RESOURCE)
	if not (cargo is String) and cargo != null:
		return "%s tem carried_resource que não é id nem null" % entry.get(KEY_UNIT_ID)
	if entry[KEY_HEALTH] <= 0.0 or entry[KEY_LEVEL] < 1 or entry[KEY_EXPERIENCE] < 0.0 \
			or entry[KEY_CARRIED_AMOUNT] < 0:
		return "%s tem valor fora da faixa" % entry.get(KEY_UNIT_ID)
	if entry[KEY_CARRIED_AMOUNT] > 0 and not (cargo is String):
		return "%s carrega sem recurso" % entry.get(KEY_UNIT_ID)
	if entry[KEY_CARRIED_AMOUNT] == 0 and cargo != null:
		return "%s tem recurso sem carga" % entry.get(KEY_UNIT_ID)
	return ""


static func _validate_soldier(soldier: Dictionary) -> String:
	if not _is_bool(soldier, KEY_RECRUITED) or not _is_bool(soldier, KEY_ALIVE):
		return "soldier precisa de recruited e alive"
	if not soldier[KEY_RECRUITED]:
		if soldier[KEY_ALIVE]:
			return "soldier vivo sem recrutamento registrado"
		return ""
	if not soldier[KEY_ALIVE]:
		return ""
	if soldier.get(KEY_UNIT_ID) != SOLDIER_ID:
		return "unit_id do Soldado desconhecido: %s" % [soldier.get(KEY_UNIT_ID)]
	if not _is_string(soldier, KEY_UNIT_TYPE_ID) or not _is_number(soldier, KEY_HEALTH) \
			or not _is_int(soldier, KEY_LEVEL) or not _is_number(soldier, KEY_EXPERIENCE) \
			or not _is_position(soldier):
		return "soldier tem campo ausente ou de tipo errado"
	if soldier[KEY_HEALTH] <= 0.0 or soldier[KEY_LEVEL] < 1 \
			or soldier[KEY_EXPERIENCE] < 0.0:
		return "soldier tem valor fora da faixa"
	return ""


## §30/§31/§34: uma construção existe com id semântico, trabalho restante e posição.
## `completed` é derivado (§123) e por isso não é campo do arquivo.
static func _validate_constructions(campaign: Dictionary) -> String:
	var constructions := campaign[SECTION_CONSTRUCTIONS] as Dictionary
	var reason := _validate_site(constructions.get(SECTION_NEST), "nest", NEST_ID)
	if not reason.is_empty():
		return reason
	return _validate_site(constructions.get(SECTION_BARRACKS), "barracks", BARRACKS_ID)


static func _validate_site(site: Variant, field: String, instance_id: String) -> String:
	if not (site is Dictionary):
		return "constructions.%s está ausente" % field
	var data := site as Dictionary
	if not _is_bool(data, KEY_EXISTS):
		return "constructions.%s precisa de exists" % field
	if not data[KEY_EXISTS]:
		return ""
	if data.get(field + "_id") != instance_id or not _is_number(data, KEY_REMAINING_WORK) \
			or not _is_position(data):
		return "constructions.%s é incompleto ou tem id errado" % field
	if data[KEY_REMAINING_WORK] < 0.0:
		return "constructions.%s tem trabalho negativo" % field
	return ""


## §37/§42: o mundo guarda o livro-razão das Rochas e os montes vivos.
static func _validate_world(campaign: Dictionary) -> String:
	var world := campaign[SECTION_WORLD] as Dictionary
	if not _is_array(world, KEY_ROCKS) or not _is_array(world, KEY_PILES):
		return "world precisa de rocks e piles"
	var seen_ids: Array = []
	for rock in world[KEY_ROCKS]:
		if not (rock is Dictionary):
			return "world.rocks tem entrada que não é um registro"
		var entry := rock as Dictionary
		if not _is_string(entry, KEY_ROCK_ID) or not _is_bool(entry, KEY_EXCAVATED) \
				or not _is_number(entry, KEY_REMAINING_WORK):
			return "world.rocks tem registro incompleto"
		if entry[KEY_ROCK_ID] == "" or seen_ids.has(entry[KEY_ROCK_ID]):
			return "world.rocks tem rock_id repetido ou vazio"
		seen_ids.append(entry[KEY_ROCK_ID])
		if entry[KEY_REMAINING_WORK] < 0.0:
			return "%s tem trabalho negativo" % entry[KEY_ROCK_ID]
		if entry[KEY_EXCAVATED] and entry[KEY_REMAINING_WORK] > 0.0:
			return "%s está escavada com trabalho restante" % entry[KEY_ROCK_ID]
	for pile in world[KEY_PILES]:
		if not (pile is Dictionary):
			return "world.piles tem entrada que não é um registro"
		var stored := pile as Dictionary
		if not _is_string(stored, KEY_PILE_ID) or not _is_string(stored, KEY_RESOURCE_ID) \
				or not _is_int(stored, KEY_AMOUNT) or not _is_position(stored):
			return "world.piles tem registro incompleto"
		if stored[KEY_PILE_ID] == "" or stored[KEY_RESOURCE_ID] == "":
			return "world.piles tem id vazio"
		# §44/§70: monte zerado não é estado de campanha — rejeitar, não normalizar.
		if stored[KEY_AMOUNT] <= 0:
			return "%s é um monte sem recurso" % stored[KEY_PILE_ID]
	return ""


## §45/§46/§48: o ciclo de vida é texto legível, e o tempo volta em segundos.
static func _validate_invasion(campaign: Dictionary) -> String:
	var invasion := campaign[SECTION_INVASION] as Dictionary
	if not _is_string(invasion, KEY_STATE) or not INVASION_STATE_NAMES.has(invasion[KEY_STATE]):
		return "invasion.state desconhecido: %s" % [invasion.get(KEY_STATE)]
	if not _is_number(invasion, KEY_PREPARATION_REMAINING) \
			or invasion[KEY_PREPARATION_REMAINING] < 0.0:
		return "invasion.preparation_time_remaining precisa ser um número não negativo"
	if not _is_array(invasion, KEY_INVADERS):
		return "invasion precisa de invaders"
	var seen_ids: Array = []
	for invader in invasion[KEY_INVADERS]:
		if not (invader is Dictionary):
			return "invasion.invaders tem entrada que não é um registro"
		var entry := invader as Dictionary
		if not _is_string(entry, KEY_INVADER_ID) or not _is_string(entry, KEY_ENEMY_TYPE_ID) \
				or not _is_number(entry, KEY_HEALTH) or not _is_position(entry):
			return "invasion.invaders tem registro incompleto"
		if seen_ids.has(entry[KEY_INVADER_ID]):
			return "invasion.invaders tem invader_id repetido"
		seen_ids.append(entry[KEY_INVADER_ID])
		if entry[KEY_HEALTH] <= 0.0:
			return "%s é um invasor sem vida" % entry[KEY_INVADER_ID]
	return ""


static func _is_number(source: Dictionary, key: String) -> bool:
	return source.has(key) and (source[key] is int or source[key] is float)


## §13/T18: `int` do contrato é "número sem parte fracionária". O `JSON` do Godot devolve
## float para todo número lido — `1` no arquivo chega como `1.0` —, então exigir
## `is int` depois de um parse recusaria um save perfeitamente bom. O que não é aceito é
## fração: nível, montante e população meio inteiro não existem nesta campanha.
static func _is_integral(value: Variant) -> bool:
	if value is int:
		return true
	if not (value is float):
		return false
	return value == floorf(value)


static func _is_int(source: Dictionary, key: String) -> bool:
	return source.has(key) and _is_integral(source[key])


static func _is_bool(source: Dictionary, key: String) -> bool:
	return source.has(key) and source[key] is bool


static func _is_string(source: Dictionary, key: String) -> bool:
	return source.has(key) and source[key] is String


static func _is_array(source: Dictionary, key: String) -> bool:
	return source.has(key) and source[key] is Array


static func _is_position(source: Dictionary) -> bool:
	var position: Variant = source.get(KEY_POSITION)
	if not (position is Array) or (position as Array).size() != 3:
		return false
	for coordinate in position:
		if not (coordinate is int or coordinate is float):
			return false
	return true
