extends Node
## Inventory, quests, bells.

signal inventory_changed
signal quests_changed
signal bells_changed(value: int)

const ITEMS := ["egg", "milk", "wheat", "tomato", "pumpkin", "wood", "flower", "mushroom"]

var bells := 100
var inventory := {}
var quests: Array = []
var player_name := "Paul"
var lessons: Array = []   # [{title, steps, fact}] learned from villagers (npc_actions.gd)

func count(id: String) -> int:
	return int(inventory.get(id, 0))

func add_item(id: String, n: int = 1) -> void:
	inventory[id] = count(id) + n
	if inventory[id] <= 0:
		inventory.erase(id)
	inventory_changed.emit()

func add_bells(n: int) -> void:
	bells += n
	bells_changed.emit(bells)

func active_quests() -> Array:
	return quests.filter(func(q): return not q["done"])

func add_quest(npc: String, item: String, n: int, title: String, reward: int) -> Dictionary:
	for q in quests:
		if not q["done"] and q["npc"] == npc and q["item"] == item:
			q["count"] = n
			q["title"] = title
			q["reward"] = reward
			quests_changed.emit()
			return q
	var q := {"npc": npc, "item": item, "count": clampi(n, 1, 9), "title": title, "reward": reward, "done": false}
	quests.append(q)
	quests_changed.emit()
	return q

func find_quest(npc: String, item: String) -> Dictionary:
	for q in quests:
		if not q["done"] and q["item"] == item and q["npc"] == npc:
			return q
	for q in quests:
		if not q["done"] and q["item"] == item:
			return q
	return {}

## Returns {"ok": bool, "have": int, "need": int, "quest": Dictionary}
func try_complete(npc: String, item: String) -> Dictionary:
	var q := find_quest(npc, item)
	if q.is_empty():
		return {"ok": false, "have": count(item), "need": 0, "quest": q}
	var have := count(item)
	if have < int(q["count"]):
		return {"ok": false, "have": have, "need": int(q["count"]), "quest": q}
	add_item(item, -int(q["count"]))
	q["done"] = true
	add_bells(int(q["reward"]))
	quests_changed.emit()
	return {"ok": true, "have": have, "need": int(q["count"]), "quest": q}

func context_json(_npc: String) -> String:
	return JSON.stringify({"inventory": inventory, "quests": quests, "bells": bells,
		"items": ITEMS, "playerName": player_name})
