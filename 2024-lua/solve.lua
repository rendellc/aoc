-- Function to read the input file
function read_input(file_name)
	local input = {}
	for line in io.lines(file_name) do
		table.insert(input, line)
	end
	return input
end

local function main()
	if #arg == 0 then
		print("no day specified")
		return
	end
	local aoc = require("aocutils")

	local solution = require(arg[1])
	local ex1Answer = solution:part1(solution.ex1)
	local ex1Passed = ex1Answer == solution.ex1Solution
	if ex1Passed then
		print("Example 1 PASS")
	else
		print("Example 1 FAIL (" .. ex1Answer .. " is not " .. solution.ex1Solution .. ")")
	end
	local ex2Answer = solution:part2(solution.ex2)
	local ex2Passed = ex2Answer == solution.ex2Solution
	if ex2Passed then
		print("Example 2 PASS")
	else
		print("Example 2 FAIL (" .. ex2Answer .. " is not " .. solution.ex2Solution .. ")")
	end

	local inputfile = arg[1] .. ".txt"
	if ex1Passed then
		local content = aoc:read_file(inputfile)
		print("Answer 1: " .. solution:part1(content))
	else
		print("Answer 1: (solve example first)")
	end
	if ex2Passed then
		local content = aoc:read_file(inputfile)
		print("Answer 2: " .. solution:part2(content))
	else
		print("Answer 2: (solve example first)")
	end
end

-- Run the main function
main()
