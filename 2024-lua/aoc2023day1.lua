local M = {
	ex1 = [[1abc2
pqr3stu8vwx
a1b2c3d4e5f
treb7uchet]],
	ex1Solution = "142",
	ex2 = [[two1nine
eightwothree
abcone2threexyz
xtwone3four
4nineeightseven2
zoneight234
7pqrstsixteen]],
	ex2Solution = "281",
}

---comment
---@param content string
---@return string
function M:part1(content)
	local sum = 0
	for line in content:gmatch("[^\r\n]+") do
		local linerev = string.reverse(line)
		local start = string.find(line, "%d")
		local first = string.sub(line, start, start)

		start = string.find(linerev, "%d")
		local last = string.sub(linerev, start, start)

		sum = sum + 10 * tonumber(first) + tonumber(last)
	end
	return tostring(sum)
end

---comment
---@param content string
---@return string
function M:part2(content)
	local sum = 0
	for line in content:gmatch("[^\r\n]+") do
		print(line)
		local linerev = string.reverse(line)
		-- local start = string.find(line, "%d|one|two|three|four|five|six|seven|eight|nine")
		local start, stop = string.find(line, "%f[%a](one|two|three|four|five|six|seven|eight|nine)")
		local first = string.sub(line, start, stop)
		print(first)

		start = string.find(linerev, "%d")
		local last = string.sub(linerev, start, start)

		sum = sum + 10 * tonumber(first) + tonumber(last)
	end
	return tostring(sum)
end

return M
