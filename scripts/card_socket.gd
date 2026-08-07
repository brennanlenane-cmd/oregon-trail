extends Control
class_name CardSocket

# The drop mouth of a HazardGate. CardControl asks accepts(); the gate decides.

func accepts(card_data: Dictionary) -> bool:
	var gate := get_meta("gate") as HazardGate
	return gate != null and gate.socket_accepts(card_data)

func receive(card_data: Dictionary) -> void:
	var gate := get_meta("gate") as HazardGate
	if gate != null:
		gate.socket_receive(card_data)
