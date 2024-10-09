-- {"id":733,"ver":"2.0.0","libVer":"1.0.0","author":"Rider21","dep":["dkjson>=1.0.1", "utf8>=1.0.0"]}

local baseURL = "https://author.today"
local baseAPI = "https://api.author.today/v1/"

local json = Require("dkjson")
local utf8 = Require("utf8")

local HEADERS = HeadersBuilder():add("Authorization", "Bearer guest"):build()

local ORDER_BY_FILTER = 3
local ORDER_BY_VALUES = {
	"По популярности",
	"По количеству лайков",
	"По комментариям",
	"По новизне",
	"По просмотрам",
	"Набирающие популярность",
}
local ORDER_BY_TERMS = { "popular", "likes", "comments", "id", "chapter_date", "count_chapters" }

local function BitXOR(a, b) --Bitwise xor
	local p, c = 1, 0
	while a > 0 and b > 0 do
		local ra, rb = a % 2, b % 2
		if ra ~= rb then c = c + p end
		a, b, p = (a - ra) / 2, (b - rb) / 2, p * 2
	end
	if a < b then a = b end
	while a > 0 do
		local ra = a % 2
		if ra > 0 then c = c + p end
		a, p = (a - ra) / 2, p * 2
	end
	return c
end

-- This function decrypts a string using a simple XOR cipher with a key.
local function decrypt(key, encrypt)
	-- Reverse the key and append a special string "@_@" to it.
	local fixedKey = utf8.reverse(key) .. "@_@"
	-- Create a table to store the key bytes.
	local keyBytes = {}

	-- Iterate over each character in the fixed key and add its byte value to the table.
	for char in fixedKey:gmatch(utf8.charpattern) do
		table.insert(keyBytes, utf8.byte(char))
	end

	-- Get the length of the keyBytes table.
	local keyLength = #keyBytes
	-- Initialize the index for iterating through the keyBytes table.
	local indexChar = 0

	-- Use string.gsub to iterate over each character in the encrypted string.
	return string.gsub(encrypt, utf8.charpattern, function(char)
		-- Decode the character by XORing its byte value with the corresponding byte from the keyBytes table.
		local decodedChar = utf8.char(
			BitXOR(utf8.byte(char), keyBytes[indexChar % keyLength + 1])
		)
		-- Increment the index for the next character.
		indexChar = indexChar + 1
		-- Return the decoded character.
		return decodedChar
	end)
end

local function shrinkURL(url)
	return url:gsub(baseURL .. "/work/", "")
end

local function expandURL(url, key)
	if key == KEY_NOVEL_URL then
		return baseURL .. "/work/" .. url
	end
	return baseURL .. "/reader/" .. url
end

local function getSearch(data)
	local url = "/search?category=works&q=" .. data[QUERY] .. "&page=" .. data[PAGE]
	local response = GETDocument(baseURL .. url)

	return map(response:select("a.work-row, div.book-row"), function(v)
		return Novel {
			title = v:select('h4[class="work-title"], div.book-title'):text(),
			link = v:select("a"):attr("href"):gsub("[^%d]", ""),
			imageURL = v:select('img'):attr("data-src"),
		}
	end)
end

local function getPassage(chapterURL)
	local bookID, chapterID = string.match(chapterURL, "(%d+)/(%d+)")

	local res =
		json.GET(
			baseAPI .. "work/" .. bookID .. "/chapter/" .. chapterID .. "/text",
			HEADERS
		)

	local chapterText = decrypt(res.key, res.text)
	return pageOfElem(Document(chapterText), true)
end

local function parseNovel(novelURL, loadChapters)
	local book = json.GET(baseAPI .. "work/" .. novelURL .. "/details", HEADERS)

	local novel = NovelInfo {
		title = book.title,
		tags = book.tags,
		imageURL = book.coverUrl,
		status = book.isFinished and NovelStatus.COMPLETED or NovelStatus.PUBLISHING,
	}

	local description = ""

	if book.annotation then
		description = description .. book.annotation .. "\n"
	end
	if book.authorNotes then
		description = description .. "Примечания автора:\n" .. book.authorNotes
	end
	novel:setDescription(description)

	if loadChapters then
		local chaptersJSON =
			json.GET(baseAPI .. "work/" .. novelURL .. "/content", HEADERS)

		local chapterList = {}
		for k, chapter in pairs(chaptersJSON) do
			if chapter.isAvailable and not chapter.isDraft then
				table.insert(
					chapterList,
					NovelChapter {
						title = chapter.title or "Глава " .. (k + 1),
						link = novelURL .. "/" .. chapter.id,
						release = chapter.publishTime or chapter.lastModificationTime,
						order = chapter.sortOrder or k,
					}
				)
			end
		end
		novel:setChapters(AsList(chapterList))
	end
	return novel
end

return {
	id = 733,
	name = "Автор Тудей",
	baseURL = baseURL,
	imageURL = "https://author.today/dist/favicons/android-chrome-192x192.png",
	chapterType = ChapterType.HTML,
	listings = { Listing("Novel List", true, function(data)
		local sort = ORDER_BY_TERMS[data[ORDER_BY_FILTER] + 1]
		local url = "catalog/search?page=" .. data[PAGE] .. "&sorting=" .. sort

		local response = json.GET(baseAPI .. url, HEADERS)

		return map(response.searchResults, function(v)
			return Novel {
				title = v.title,
				link = v.id,
				imageURL = 'https://cm.author.today/content/' .. v.coverUrl,
			}
		end)
	end) },
	getPassage = getPassage,
	parseNovel = parseNovel,
	hasSearch = true,
	isSearchIncrementing = true,
	search = getSearch,
	searchFilters = {
		DropdownFilter(ORDER_BY_FILTER, "Сортировка", ORDER_BY_VALUES),
	},
	shrinkURL = shrinkURL,
	expandURL = expandURL,
}
