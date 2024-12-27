local M = {
	ex1 = [[190: 10 19
3267: 81 40 27
83: 17 5
156: 15 6
7290: 6 8 6 15
161011: 16 10 13
192: 17 8 14
21037: 9 7 18 13
292: 11 6 16 20]],
	ex1Solution = "?",
	ex2 = [[190: 10 19
3267: 81 40 27
83: 17 5
156: 15 6
7290: 6 8 6 15
161011: 16 10 13
192: 17 8 14
21037: 9 7 18 13
292: 11 6 16 20]],
	ex2Solution = "?",
}

local function parse(content)
	local lines = {}
	for lineStr in content:gmatch("[^\n]+") do
		local resultStr = lineStr:match("(%d+): ")
		local values = {}

		for value in lineStr:sub(#resultStr+3):gmatch("%d+") do
			table.insert(values, tonumber(value))
		end

		table.insert(lines, {
			result=tonumber(resultStr),
			values=values,
		})
	end

	return lines
end

function getValuesString(line)
	local s = ""
	for i, value in ipairs(line.values) do
		if #s > 0 then
			s = s .. " " .. tostring(value)
		else
			s = tostring(value)
		end
	end

	return s
end

function solve(target, values, i, rem)
	if i == 0 then
		acc = values[1]
		return solve(target, values, 2, acc)
	end

	local curr = values[i]

end

---comment
---@param content string
---@return string
function M:part1(content)
	local lines = parse(content)
	for _, line in ipairs(lines) do
		print(line.result, getValuesString(line))
		solve(line.result, line.values, 0, 0)
	end


	return tostring(0)
end

---comment
---@param content string
---@return string
function M:part2(content)
	return ""
end

return M
