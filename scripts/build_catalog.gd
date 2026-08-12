class_name BuildCatalog
extends RefCounted

const ITEM_IDS: Array[StringName] = [
	&"griddle",
	&"refrigerator",
	&"table",
]

const ITEMS: Dictionary = {
	&"griddle": {
		"display_name": "Chapa",
		"price": 800,
		"footprint": Vector2i(3, 2),
		"base_color": Color("4e5558"),
	},
	&"refrigerator": {
		"display_name": "Geladeira",
		"price": 1200,
		"footprint": Vector2i(2, 3),
		"base_color": Color("d7e9e7"),
	},
	&"table": {
		"display_name": "Mesa",
		"price": 300,
		"footprint": Vector2i(3, 2),
		"base_color": Color("b86638"),
	},
}


static func get_item(item_id: StringName) -> Dictionary:
	if not ITEMS.has(item_id):
		return {}

	var item: Dictionary = ITEMS[item_id].duplicate(true)
	item["id"] = item_id
	return item


static func get_all_items() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item_id in ITEM_IDS:
		result.append(get_item(item_id))
	return result
