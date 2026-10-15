class_name LegitimacyState
extends RefCounted

## Tarefa 24 — a Legitimidade de um Povo Nativo (GDD §12, §51.1): o quanto aquele povo
## aceita a autoridade de um humano sobre o domínio que era dele antes.
##
## Não é moeda: não se gasta, não se compra e não mora no estoque. Ela muda por decisões e
## atos do Regente, e quem decide o peso de cada ato é o controller do povo — este State
## só guarda o valor, aplica a faixa 0..100 e diz em que faixa ele está.

signal legitimacy_changed(current: int, maximum: int)

const MAXIMUM := 100

## As cinco faixas do GDD §12.
enum Band { HOSTILE, DISTRUSTFUL, TOLERANT, LOYAL, DEVOTED }

const BAND_NAMES: Array[String] = ["hostil", "desconfiado", "tolerante", "leal", "devoto"]

var value: int = 0


func add(amount: int) -> void:
	if amount <= 0:
		return
	_apply(value + amount)


func remove(amount: int) -> void:
	if amount <= 0:
		return
	_apply(value - amount)


func band() -> Band:
	if value <= 20:
		return Band.HOSTILE
	if value <= 40:
		return Band.DISTRUSTFUL
	if value <= 60:
		return Band.TOLERANT
	if value <= 80:
		return Band.LOYAL
	return Band.DEVOTED


func band_name() -> String:
	return BAND_NAMES[band()]


## Restaurar não é jogar: o valor volta como o arquivo o escreveu, com um único sinal.
func restore(saved_value: int) -> bool:
	if saved_value < 0 or saved_value > MAXIMUM:
		return false
	value = saved_value
	legitimacy_changed.emit(value, MAXIMUM)
	return true


func _apply(next_value: int) -> void:
	var next := clampi(next_value, 0, MAXIMUM)
	if next == value:
		return
	value = next
	legitimacy_changed.emit(value, MAXIMUM)
