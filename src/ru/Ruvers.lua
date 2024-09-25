-- {"id":711,"ver":"1.0.0","libVer":"1.0.0","author":"Rider21","dep":["dkjson>=1.0.1"]}

local baseURL = "https://ruvers.ru/"

local json = Require("dkjson")

local SORT_BY_FILTER = 3
local SORT_BY_VALUES = { "По названию", "По дате добавления", "По рейтингу" }
local SORT_BY_TERMS = { "name", "-created_at", "-rating" }

local function shrinkURL(url)
	return url:gsub(baseURL .. "/", "")
end

local function expandURL(url)
	return baseURL .. "/" .. url
end

local function getSearch(data)
	local url = baseURL .. "api/books?page=" .. data[PAGE] ..
		"&sort=" .. SORT_BY_TERMS[data[SORT_BY_FILTER] + 1]

	if data[0] then --search
		url = url .. "&search=" .. data[0]
	end

	local response = json.GET(url)

	return map(response.data, function(v)
		return Novel {
			title = v.name,
			link = v.slug,
			imageURL = (v.images[0] and baseURL .. v.images[0]) or ""
		}
	end)
end

local function getPassage(chapterURL)
	local doc = GETDocument(baseURL .. chapterURL)
	local chap = doc:select(".chapter_text > books-chapters-text-component"):attr(":text")

	return pageOfElem(Document(chap))
end

local function parseNovel(novelURL, loadChapters)
	local response = GETDocument(expandURL(novelURL))

	local novel = NovelInfo {
		title = response:select("div.name > h1"):text(),
		genres = map(response:select(".genres > a"), function(genres) return genres:text() end),
		imageURL = response:select(".slider_prods_single > img"):attr("src"),
		description = response:select(".book_description"):text(),
		--status
	}

	if loadChapters then
		local bookId = response:select("comments-list"):attr("commentable-id");
		local chapterJson = json.GET(baseURL .. "api/books/" .. bookId .. "/chapters/all")
		local chapterList = {}
		for k, v in pairs(chapterJson.data) do
			if v.is_published and v.is_free or v.purchased_by_user then
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
