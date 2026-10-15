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
## §45/T20: a Mina acrescenta estado persistente novo, então o formato escrito é o V2.
## §45/T21: a Fazenda Fúngica acrescenta a quarta obra, então o formato escrito passa a ser o
## V3. §56: V1 e V2 continuam sendo lidos — através da cadeia de migração explícita abaixo —
## e nunca escritos. §58: suporte é lista nominal, não "qualquer número inteiro": V0 e V4/999
## são recusados.
## T22: o terceiro Trabalhador (expansão por Biomassa) acrescenta estado persistente novo —
## a flag histórica `worker_003_summoned` e o registro `worker_003` —, então o formato escrito
## passa a ser o V4. V1, V2 e V3 continuam sendo lidos pela mesma corrente explícita, um
## degrau por versão, e nunca escritos. V0 e V5/999 são recusados.
## T23: a superfície (Notoriedade e a primeira Incursão) acrescenta a seção `surface`, e o
## formato escrito passa a ser o V5. V0 e V6/999 são recusados.
## T24: o primeiro Povo Nativo (selo, Legitimidade, pedidos, juramento e Guardião) acrescenta
## a seção `natives`, e o formato escrito passa a ser o V6. V0 e V7/999 são recusados.
## T25: as incursões recorrentes acrescentam número, tamanho da guilda e calmaria à
## `surface.incursion`, e o formato escrito passa a ser o V7. V0 e V8/999 são recusados.
## T26: o Cristal da primeira guilda inteiramente repelida é um marco histórico, e a flag que o
## registra entra em `surface`. O formato escrito passa a ser o V8; V0 e V9/999 são recusados.
## O Núcleo Nv.3 não precisa de campo novo: `core.level` já o diz.
const SAVE_VERSION := 8
const SAVE_VERSION_V1 := 1
const SAVE_VERSION_V2 := 2
const SAVE_VERSION_V3 := 3
const SAVE_VERSION_V4 := 4
const SAVE_VERSION_V5 := 5
const SAVE_VERSION_V6 := 6
const SAVE_VERSION_V7 := 7
const SUPPORTED_VERSIONS: Array[int] = [SAVE_VERSION_V1, SAVE_VERSION_V2, SAVE_VERSION_V3,
		SAVE_VERSION_V4, SAVE_VERSION_V5, SAVE_VERSION_V6, SAVE_VERSION_V7, SAVE_VERSION]

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
## T23: a oitava seção, só do V5 em diante. As sete do V1 continuam obrigatórias em todas.
const SECTION_SURFACE := "surface"
## T24: a nona seção, só do V6 em diante, e o registro do único povo da tarefa.
const SECTION_NATIVES := "natives"
const NATIVE_PEOPLE_ID := "decapitated_guard"

## §30/§34: cada obra tem chave e id próprios, e o arquivo os nomeia por inteiro.
## §48/T20: `mine` entra como terceira chave de `constructions`, no mesmo formato.
## §47/T21: `fungal_farm` entra como quarta chave, também no mesmo formato.
const SECTION_NEST := "nest"
const SECTION_BARRACKS := "barracks"
const SECTION_MINE := "mine"
const SECTION_FUNGAL_FARM := "fungal_farm"

const INVASION_STATE_NAMES: Array[String] = [
	"NOT_STARTED", "PREPARATION", "ACTIVE", "VICTORY", "DEFEAT"]
## T23: o ciclo da Incursão da Superfície e as fases do saqueador, por nome.
const INCURSION_STATE_NAMES: Array[String] = ["NOT_STARTED", "PREPARATION", "ACTIVE", "ENDED"]
const RAIDER_PHASE_NAMES: Array[String] = ["APPROACH", "LOOT", "RETREAT"]

## §14: as identidades semânticas da campanha. Nada aqui é instance_id de Node.
const CORE_ID := "main_core"
const FIRST_WORKER_ID := "worker_001"
const SECOND_WORKER_ID := "worker_002"
## T22: a identidade semântica do terceiro Trabalhador. Só o V4 a aceita.
const THIRD_WORKER_ID := "worker_003"
const SOLDIER_ID := "soldier_001"
const NEST_ID := "nest_001"
const BARRACKS_ID := "barracks_001"
## §25/§48/T20: a identidade semântica da única Mina da tarefa.
const MINE_ID := "mine_001"
## §25/§48/T21: a identidade semântica da única Fazenda Fúngica da tarefa.
const FUNGAL_FARM_ID := "fungal_farm_001"

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
## T22: a flag histórica da expansão — mesmo papel da do segundo Worker.
const KEY_THIRD_SUMMONED := "worker_003_summoned"
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
## §49/T20: o relógio da Mina é estado temporal persistente. Intervalo, montante e recurso
## produzidos são configuração da MineDefinition e por isso nunca aparecem no arquivo.
const KEY_PRODUCTION_ELAPSED := "production_elapsed"
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
## T23: os campos da superfície.
const KEY_NOTORIETY := "notoriety"
const KEY_INCURSION := "incursion"
const KEY_RAIDERS := "raiders"
const KEY_RAIDER_ID := "raider_id"
const KEY_PHASE := "phase"
const KEY_LOOT := "loot"
const KEY_REPELLED := "repelled"
const KEY_ESCAPED := "escaped"
## T23: o limiar de Notoriedade que a migração V4→V5 reconhece num Núcleo Nv.2 — o mesmo
## fato que, jogado, soma esse valor (SurfaceIncursionController.NOTORIETY_CORE_LEVEL_TWO).
const MIGRATED_LEVEL_TWO_NOTORIETY := 20
## T24: os campos do povo.
const KEY_SEAL_WORK_DONE := "seal_work_done"
const KEY_LEGITIMACY := "legitimacy"
const KEY_REQUESTS_FULFILLED := "requests_fulfilled"
const KEY_OATH_SWORN := "oath_sworn"
const KEY_GUARDIAN := "guardian"
## T25: os campos das incursões recorrentes.
const KEY_INCURSION_NUMBER := "incursion_number"
const KEY_GUILD_SIZE := "guild_size"
const KEY_COOLDOWN_REMAINING := "cooldown_remaining"
## T25: o tamanho da guilda que a Tarefa 23 sempre largou — o que um V6 migrado registra.
const MIGRATED_GUILD_SIZE := 2
## T26: a flag do Cristal da guilda inteiramente repelida.
const KEY_CLEAN_REPEL_MILESTONE := "clean_repel_milestone"


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
##
## §55/§60/T20: o documento é validado contra o schema da versão que ele mesmo declara.
## Um V1 bom continua sendo aceito como V1; o que transforma ele em V2 é a migração
## explícita abaixo, nunca uma condescendência do validador.
static func validate_document(document: Variant) -> String:
	var reason := _validate_envelope(document)
	if not reason.is_empty():
		return reason
	var root := document as Dictionary
	var campaign := root[ROOT_CAMPAIGN] as Dictionary
	var version := int(root[ROOT_VERSION])
	if version == SAVE_VERSION_V1:
		return validate_v1(campaign)
	if version == SAVE_VERSION_V2:
		return validate_v2(campaign)
	if version == SAVE_VERSION_V3:
		return validate_v3(campaign)
	if version == SAVE_VERSION_V4:
		return validate_v4(campaign)
	if version == SAVE_VERSION_V5:
		return validate_v5(campaign)
	if version == SAVE_VERSION_V6:
		return validate_v6(campaign)
	if version == SAVE_VERSION_V7:
		return validate_v7(campaign)
	return validate_v8(campaign)


## §73: o V1 é o formato congelado em docs/SAVE_SCHEMA_V1.md — duas obras e nenhum relógio
## de produção. Ele não ganha campo novo aqui: quem acrescenta o estado da Mina é a
## migração, e o resultado dela passa a ser validado como V2.
static func validate_v1(campaign: Dictionary) -> String:
	return _validate_sections(campaign)


## §47: V2 é o V1 inteiro mais `constructions.mine`. Nenhum campo antigo muda de nome, de
## tipo ou de significado — é acréscimo, não releitura.
##
## §47/T21: V2 continua sendo o V2 congelado; quem acrescenta a Fazenda é a migração V2→V3.
## Validar V2 aqui é validar o V2 que existia antes desta tarefa, e nunca um V2 "tolerante"
## que aceitaria a chave nova.
static func validate_v2(campaign: Dictionary) -> String:
	var reason := _validate_sections(campaign)
	if not reason.is_empty():
		return reason
	return _validate_mine(campaign)


## §47/T21: V3 é o V2 inteiro mais `constructions.fungal_farm`. Nenhum campo de V1 nem de V2
## muda de nome, de tipo ou de significado.
static func validate_v3(campaign: Dictionary) -> String:
	var reason := _validate_sections(campaign)
	if not reason.is_empty():
		return reason
	reason = _validate_mine(campaign)
	if not reason.is_empty():
		return reason
	return _validate_fungal_farm(campaign)


## T22: V4 é o V3 inteiro mais `units.worker_003_summoned` e a permissão de um registro
## `worker_003` em `units.workers`. Nenhum campo de V1, V2 ou V3 muda de nome, de tipo ou de
## significado. Um registro do terceiro Worker sem a flag histórica é contradição — a unidade
## não pode existir sem ter sido invocada — e é recusado aqui, antes de qualquer domínio.
static func validate_v4(campaign: Dictionary) -> String:
	var reason := _validate_sections(campaign, true)
	if not reason.is_empty():
		return reason
	reason = _validate_mine(campaign)
	if not reason.is_empty():
		return reason
	reason = _validate_fungal_farm(campaign)
	if not reason.is_empty():
		return reason
	return _validate_third_worker(campaign)


## T23: V5 é o V4 inteiro mais a seção `surface`. Nenhum campo de V1–V4 muda de nome, de
## tipo ou de significado.
static func validate_v5(campaign: Dictionary) -> String:
	var reason := validate_v4(campaign)
	if not reason.is_empty():
		return reason
	return _validate_surface(campaign)


## T24: V6 é o V5 inteiro mais a seção `natives`.
static func validate_v6(campaign: Dictionary) -> String:
	var reason := validate_v5(campaign)
	if not reason.is_empty():
		return reason
	return _validate_natives(campaign)


## T25: V7 é o V6 inteiro mais número, tamanho e calmaria da incursão.
static func validate_v7(campaign: Dictionary) -> String:
	var reason := validate_v6(campaign)
	if not reason.is_empty():
		return reason
	return _validate_recurring_incursion(campaign)


## T26: V8 é o V7 inteiro mais `surface.clean_repel_milestone`. O Cristal só pode ter sido
## entregue se alguma incursão já aconteceu.
static func validate_v8(campaign: Dictionary) -> String:
	var reason := validate_v7(campaign)
	if not reason.is_empty():
		return reason
	var surface := campaign[SECTION_SURFACE] as Dictionary
	if not _is_bool(surface, KEY_CLEAN_REPEL_MILESTONE):
		return "surface.clean_repel_milestone precisa ser bool"
	if surface[KEY_CLEAN_REPEL_MILESTONE] \
			and int((surface[KEY_INCURSION] as Dictionary)[KEY_INCURSION_NUMBER]) < 1:
		return "Cristal da guilda repelida sem nenhuma incursão"
	return ""


## §53/§116: a rota de migração é uma sequência de funções nomeadas, não um registry. Cada
## versão sobe exatamente um degrau, na ordem: V1→V2 e depois V2→V3. Não há atalho V1→V3 —
## uma campanha V1 passa pelos dois degraus, e cada degrau acrescenta só o que é seu.
static func migrate_to_current(document: Dictionary) -> Dictionary:
	var migrated := document.duplicate(true) as Dictionary
	if int(migrated[ROOT_VERSION]) == SAVE_VERSION_V1:
		migrated = migrate_v1_to_v2(migrated)
	if int(migrated[ROOT_VERSION]) == SAVE_VERSION_V2:
		migrated = migrate_v2_to_v3(migrated)
	if int(migrated[ROOT_VERSION]) == SAVE_VERSION_V3:
		migrated = migrate_v3_to_v4(migrated)
	if int(migrated[ROOT_VERSION]) == SAVE_VERSION_V4:
		migrated = migrate_v4_to_v5(migrated)
	if int(migrated[ROOT_VERSION]) == SAVE_VERSION_V5:
		migrated = migrate_v5_to_v6(migrated)
	if int(migrated[ROOT_VERSION]) == SAVE_VERSION_V6:
		migrated = migrate_v6_to_v7(migrated)
	if int(migrated[ROOT_VERSION]) == SAVE_VERSION_V7:
		migrated = migrate_v7_to_v8(migrated)
	return migrated


## §54: o único fato novo de um V1 migrado é que aquela campanha não tem Mina. Os números
## de gameplay continuam sendo os mesmos valores do documento de entrada.
static func migrate_v1_to_v2(document: Dictionary) -> Dictionary:
	var migrated := document.duplicate(true) as Dictionary
	migrated[ROOT_VERSION] = SAVE_VERSION_V2
	((migrated[ROOT_CAMPAIGN] as Dictionary)[SECTION_CONSTRUCTIONS] as Dictionary)[
			SECTION_MINE] = {KEY_EXISTS: false}
	return migrated


## §54/T21: o único fato novo de um V2 migrado é que aquela campanha não tem Fazenda
## Fúngica. A Mina que o V2 já tinha é preservada exatamente como está — a migração
## acrescenta, não reescreve. Como o V1 passa por `migrate_v1_to_v2()` antes de chegar aqui,
## uma campanha V1 ganha `mine` e `fungal_farm` nos dois degraus, na ordem certa.
static func migrate_v2_to_v3(document: Dictionary) -> Dictionary:
	var migrated := document.duplicate(true) as Dictionary
	migrated[ROOT_VERSION] = SAVE_VERSION_V3
	((migrated[ROOT_CAMPAIGN] as Dictionary)[SECTION_CONSTRUCTIONS] as Dictionary)[
			SECTION_FUNGAL_FARM] = {KEY_EXISTS: false}
	return migrated


## T22: o único fato novo de um V3 migrado é que aquela campanha nunca invocou o terceiro
## Trabalhador. O V3 não tinha como registrar worker_003 (o validador V3 o recusa), então não
## há unidade a converter — só a flag histórica a acrescentar, em false.
static func migrate_v3_to_v4(document: Dictionary) -> Dictionary:
	var migrated := document.duplicate(true) as Dictionary
	migrated[ROOT_VERSION] = SAVE_VERSION_V4
	((migrated[ROOT_CAMPAIGN] as Dictionary)[SECTION_UNITS] as Dictionary)[
			KEY_THIRD_SUMMONED] = false
	return migrated


## T23: o fato novo de um V4 migrado é que a incursão ainda não aconteceu. A Notoriedade
## não é inventada: um Núcleo já no Nv.2 é exatamente o fato que, jogado, soma 20 — e é o
## nível gravado no próprio arquivo que decide. Nv.1 migra com zero.
static func migrate_v4_to_v5(document: Dictionary) -> Dictionary:
	var migrated := document.duplicate(true) as Dictionary
	migrated[ROOT_VERSION] = SAVE_VERSION_V5
	var campaign := migrated[ROOT_CAMPAIGN] as Dictionary
	var level := int((campaign[SECTION_CORE] as Dictionary)[KEY_LEVEL])
	campaign[SECTION_SURFACE] = {
		KEY_NOTORIETY: MIGRATED_LEVEL_TWO_NOTORIETY if level >= 2 else 0,
		KEY_INCURSION: {
			KEY_STATE: "NOT_STARTED",
			KEY_PREPARATION_REMAINING: 0.0,
			KEY_RAIDERS: [],
			KEY_REPELLED: 0,
			KEY_ESCAPED: 0,
		},
	}
	return migrated


## T24: o fato novo de um V5 migrado é que o selo nunca foi tocado e a Guarda nunca foi
## encontrada. Nada é inventado: se o Núcleo gravado já está no Nv.2, o selo desperta na
## carga pela regra viva do controller, intacto.
static func migrate_v5_to_v6(document: Dictionary) -> Dictionary:
	var migrated := document.duplicate(true) as Dictionary
	migrated[ROOT_VERSION] = SAVE_VERSION_V6
	(migrated[ROOT_CAMPAIGN] as Dictionary)[SECTION_NATIVES] = {
		NATIVE_PEOPLE_ID: {
			KEY_SEAL_WORK_DONE: 0.0,
			KEY_LEGITIMACY: 0,
			KEY_REQUESTS_FULFILLED: 0,
			KEY_OATH_SWORN: false,
			KEY_GUARDIAN: {KEY_ALIVE: false},
		},
	}
	return migrated


## T25: um V6 conhecia uma única incursão, sempre de 2. O que o arquivo diz vira número: em
## ACTIVE ou ENDED aquela foi a incursão 1, de 2 saqueadores; antes dela, nenhuma. A calmaria
## migra zerada — uma campanha V6 que tinha terminado a incursão vê a próxima guilda começar a
## preparação logo depois da carga, que é a regra nova, não um evento inventado.
static func migrate_v6_to_v7(document: Dictionary) -> Dictionary:
	var migrated := document.duplicate(true) as Dictionary
	migrated[ROOT_VERSION] = SAVE_VERSION_V7
	var incursion := ((migrated[ROOT_CAMPAIGN] as Dictionary)[SECTION_SURFACE] as Dictionary)[
			KEY_INCURSION] as Dictionary
	var launched: bool = incursion[KEY_STATE] == "ACTIVE" or incursion[KEY_STATE] == "ENDED"
	incursion[KEY_INCURSION_NUMBER] = 1 if launched else 0
	incursion[KEY_GUILD_SIZE] = MIGRATED_GUILD_SIZE if launched else 0
	incursion[KEY_COOLDOWN_REMAINING] = 0.0
	return migrated


## T26: o V7 não conhecia o marco, então ele nunca foi entregue. Nada é inventado — nem uma
## incursão V7 já encerrada sem fugas vira Cristal: a próxima guilda inteira repelida é que o
## concede.
static func migrate_v7_to_v8(document: Dictionary) -> Dictionary:
	var migrated := document.duplicate(true) as Dictionary
	migrated[ROOT_VERSION] = SAVE_VERSION
	((migrated[ROOT_CAMPAIGN] as Dictionary)[SECTION_SURFACE] as Dictionary)[
			KEY_CLEAN_REPEL_MILESTONE] = false
	return migrated


static func _validate_envelope(document: Variant) -> String:
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
	return ""


## T22: `accepts_third_worker` só é true para o V4. V1, V2 e V3 são formatos congelados e
## continuam recusando o registro worker_003 — o passado não ganha unidade nova.
static func _validate_sections(campaign: Dictionary, accepts_third_worker := false) -> String:
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
	reason = _validate_units(campaign, accepts_third_worker)
	if not reason.is_empty():
		return reason
	reason = _validate_constructions(campaign)
	if not reason.is_empty():
		return reason
	reason = _validate_world(campaign)
	if not reason.is_empty():
		return reason
	return _validate_invasion(campaign)


## §8/§58/T20/T22: as versões nominalmente suportadas. V0, V5 e V999 são recusados sem
## adivinhação, e um documento recusado não chega à etapa de aplicação (§67).
static func is_supported_version(value: Variant) -> bool:
	return _is_integral(value) and SUPPORTED_VERSIONS.has(int(value))


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
static func _validate_units(campaign: Dictionary, accepts_third_worker := false) -> String:
	var units := campaign[SECTION_UNITS] as Dictionary
	if not _is_array(units, KEY_WORKERS) or not _is_bool(units, KEY_SECOND_SUMMONED) \
			or not (units.get(KEY_SOLDIER) is Dictionary):
		return "units precisa de workers, worker_002_summoned e soldier"
	var has_scene_worker := false
	for worker in units[KEY_WORKERS] as Array:
		var reason := _validate_worker(worker, accepts_third_worker)
		if not reason.is_empty():
			return reason
		if (worker as Dictionary)[KEY_UNIT_ID] == FIRST_WORKER_ID:
			has_scene_worker = true
	if not has_scene_worker:
		return "units não registra %s" % FIRST_WORKER_ID
	return _validate_soldier(units[KEY_SOLDIER] as Dictionary)


static func _validate_worker(worker: Variant, accepts_third_worker := false) -> String:
	if not (worker is Dictionary):
		return "workers tem entrada que não é um registro"
	var entry := worker as Dictionary
	var known_ids: Array = [FIRST_WORKER_ID, SECOND_WORKER_ID]
	if accepts_third_worker:
		known_ids.append(THIRD_WORKER_ID)
	if not known_ids.has(entry.get(KEY_UNIT_ID)):
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


## T22: a flag é obrigatória no V4, e o registro do terceiro Worker exige a história dele.
static func _validate_third_worker(campaign: Dictionary) -> String:
	var units := campaign[SECTION_UNITS] as Dictionary
	if not _is_bool(units, KEY_THIRD_SUMMONED):
		return "units precisa de worker_003_summoned"
	for worker in units[KEY_WORKERS] as Array:
		if (worker as Dictionary)[KEY_UNIT_ID] == THIRD_WORKER_ID \
				and not units[KEY_THIRD_SUMMONED]:
			return "worker_003 registrado sem worker_003_summoned"
	return ""


## T23: a forma da seção `surface`. Faixas que dependem da Definition (vida, capacidade de
## saque) e de quantos saqueadores a incursão tem moram no SaveGameController.
static func _validate_surface(campaign: Dictionary) -> String:
	var surface: Variant = campaign.get(SECTION_SURFACE)
	if not (surface is Dictionary):
		return "seção obrigatória ausente ou inválida: surface"
	var section := surface as Dictionary
	if not _is_int(section, KEY_NOTORIETY) or section[KEY_NOTORIETY] < 0 \
			or section[KEY_NOTORIETY] > 100:
		return "surface.notoriety precisa ser um inteiro entre 0 e 100"
	if not (section.get(KEY_INCURSION) is Dictionary):
		return "surface.incursion está ausente"
	var incursion := section[KEY_INCURSION] as Dictionary
	if not INCURSION_STATE_NAMES.has(incursion.get(KEY_STATE)):
		return "estado de incursão desconhecido: %s" % [incursion.get(KEY_STATE)]
	if not _is_number(incursion, KEY_PREPARATION_REMAINING) \
			or incursion[KEY_PREPARATION_REMAINING] < 0.0:
		return "surface.incursion.preparation_time_remaining inválido"
	if not _is_int(incursion, KEY_REPELLED) or not _is_int(incursion, KEY_ESCAPED) \
			or incursion[KEY_REPELLED] < 0 or incursion[KEY_ESCAPED] < 0:
		return "surface.incursion precisa de repelled e escaped inteiros não negativos"
	if not _is_array(incursion, KEY_RAIDERS):
		return "surface.incursion.raiders está ausente"
	var state := String(incursion[KEY_STATE])
	var raiders := incursion[KEY_RAIDERS] as Array
	if state != "PREPARATION" and incursion[KEY_PREPARATION_REMAINING] > 0.0:
		return "tempo de preparação da incursão guardado fora de PREPARATION"
	if state != "ACTIVE" and not raiders.is_empty():
		return "%s não pode ter saqueador em campo" % state
	if state == "ACTIVE" and raiders.is_empty():
		return "incursão ACTIVE sem saqueador é uma campanha impossível"
	for raider in raiders:
		var reason := _validate_raider(raider)
		if not reason.is_empty():
			return reason
	return ""


static func _validate_raider(raider: Variant) -> String:
	if not (raider is Dictionary):
		return "raiders tem entrada que não é um registro"
	var entry := raider as Dictionary
	if not _is_string(entry, KEY_RAIDER_ID) or not _is_number(entry, KEY_HEALTH) \
			or not _is_position(entry) or not RAIDER_PHASE_NAMES.has(entry.get(KEY_PHASE)) \
			or not (entry.get(KEY_LOOT) is Dictionary):
		return "saqueador com campo ausente ou de tipo errado"
	if entry[KEY_HEALTH] <= 0.0:
		return "%s sem vida não é um saqueador em campo" % entry[KEY_RAIDER_ID]
	var loot := entry[KEY_LOOT] as Dictionary
	for resource_id in loot:
		if not (resource_id is String) or not _is_int(loot, String(resource_id)) \
				or loot[resource_id] <= 0:
			return "%s tem saque inválido" % entry[KEY_RAIDER_ID]
	return ""


## T24: a forma da seção `natives`. Faixas que dependem da Definition do povo (trabalho do
## selo, número de pedidos, limiar do juramento, vida do Guardião) moram no controller.
static func _validate_natives(campaign: Dictionary) -> String:
	var natives: Variant = campaign.get(SECTION_NATIVES)
	if not (natives is Dictionary):
		return "seção obrigatória ausente ou inválida: natives"
	var people: Variant = (natives as Dictionary).get(NATIVE_PEOPLE_ID)
	if not (people is Dictionary):
		return "natives.%s está ausente" % NATIVE_PEOPLE_ID
	var entry := people as Dictionary
	if not _is_number(entry, KEY_SEAL_WORK_DONE) or entry[KEY_SEAL_WORK_DONE] < 0.0:
		return "natives.seal_work_done precisa ser um número não negativo"
	if not _is_int(entry, KEY_LEGITIMACY) or entry[KEY_LEGITIMACY] < 0 \
			or entry[KEY_LEGITIMACY] > 100:
		return "natives.legitimacy precisa ser um inteiro entre 0 e 100"
	if not _is_int(entry, KEY_REQUESTS_FULFILLED) or entry[KEY_REQUESTS_FULFILLED] < 0:
		return "natives.requests_fulfilled precisa ser um inteiro não negativo"
	if not _is_bool(entry, KEY_OATH_SWORN):
		return "natives.oath_sworn precisa ser bool"
	if not (entry.get(KEY_GUARDIAN) is Dictionary):
		return "natives.guardian está ausente"
	var guardian := entry[KEY_GUARDIAN] as Dictionary
	if not _is_bool(guardian, KEY_ALIVE):
		return "natives.guardian.alive precisa ser bool"
	if guardian[KEY_ALIVE]:
		if not _is_number(guardian, KEY_HEALTH) or guardian[KEY_HEALTH] <= 0.0 \
				or not _is_int(guardian, KEY_LEVEL) or guardian[KEY_LEVEL] < 1 \
				or not _is_number(guardian, KEY_EXPERIENCE) or guardian[KEY_EXPERIENCE] < 0.0 \
				or not _is_position(guardian):
			return "natives.guardian vivo com campo ausente ou fora da faixa"
		if not entry[KEY_OATH_SWORN]:
			return "Guardião em campo sem juramento prestado"
	return ""


## T25: a forma dos campos recorrentes. A guilda nunca passa de 5; a calmaria só existe em
## ENDED; antes da primeira largada não há número nem guilda; depois dela, sempre há.
static func _validate_recurring_incursion(campaign: Dictionary) -> String:
	var incursion := ((campaign[SECTION_SURFACE] as Dictionary)[KEY_INCURSION]) as Dictionary
	if not _is_int(incursion, KEY_INCURSION_NUMBER) or incursion[KEY_INCURSION_NUMBER] < 0:
		return "surface.incursion.incursion_number precisa ser um inteiro não negativo"
	if not _is_int(incursion, KEY_GUILD_SIZE) or incursion[KEY_GUILD_SIZE] < 0 \
			or incursion[KEY_GUILD_SIZE] > 5:
		return "surface.incursion.guild_size precisa ser um inteiro entre 0 e 5"
	if not _is_number(incursion, KEY_COOLDOWN_REMAINING) \
			or incursion[KEY_COOLDOWN_REMAINING] < 0.0:
		return "surface.incursion.cooldown_remaining inválido"
	var state := String(incursion[KEY_STATE])
	if state != "ENDED" and incursion[KEY_COOLDOWN_REMAINING] > 0.0:
		return "calmaria guardada fora de ENDED"
	if state == "NOT_STARTED" and (incursion[KEY_INCURSION_NUMBER] != 0
			or incursion[KEY_GUILD_SIZE] != 0):
		return "incursão NOT_STARTED com número ou guilda registrados"
	if (state == "ACTIVE" or state == "ENDED") and (incursion[KEY_INCURSION_NUMBER] < 1
			or incursion[KEY_GUILD_SIZE] < 2):
		return "incursão %s sem número ou guilda" % state
	if (incursion[KEY_RAIDERS] as Array).size() > incursion[KEY_GUILD_SIZE]:
		return "mais saqueadores em campo do que a guilda tem"
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


## §48/§49/T20: a Mina é uma obra, então repete o formato de Ninho e Quartel e acrescenta
## o relógio. A faixa superior de `production_elapsed` é a `production_interval` da
## MineDefinition, e faixa contra Definition é domínio — mora no SaveGameController, não
## aqui. O que este contrato pode afirmar sozinho é o tipo, a presença e o sinal.
static func _validate_mine(campaign: Dictionary) -> String:
	var mine: Variant = (campaign[SECTION_CONSTRUCTIONS] as Dictionary).get(SECTION_MINE)
	if not (mine is Dictionary):
		return "constructions.mine está ausente"
	var data := mine as Dictionary
	if not _is_bool(data, KEY_EXISTS):
		return "constructions.mine precisa de exists"
	if not data[KEY_EXISTS]:
		return ""
	if data.get("mine_id") != MINE_ID or not _is_number(data, KEY_REMAINING_WORK) \
			or not _is_position(data) or not _is_number(data, KEY_PRODUCTION_ELAPSED):
		return "constructions.mine é incompleto ou tem id errado"
	if data[KEY_REMAINING_WORK] < 0.0 or data[KEY_PRODUCTION_ELAPSED] < 0.0:
		return "constructions.mine tem valor negativo"
	return ""


## §48/§49/T21: a Fazenda Fúngica repete o formato de Mina — obra com relógio. O que este
## contrato pode afirmar sozinho é o tipo, a presença e o sinal; a faixa superior contra a
## `production_interval` é domínio e mora no SaveGameController. Note que aqui o topo da
## faixa é **inclusive** (a diferença de §17), mas essa é uma regra contra Definition e não
## contra schema — o contrato só recusa negativo.
static func _validate_fungal_farm(campaign: Dictionary) -> String:
	var farm: Variant = (campaign[SECTION_CONSTRUCTIONS] as Dictionary).get(SECTION_FUNGAL_FARM)
	if not (farm is Dictionary):
		return "constructions.fungal_farm está ausente"
	var data := farm as Dictionary
	if not _is_bool(data, KEY_EXISTS):
		return "constructions.fungal_farm precisa de exists"
	if not data[KEY_EXISTS]:
		return ""
	if data.get("fungal_farm_id") != FUNGAL_FARM_ID \
			or not _is_number(data, KEY_REMAINING_WORK) \
			or not _is_position(data) or not _is_number(data, KEY_PRODUCTION_ELAPSED):
		return "constructions.fungal_farm é incompleto ou tem id errado"
	if data[KEY_REMAINING_WORK] < 0.0 or data[KEY_PRODUCTION_ELAPSED] < 0.0:
		return "constructions.fungal_farm tem valor negativo"
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
