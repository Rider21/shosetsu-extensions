-- {"id":711,"ver":"1.0.0","libVer":"1.0.0","author":"Rider21","dep":["dkjson>=1.0.1"]}

local baseURL = "https://ruvers.ru"
local json = Require("dkjson")

local SORT_BY_FILTER = 3
local SORT_BY_VALUES = { "По названию", "По дате добавления", "По рейтингу" }
local SORT_BY_TERMS = { "name", "-created_at", "-rating" }

local function unescapeUnicode(escapedString)
	-- This function replaces all occurrences of `\uXXXX` in the string
	-- with the corresponding unicode character.
	return (string.gsub(escapedString, "\\u(%x%x%x%x)", function(hexCode)
		-- Convert the hex code to a decimal number.
		local unicodeValue = tonumber("0x" .. hexCode)

		-- Handle different unicode ranges based on the value.
		if unicodeValue < 0x80 then
			-- For values less than 0x80, the character is simply the same as the unicode value.
			return string.char(unicodeValue)
		elseif unicodeValue < 0x800 then
			-- For values less than 0x800, the character is encoded in 2 bytes.
			local byte1 = unicodeValue % 64;
			unicodeValue = math.floor(unicodeValue / 64)
			return string.char(0xC0 + unicodeValue, 0x80 + byte1)
		elseif unicodeValue < 0x10000 then
			-- For values less than 0x10000, the character is encoded in 3 bytes.
			local byte1 = unicodeValue % 64;
			unicodeValue = math.floor(unicodeValue / 64)
			local byte2 = unicodeValue % 64;
			unicodeValue = math.floor(unicodeValue / 64)
			return string.char(0xE0 + unicodeValue, 0x80 + byte2, 0x80 + byte1)
		else
			-- For values greater than or equal to 0x10000, the character is encoded in 4 bytes.
			local byte1 = unicodeValue % 64;
			unicodeValue = math.floor(unicodeValue / 64)
			local byte2 = unicodeValue % 64;
			unicodeValue = math.floor(unicodeValue / 64)
			local byte3 = unicodeValue % 64;
			unicodeValue = math.floor(unicodeValue / 64)
			return string.char(0xF0 + unicodeValue, 0x80 + byte3, 0x80 + byte2, 0x80 + byte1)
		end
	end))
end

local function shrinkURL(url)
	return url:gsub(baseURL .. "/", "")
end

local function expandURL(url)
	return baseURL .. "/" .. url
end

local function getSearch(data)
	local url = baseURL .. "/api/books?page=" .. data[PAGE] ..
		"&sort=" .. SORT_BY_TERMS[data[SORT_BY_FILTER] + 1]

	if data[0] then --search
		url = url .. "&search=" .. data[0]
	end

	local response = json.GET(url)

	return map(response.data, function(v)
		return Novel {
			title = v.name,
			link = v.slug,
			imageURL = expandURL(v.images[1])
		}
	end)
end

local function getPassage(chapterURL)
	local doc = GETDocument(expandURL(chapterURL))
	local chap = doc:select(".chapter_text > books-chapters-text-component, .chapter_text > mobile-books-chapters-text-component")
	local chapterText = unescapeUnicode(chap:attr(":text"))

	return pageOfElem(Document(chapterText))
end

local function parseNovel(novelURL, loadChapters)
	local response = GETDocument(expandURL(novelURL))

	local novel = NovelInfo {
		title = response:select("div.name > h1"):text(),
		genres = map(response:select(".genres > a"), function(genres) return genres:text() end),
		imageURL = response:select(".slider_prods_single > img"):attr("src"),
		description = response:select(".book_description"):text(),
	}

	local status = response:select(".status_row > div:nth-child(1) > a"):text()
	if status == "В работе" then
		novel:setStatus(NovelStatus.PUBLISHING)
	elseif status == "Завершено" then
		novel:setStatus(NovelStatus.COMPLETED)
	end

	if loadChapters then
		local bookId = response:select("comments-list"):attr("commentable-id");
		local chapterJson = json.GET(baseURL .. "/api/books/" .. bookId .. "/chapters/all")
		local chapterList = {}
		for k, v in pairs(chapterJson.data) do
			if v.is_published and (v.is_free or v.purchased_by_user) then
				table.insert(chapterList, NovelChapter {
					title = "Глава " .. v.number .. " " .. (v.name or ""),
					link = novelURL .. "/" .. v.id,
					release = v.created_at,
					order = k
				});
			end
		end
		novel:setChapters(AsList(chapterList))
	end
	return novel
end

return {
	id = 711,
	name = "Ruvers",
	baseURL = baseURL,
	imageURL = "https://ruvers.ru/img/favicon/apple-touch-icon.png",
	chapterType = ChapterType.HTML,

	listings = {
		Listing("Novel List", true, function(data)
			return getSearch(data)
		end)
	},

	getPassage = getPassage,
	parseNovel = parseNovel,

	hasSearch = true,
	isSearchIncrementing = true,
	search = getSearch,
	searchFilters = {
		DropdownFilter(SORT_BY_FILTER, "Сортировка", SORT_BY_VALUES),
	},

	shrinkURL = shrinkURL,
	expandURL = expandURL,
}
