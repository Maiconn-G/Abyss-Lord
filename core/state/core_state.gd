class_name CoreState
extends RefCounted

signal essence_changed(current: float, maximum: float)
signal population_changed(current: int, capacity: int)
signal population_capacity_changed(current_population: int, new_capacity: int)

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


func add_population_capacity_bonus(amount: int) -> void:
	if amount <= 0:
		return
	population_capacity_bonus += amount
	population_capacity_changed.emit(population, get_population_capacity())
