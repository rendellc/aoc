local M = {
	ex1 = [[MMMSXXMASM
MSAMXMSMSA
AMXSXMAAMM
MSAMASMSMX
XMASAMXAMM
XXAMMXXAMA
SMSMSASXSS
SAXAMASAAA
MAMMMXMMMM
MXMXAXMASX]],
	ex1Solution = "18",
	ex2 = [[MMMSXXMASM
MSAMXMSMSA
AMXSXMAAMM
MSAMASMSMX
XMASAMXAMM
XXAMMXXAMA
SMSMSASXSS
SAXAMASAAA
MAMMMXMMMM
MXMXAXMASX]],
	ex2Solution = "9",
}

---@param content string
---@return table
local function describeInput(content)
	local len = #content;

	local line = content:match("^[^\n]*");

	local nRows = #line;
	print("#content:", #content)
	local nCols = (#content + 1)/(nRows + 1)
	print("rows:", nRows)
	print("cols:", nCols)
	nCols = math.floor(nCols)
	print("cols (floor):", nCols)

	return {
		nCols = nCols,
		nRows = nRows,
	}
end

---comment
---@param content string
---@return string
function M:part1(content)
	local counter = 0

	local dsc = describeInput(content)

	local searchFrom = 0;
	while true do
		searchFrom = searchFrom + 1
		-- searchFrom = content:find("[XS]", searchFrom)
		searchFrom = content:find("X", searchFrom)
		if searchFrom == nil then
			break
		end

		local steps = {
			{1,0}, -- right (horizontal)
			{1,1}, -- right down (diagonal)
			{0,1}, -- down (vertical)
			{-1,1}, -- left down
			{-1,0}, -- left (backward)
			{-1,-1}, -- left up
			{0,-1}, -- up
			{1,-1}, -- right up
		};

		for _, step in ipairs(steps) do
			local rStep = step[1];
			local dStep = step[2];
			local word = "X"
			for i = 1, 3 do
				local j = searchFrom + dStep*i*(dsc.nCols+1) + rStep*i;
				if j < 1 or j > #content then
					goto next_step
				end
				local char = content:sub(j,j)
				if char == nil or char == '\n' then
					goto next_step
				end
				word = word .. char;

			end

			-- print("word:", searchFrom, rStep, dStep, word)
			if word == "XMAS" then
				-- print("-- matched")
				counter = counter + 1;
			end

			::next_step::
		end
	end

	return tostring(counter)
end

---comment
---@param content string
---@return string
function M:part2(content)
	local counter = 0

	local dsc = describeInput(content)

	local searchFrom = 0;
	while true do
		searchFrom = searchFrom + 1
		searchFrom = content:find("A", searchFrom)
		if searchFrom == nil then
			break
		end

		local downRight = searchFrom + 1*(dsc.nCols+1) + 1
		if downRight  > #content then
			goto continue
		end

		local upLeft = searchFrom - 1*(dsc.nCols+1) - 1
		if upLeft < 1 then
			goto continue
		end

		local upRight = searchFrom - 1*(dsc.nCols+1) + 1
		local downLeft = searchFrom + 1*(dsc.nCols+1) - 1


		local diag1 = content:sub(upLeft,upLeft) .. content:sub(downRight,downRight)
		if diag1 ~= "SM" and diag1 ~= "MS" then
			goto continue
		end


		local diag2 = content:sub(downLeft,downLeft) .. content:sub(upRight,upRight)
		if diag2 ~= "SM" and diag2 ~= "MS" then
			goto continue
		end

		print("match:", diag1, diag2)
		counter = counter + 1;
		::continue::

	end
	return tostring(counter)
end

return M
