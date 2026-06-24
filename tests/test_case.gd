extends RefCounted
## TestCase — tiny assertion base for the headless test runner.
##
## Subclass this and add methods named `test_*`. The runner calls run(), which
## executes every test_ method and records pass/fail. No external addon needed.
## (If the suite outgrows this, add the GUT addon under addons/gut/ — see
## tests/README.md — and these can be migrated or kept alongside.)

var _total: int = 0
var _failed: int = 0
var _log: Array[String] = []
var _current: String = ""
var _current_failed: bool = false


## Runs all test_* methods. Returns {total, failed, log}.
func run() -> Dictionary:
	for method in get_method_list():
		var n: String = method.name
		if not n.begins_with("test_"):
			continue
		_current = n
		_current_failed = false
		_total += 1
		call(n)
		if _current_failed:
			_failed += 1
		else:
			_log.append("  PASS  %s" % n)
	return {"total": _total, "failed": _failed, "log": _log}


func _fail(msg: String) -> void:
	_current_failed = true
	_log.append("  FAIL  %s — %s" % [_current, msg])


func assert_eq(actual: Variant, expected: Variant, note: String = "") -> void:
	if actual != expected:
		_fail("expected %s, got %s%s" % [str(expected), str(actual), _suffix(note)])


func assert_true(value: Variant, note: String = "") -> void:
	if not value:
		_fail("expected true, got %s%s" % [str(value), _suffix(note)])


func assert_false(value: Variant, note: String = "") -> void:
	if value:
		_fail("expected false, got %s%s" % [str(value), _suffix(note)])


func _suffix(note: String) -> String:
	return "" if note.is_empty() else " (%s)" % note
