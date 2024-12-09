local M = {
	ex1 = "xmul(2,4)%&mul[3,7]!@^do_not_mul(5,5)+mul(32,64]then(mul(11,8)mul(8,5))",
	ex1Solution = "161",
	ex2 = "xmul(2,4)%&mul[3,7]!@^don't()_mul(5,5)+mul(32,64]then(mul(11,8)undo()?mul(8,5))",
	ex2Solution = "48",
}

---comment
---@param content string
---@return string
function M:part1(content)
	local sum = 0
	for v1, v2 in content:gmatch("mul%((%d+),(%d+)%)") do 
		sum = sum + tonumber(v1)*tonumber(v2)
	end
	return tostring(sum)
end

---@param str string
---@return table?
local function find_next(str)
	local matches = {}

	local mul_start, mul_stop, x, y = str:find("mul%((%d+),(%d+)%)")
	if mul_start then
		table.insert(matches, {
			start = mul_start,
			stop = mul_stop,
			token = "mul",
			values = { x, y},
		})
	end

	local do_start, do_stop = str:find("do%(%)")
	if do_start then
		table.insert(matches, {
			start = do_start,
			stop = do_stop,
			token = "do",
		})
	end

	local dont_start, dont_stop = str:find("don't%(%)")
	if dont_start then
		table.insert(matches, {
			start = dont_start,
			stop = dont_stop,
			token = "dont",
		})
	end

	if #matches == 0 then
		return nil
	end

	table.sort(matches, function(a, b)
		return a.start < b.start
	end)

	return matches[1]

end

---comment
---@param content string
---@return string
function M:part2(content)
	local sum = 0
	local is_enabled = true
	local pattern = find_next(content)
	while pattern do
		if pattern.token == "do" then
			is_enabled = true;
		elseif pattern.token == "dont" then
			is_enabled = false;
		elseif is_enabled and pattern.token == "mul" then
			x,y = tonumber(pattern.values[1]), tonumber(pattern.values[2])
			sum = sum + x*y
		end


		content = content:sub(pattern.stop, -1)
		pattern = find_next(content)
	end
	return tostring(sum)
end

return M
