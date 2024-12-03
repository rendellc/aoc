local M = {
	ex1 = "xmul(2,4)%&mul[3,7]!@^do_not_mul(5,5)+mul(32,64]then(mul(11,8)mul(8,5))",
	ex1Solution = "161",
	ex2 = "xmul(2,4)%&mul[3,7]!@^do_not_mul(5,5)+mul(32,64]then(mul(11,8)mul(8,5))",
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

---comment
---@param content string
---@return string
function M:part2(content)
	print(content)
	local sum = 0
	local is_enabled = true
	for v1, v2 in content:gmatch("[mul%((%d+),(%d+)%)]|[(do%(%))]|[(don't%(%))]") do 
		print("match: " .. v1 .. " " .. v2)

		if v2 then
			if is_enabled then
				sum = sum + tonumber(v1)*tonumber(v2)
			end
		elseif v1 == "do()" then
			print("enabled")
			is_enabled = true
		elseif v1 == "don't()" then
			print("disabled")
			is_enabled = false
		else
		end
	end
	return tostring(sum)
end

return M
