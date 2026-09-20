-- Run with execute_luau in Studio's Edit DataModel. No player data changes.
local shared = game.ReplicatedStorage.Shared
local copy = shared.HotBarDrag:Clone()
copy.Parent = shared
local ok, result = pcall(function()
	local rules = require(copy)
	local order = {"a", "empty", "b", "c", "d", "nextPage"}
	local row = {{key="a",x=100},{key="b",x=160},{key="c",x=220},{key="d",x=280}}
	assert(rules.before(order,"a",row,160)=="c", "move right into neighbour")
	assert(rules.before(order,"c",row,100)=="a", "move left into first slot")
	assert(rules.before(order,"b",row,160)=="b", "drop at origin preserves order")
	assert(rules.before(order,"a",row,300)=="nextPage", "end of page preserves next page")
	assert(rules.before(order,"d",row,220)=="c", "move one slot left")
	assert(rules.before(order,"a",row,220)=="d", "move two slots right")
	local lastPage = {{key="nextPage",x=100},{key="d",x=160}}
	assert(rules.before(order,"d",lastPage,100)==nil, "last item has no successor")
	assert(rules.before(order,"c",{},100)=="c", "empty row is a no-op")
	assert(rules.before(order,"missing",row,100)=="missing", "stale key is a no-op")
	local touch = {UserInputType=Enum.UserInputType.Touch} :: any
	local other = {UserInputType=Enum.UserInputType.Touch} :: any
	local mouse = {UserInputType=Enum.UserInputType.MouseButton1} :: any
	local move = {UserInputType=Enum.UserInputType.MouseMovement} :: any
	assert(rules.owns(touch,touch,false) and rules.owns(touch,touch,true))
	assert(not rules.owns(touch,other,false) and not rules.owns(touch,other,true), "second finger cannot move/release drag")
	assert(not rules.owns(touch,move,false) and not rules.owns(mouse,touch,true))
	assert(rules.owns(mouse,move,false) and rules.owns(mouse,mouse,true))
	assert(not rules.owns(nil,move,false))
	assert(rules.contains(Vector2.new(10,-30),Vector2.new(0,-58),Vector2.new(50,44)))
	assert(not rules.contains(Vector2.new(60,-30),Vector2.new(0,-58),Vector2.new(50,44)))
	assert(not table.find(require(shared.HotBar).ITEMS,"ladder"), "retired ladder is out of the arrangement")
	return "PASS: neighbour moves, page boundaries, empty stock, no-op drops, touch ownership, mouse input, safe-area bounds and retired-item save list."
end)
copy:Destroy()
assert(ok,result)
return result
