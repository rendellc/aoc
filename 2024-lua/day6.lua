local M = {
	ex1 = [[....#.....
.........#
..........
..#.......
.......#..
..........
.#..^.....
........#.
#.........
......#...]],
	ex1Solution = "41",
	ex2 = [[....#.....
.........#
..........
..#.......
.......#..
..........
.#..^.....
........#.
#.........
......#...]],
	ex2Solution = "6",
}

local function createGuard(location, direction)
	local guard = {
		location=location,
		direction=direction,
	}
	function guard:isInside(map)
		return map:isInside(self.location)
	end
	function guard:isStepObstructed(map)
		return map:isObstructed(self.location + self.direction)
	end
	function guard:directionRotate(map)
		if self.direction == map.up then 
			return map.right
		elseif self.direction == map.right then
			return map.down
		elseif self.direction == map.down then
			return map.left
		elseif self.direction == map.left then
			return map.up
		end

		print("invalid direction", self.direction)
		return nil
	end
	function guard:nextLocationRotate(map)
		return self.location + self:directionRotate(map)
	end
	function guard:toState()
		return string.format("%i,%i", self.location, self.direction)
	end
	function guard:doStep(map)
		local stepLocation = self.location + self.direction;
		if not map:isObstructed(stepLocation) then
			self.location = stepLocation
			return
		end

		-- path is obstructed, turn and perform step
		if self.direction == map.up then 
			self.direction = map.right
		elseif self.direction == map.right then
			self.direction = map.down
		elseif self.direction == map.down then
			self.direction = map.left
		elseif self.direction == map.left then
			self.direction = map.up
		else
			print("invalid direction", self.location, self.direction)
			return
		end
		self:doStep(map)
	end

	return guard
end

function guardFromState(str)
	local loc, dir = string.match(str, "(-?%d+),(-?%d+)")
	return createGuard(tonumber(loc),tonumber(dir))
end

local function parse(content) 
	print("parsing input")
	local line = content:match("[^\n]+")

	local map = {
		width = #line,
		height = math.floor((#content+1)/(#line + 1)),
		up = -#line-1,
		down = #line+1,
		right = 1,
		left = -1,
		data = content,
	};
	for k,v in pairs(map)do
		if k ~= "data" then
			print(k,v)
		end
	end

	local guard = createGuard(
		content:find("%^"),
		map.up
	)

	function map:isInside(pos)
		-- print("map IsInside", pos, #self.data)
		if pos < 1 or pos > #self.data then
			return false
		end
		local c = self.data:sub(pos,pos)
		return c ~= '\n'
	end
	function map:isObstructed(pos)
		if pos < 1 or pos > #self.data then
			-- allowed to walk outsode of map
			return false
		end
		local c = self.data:sub(pos,pos)
		return c ~= "." and c ~= "^"
	end

	print("parsing done")
	return map, guard
end

function len(tab)
	local n = 0
	for _, _ in pairs(tab) do
		n = n + 1
	end

	return n
end

---comment
---@param content string
---@return string
function M:part1(content)
	print("Start part1")
	local map, guard = parse(content)
	local locations = {}
	local uniqueLocations = 0
	while guard:isInside(map) do
		print(guard.location, len(locations))
		if locations[guard.location] == nil then
			uniqueLocations = uniqueLocations + 1;
		end
		locations[guard.location] = true
		guard:doStep(map)
	end

	return tostring(uniqueLocations)
end

local function hasLoop(map, guard, extraObstructPos)
	local mapObstructed = map:sub(1, extraObstructPos - 1) .. "0" .. map:sub(extraObstructPos + 1, -1)
	map.data = mapObstructed


	local guardStates = {}
	while guard:isInside(map) do
		local state = guard:toState()

		if guardStates[state] then
			return true
		end

		guardStates[state] = true
		guard:doStep(map)
	end

	return false
end

---comment
---@param content string
---@return string
function M:part2(content)
	print("Starting part2")
	return "?"
	-- local map, guard = parse(content)
	-- local guardStartState = guard:toState()

	-- find path without additional obstructions
	-- local guardLocs = {}
	-- while guard:isInside(map) do
	-- 	guardLocs[guard.location] = true
	-- 	guard:doStep(map)
	-- end

	-- return "?"

	-- -- find path without additional obstructions
	-- for _,loc in ipairs(guardLocs) do
	-- 	guard = guardFromState(guardStartState)
	-- 	-- print(string.format("obs path %i/%i", i, #guardPath))
	-- 	print(guard.location)

	-- 	if hasLoop(map, guard, loc) then
	-- 		print("found loop", loc)
	-- 		loopCounter = loopCounter + 1
	-- 	end
	-- end

	-- return tostring(loopCounter)
end

return M
