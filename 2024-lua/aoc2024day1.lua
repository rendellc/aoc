local M = {
	ex1 = [[3   4
4   3
2   5
1   3
3   9
3   3]],
	ex1Solution = "11",
	ex2 = [[3   4
4   3
2   5
1   3
3   9
3   3]],
	ex2Solution = "31",
}

---comment
---@param content string
---@return string
function M:part1(content)
	local left = {}
	local right = {}
	for line in content:gmatch("[^\r\n]+") do
		local num1, num2 = line:match("(%d+)%s+(%d+)")
		table.insert(left, tonumber(num1))
		table.insert(right, tonumber(num2))
	end

	table.sort(left)
	table.sort(right)

	local distance = 0
	for i = 1, #left do
		distance = distance + math.abs(left[i] - right[i])
	end

	return tostring(distance)
end

---comment
---@param content string
---@return string
function M:part2(content)
	local lefts = {}
	local rights = {}
	for line in content:gmatch("[^\r\n]+") do
		local num1, num2 = line:match("(%d+)%s+(%d+)")
		table.insert(lefts, tonumber(num1))
		table.insert(rights, tonumber(num2))
	end

	local similarity = 0
	for _, left in ipairs(lefts) do
		local right_counter = 0
		for _, right in ipairs(rights) do
			if right == left then
				right_counter = right_counter + 1
			end
		end

		similarity = similarity + left * right_counter
	end

	return tostring(similarity)
end

return M
