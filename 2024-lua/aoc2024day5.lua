local M = {
	ex1 = [[47|53
97|13
97|61
97|47
75|29
61|13
75|53
29|13
97|29
53|29
61|53
97|53
61|29
47|13
75|47
97|75
47|61
75|61
47|29
75|13
53|13

75,47,61,53,29
97,61,53,29,13
75,29,13
75,97,47,61,53
61,13,29
97,13,75,29,47]],
	ex1Solution = "143",
	ex2 = [[47|53
97|13
97|61
97|47
75|29
61|13
75|53
29|13
97|29
53|29
61|53
97|53
61|29
47|13
75|47
97|75
47|61
75|61
47|29
75|13
53|13

75,47,61,53,29
97,61,53,29,13
75,29,13
75,97,47,61,53
61,13,29
97,13,75,29,47]],
	ex2Solution = "123",
}

local function parse(content)
	local rules = {
		before = {},
		after = {},
		lookup = {},
	}

	local start, stop = content:find("\n\n")
	for v1, v2 in content:sub(0,start):gmatch("(%d+)|(%d+)") do
		rules.lookup[string.format("%s<%s", v1,v2)] = true

		-- local s = string.format("%s<%s", v1, v2);
		if rules.before[v2] == nil then
			rules.before[v2] = {}
		end
		table.insert(rules.before[v2], v1)

		if rules.after[v1] == nil then
			rules.after[v1] = {}
		end
		table.insert(rules.after[v1], v2)
	end

	local pagelists = {}
	for line in content:sub(stop+1,-1):gmatch("[^\n]+") do
		local pages = {}
		for page in line:gmatch("%d+") do
			table.insert(pages, page)
		end

		table.insert(pagelists, pages)
	end

	return rules, pagelists
end

local function isPagelistOrdered(pagelist, rules) 
	for i, rule in ipairs(rules) do
		-- print(i, rule)
	end
end

---comment
---@param content string
---@return string
function M:part1(content)
	local sum = 0

	local rules, pagelists = parse(content)

	for pagelistIndex, pagelist in ipairs(pagelists) do
		for i=1,#pagelist do
			for j=i+1,#pagelist do
				local before = pagelist[i]
				local after = pagelist[j]

				if rules.lookup[string.format("%s<%s", after, before)] then
					goto next_list
				end
			end
		end

		local middleIdx = math.floor(#pagelist/2) + 1
		sum = sum + tonumber(pagelist[middleIdx])

		::next_list::
	end

	return tostring(sum)
end

---comment
---@param content string
---@return string
function M:part2(content)
	local sum = 0

	local rules, pagelists = parse(content)

	for pagelistIndex, pagelist in ipairs(pagelists) do
		for i=1,#pagelist do
			for j=i+1,#pagelist do
				local before = pagelist[i]
				local after = pagelist[j]

				if rules.lookup[string.format("%s<%s", after, before)] then
					goto handle_incorrect
				end
			end
		end
		goto skip_correctly_ordered

		::handle_incorrect::
		table.sort(pagelist, function(a,b)
			if rules.lookup[string.format("%s<%s", a, b)] then
				return true
			end
			return false
		end)

		local middleIdx = math.floor(#pagelist/2) + 1
		sum = sum + tonumber(pagelist[middleIdx])

		::skip_correctly_ordered::
	end

	return tostring(sum)
end

return M
