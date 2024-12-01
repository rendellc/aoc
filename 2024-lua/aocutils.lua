local M = {}

---comment
---@param str string
---@param delimeter string
---@return table
function M:split_lines(str)
	local lines = {}
	for line in string.gmatch(str, "(.-)\n") do
		table.insert(lines, line)
	end

	return lines
end

function M:read_file(filename)
	print("opening file: " .. filename)
	local file = io.open(filename, "r")
	if not file then
		error("could not open file")
	end

	local content = file:read("*all")
	file:close()
	return content
end

return M
