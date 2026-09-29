class_name CoreState
extends RefCounted

signal essence_changed(current: float, maximum: float)
signal population_changed(current: int, capacity: int)
signal population_capacity_changed(current_population: int, new_capacity: int)
signal integrity_changed(current: float, maximum: float)
signal destroyed
signal evolved(old_level: int, new_level: int)

var definition: CoreDefinition
var core_id: String = "main_core"
var level: int = 1
var integrity: float = 0.0
var essence: float = 0.0
var population: int = 0
var population_capacity_bonus: int = 0


func _init(core_definition: CoreDefinition, id: String = "main_core") -> void:
	definition = core_definition
	core_id = id
	level = core_definition.level
	integrity = core_definition.max_integrity
	essence = core_definition.starting_essence


## §4/§5: dano estrutural com clamp 0..max_integrity. amount inválido não altera
## nada; chegar a zero emite destroyed exatamente uma vez, porque dano seguinte já
## encontra a Integrity inalterada e sai antes do emit.
func damage(amount: float) -> void:
	if amount <= 0.0:
		return
	var next := clampf(integrity - amount, 0.0, definition.max_integrity)
	if next == integrity:
		return
	integrity = next
	integrity_changed.emit(integrity, definition.max_integrity)
	if is_destroyed():
		destroyed.emit()


func is_destroyed() -> bool:
	return integrity <= 0.0


func add_essence(amount: float) -> void:
	if amount <= 0.0:
		return
	var maximum := definition.max_essence
	if essence >= maximum:
		return
	essence = minf(essence + amount, maximum)
	essence_changed.emit(essence, maximum)


func consume_essence(amount: float) -> bool:
	if amount < 0.0 or amount > essence:
		return false
	essence -= amount
	essence_changed.emit(essence, definition.max_essence)
	return true


func set_population(value: int) -> void:
	var capacity := get_population_capacity()
	var next := clampi(value, 0, capacity)
	if next == population:
		return
	population = next
	population_changed.emit(population, capacity)


func get_population_capacity() -> int:
	return definition.population_capacity + population_capacity_bonus


func can_add_population(amount: int = 1) -> bool:
	if amount <= 0:
		return false
	return population + amount <= get_population_capacity()


func try_add_population(amount: int = 1) -> bool:
	if not can_add_population(amount):
		return false
	population += amount
	population_changed.emit(population, get_population_capacity())
	return true


## §44: remover população é atômico como adicionar. amount inválido ou maior que a
## população atual rejeita a operação inteira — nunca se reduz silenciosamente.
func try_remove_population(amount: int = 1) -> bool:
	if amount <= 0 or amount > population:
		return false
	population -= amount
	population_changed.emit(population, get_population_capacity())
	return true


func add_population_capacity_bonus(amount: int) -> void:
	if amount <= 0:
		return
	population_capacity_bonus += amount
	population_capacity_changed.emit(population, get_population_capacity())


## §18/T18: restaurar não é jogar. Nada aqui passa por `damage`, `add_essence` nem
## `evolve_to`, porque nenhum deles expressa a operação "o domínio volta a ser este":
## a evolução trocaria a Integrity pelo teto novo (e §19/T18 exige o valor salvo, não o
## teto), e `destroyed`/`evolved` anunciariam como novidade um evento que o jogador já
## viveu (§20/§54/T18). A validação é a mesma regra de faixa dos caminhos normais —
## número fora de domínio devolve false e não toca em nada.
##
## §77/T18: os sinais do fim são os de valor, uma emissão por número, já com o estado
## final. Não existe sequência intermediária: quem escuta recebe a campanha carregada.
func restore_persistent_state(
		core_definition: CoreDefinition,
		value_integrity: float,
		value_essence: float,
		value_population: int,
		value_capacity_bonus: int) -> bool:
	if core_definition == null:
		return false
	if value_integrity < 0.0 or value_integrity > core_definition.max_integrity:
		return false
	if value_essence < 0.0 or value_essence > core_definition.max_essence:
		return false
	if value_capacity_bonus < 0:
		return false
	var capacity := core_definition.population_capacity + value_capacity_bonus
	if value_population < 0 or value_population > capacity:
		return false
	definition = core_definition
	level = core_definition.level
	integrity = value_integrity
	essence = value_essence
	population_capacity_bonus = value_capacity_bonus
	population = value_population
	integrity_changed.emit(integrity, core_definition.max_integrity)
	essence_changed.emit(essence, core_definition.max_essence)
	population_changed.emit(population, capacity)
	return true


## §8/T14: a única transição existente é para um nível superior. Mesma Definition,
## Definition nula e nível menor caem aqui antes de qualquer escrita, então §9 fica
## garantido por construção: nunca existe um instante com level novo e limites velhos.
func can_evolve_to(new_definition: CoreDefinition) -> bool:
	return new_definition != null and new_definition.level > level


## §7/§12/§14/T14: evoluir é trocar a Definition deste mesmo State — o Núcleo continua
## sendo o Núcleo, com o mesmo core_id, a mesma Population e o mesmo bônus do Ninho
## (§17/§18/§51/§97: nada aqui chama set_population nem readiciona bônus). A Integrity
## sobe para o teto novo porque o marco recompensa a sobrevivência; a Essence que restou
## é preservada, e o único ajuste possível é o clamp ao teto novo (§15), que neste caso
## amplia. Os sinais vêm na ordem de §21: valores primeiro, evolved por último, para que
## quem escuta evolved já enxergue o estado final.
func evolve_to(new_definition: CoreDefinition) -> bool:
	if not can_evolve_to(new_definition):
		return false
	var old_level := level
	definition = new_definition
	level = new_definition.level
	integrity = new_definition.max_integrity
	essence = minf(essence, new_definition.max_essence)
	integrity_changed.emit(integrity, new_definition.max_integrity)
	essence_changed.emit(essence, new_definition.max_essence)
	population_capacity_changed.emit(population, get_population_capacity())
	evolved.emit(old_level, level)
	return true
