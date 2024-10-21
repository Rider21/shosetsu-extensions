-- {"id":733,"ver":"1.0.0","libVer":"1.0.0","author":"Rider21","dep":["dkjson>=1.0.1", "utf8>=1.0.0"]}

local baseURL = "https://author.today"

local dkjson = Require("dkjson")
local utf8 = Require("utf8")

local ORDER_BY_FILTER = 3
local ORDER_BY_VALUES = {
	"По популярности",
	"по новизне",
	"по количеству лайков",
	"по просмотрам",
	"по комментариям",
	"набирающие популярность",
}

local ORDER_BY_TERMS = {
	"popular",
	"recent",
	"likes",
	"views",
	"comments",
	"trending",
}

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
local function decrypt(key, encrypt, userID)
	if userID == "null" or tonumber(userID) == nil then userID = nil end
	-- Reverse the key and append a special string "@_@" to it.
	local fixedKey = utf8.reverse(key) .. "@_@" .. (userID or "")
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
			imageURL = v:select("img"):attr("data-src"):match("(.-)%?"),
		}
	end)
end

local function getPassage(chapterURL)
	local bookID, chapterID = string.match(chapterURL, "(%d+)/(%d+)")
	local resHTML = Request(GET(expandURL(chapterURL))):body():string()

	local chaptersRaw = string.match(resHTML, "chapters: (.-)%],") .. "]"
	local chaptersJson = dkjson.decode(chaptersRaw)
	local chapterTitle = ""

	for i, v in pairs(chaptersJson) do
		if tostring(v.id) == chapterID then
			chapterTitle = "<h1>" .. v.title .. "</h1>"
			break
		end
	end

	local res = Request(GET(baseURL .. "/reader/" .. bookID .. "/chapter?id=" .. chapterID))
	local key = res:headers():get("reader-secret")
	local userId = string.match(resHTML, "userId: ([^,]+)")
	local json = dkjson.decode(res:body():string())

	local chapterText = decrypt(key, json.data.text, userId)
	return pageOfElem(Document(chapterTitle .. chapterText), true)
end

local function parseNovel(novelURL, loadChapters)
	local doc = GETDocument(expandURL(novelURL, KEY_NOVEL_URL))

	local novel = NovelInfo {
		title = doc:select("h1.book-title, h1.card-title"):text(),
		imageURL = doc:select(".cover-image"):attr("src"):match("(.-)%?"),
		description = doc:select(".annotation, .card-description"):text(),
		authors = { doc:select('meta[itemprop="name"]'):attr("content") }
	}

	if doc:select(".card-author > a"):size() > 0 then
		novel:setAuthors(map(
			doc:select(".card-author > a"), function(name)
				return name:text()
			end)
		)
	end

	novel:setTags(map(
		doc:select(".tags > a, span.tag-text"), function(tags)
			return tags:text()
		end)
	)

	if doc:select("span.label:nth-child(1), label.label"):text():match("процессе") then
		novel:setStatus(NovelStatus.PUBLISHING)
	else
		novel:setStatus(NovelStatus.COMPLETED)
	end

	if loadChapters then
		local chapterHtml = doc:select("#tab-chapters > ul > li, .list-unstyled >li.clearfix")
		local chapterList = map(chapterHtml, function(v, i)
			local chapterInfo = v:select("a")
			if chapterInfo:size() > 0 then
				return NovelChapter {
					title = chapterInfo:text(),
					link = string.gsub(chapterInfo:attr("href"), "/reader/", ""),
					release = v:select("span > span"):attr("data-time"),
					order = i
				}
			end
		end)
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

	listings = {
		Listing("Novel List", true, function(data)
			local sort = ORDER_BY_TERMS[data[ORDER_BY_FILTER] + 1]
			local url = baseURL .. "/work/genre/all/?sorting=" .. sort .. "&page=" .. data[PAGE]

			local d = GETDocument(url)
			return map(d:select("a.work-row, div.book-row"), function(v)
				return Novel {
					title = v:select('h4[class="work-title"], div.book-title'):text(),
					link = v:select("a"):attr("href"):gsub("[^%d]", ""),
					imageURL = v:select("img"):attr("data-src"):match("(.-)%?"),
				}
			end)
		end)
	},
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
