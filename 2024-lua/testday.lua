local M = {
	exampleInput = [[1abc2
pqr3stu8vwx
a1b2c3d4e5f
treb7uchet]],
	exampleAnswer1 = 77,
}

---comment
---@param inputfile string
---@return string
function M:part1(inputfile)
	local aoc = require("aocutils")
	local content = aoc:read_file(inputfile)
	local lines = aoc:split_string(content, "\n")

	local totalsum = 0
	for index, line in ipairs(lines) do
		local linesum = 0
		for str in string.gmatch(line, "%S+") do
			local num = tonumber(str)
			if num then
				linesum = linesum + math.floor(num)
			end
		end

		totalsum = totalsum + linesum
	end

	return tostring(totalsum)
end

---comment
---@param inputfile string
---@return string
function M:part2(inputfile)
	return "part 2 not implemented"
end

return M
