-- {"id":74,"ver":"1.0.2","libVer":"1.0.0","author":"Rider21"}

local baseURL = "https://jaomix.ru"

local ORDER_BY_FILTER = 3
local ORDER_BY_VALUES = { "Дате добавления", "Имя", "Просмотры", "Дате обновления",
	"Топ дня", "Топ недели", "Топ месяца", "Топ года", "Топ за все время" }
local ORDER_BY_TERMS = { "new", "alphabet", "count", "upd", "topday", "topweek", "topyear", "alltime" }

local LANGUAGE_FILTER = 4
local LANGUAGE_VALUES = {
	"Английский",
	"Китайский",
	"Корейский",
	"Японский"
}

local GENRE_FILTER = 10
local GENRE_VALUES = {
	"Боевые Искусства",
	"Виртуальный Мир",
	"Гарем",
	"Детектив",
	"Драма",
	"Игра",
	"Истории из жизни",
	"Исторический",
	"История",
	"Исэкай",
	"Комедия",
	"Меха",
	"Мистика",
	"Научная Фантастика",
	"Повседневность",
	"Постапокалипсис",
	"Приключения",
	"Психология",
	"Романтика",
	"Сверхъестественное",
	"Сёнэн",
	"Сёнэн-ай",
	"Спорт",
	"Сэйнэн",
	"Сюаньхуа",
	"Трагедия",
	"Триллер",
	"Фантастика",
	"Фэнтези",
	"Хоррор",
	"Школьная жизнь",
	"Шоунен",
	"Экшн",
	"Этти",
	"Юри",
	"Adult",
	"Ecchi",
	"Josei",
	"Lolicon",
	"Mature",
	"Shoujo",
	"Wuxia",
	"Xianxia",
	"Xuanhuan",
	"Yaoi"
}

local function shrinkURL(url)
	return url:gsub(baseURL .. "/", "")
end

local function expandURL(url)
	return baseURL .. "/" .. url
end

local function split(str, pat)
	local t = {}
	for str in string.gmatch(str, "([^" .. pat .. "]+)") do
		table.insert(t, str)
	end
	return t
end

local function getSearch(data)
	local url = baseURL .. "/?searchrn"

	if data[0] then --search
		url = url .. "=" .. data[0] .. "&but=Поиск+по+названию"
	end

	for k, v in pairs(data) do
		if v then
			if (k > 4 and k < 10) then
				url = url .. "&lang[]=" .. LANGUAGE_VALUES[k - LANGUAGE_FILTER]
			elseif (k > 10 and k < 100) then
				url = url .. "&genre[]=" .. GENRE_VALUES[k - GENRE_FILTER]
			end
		end
	end

	url = url .. "&sortby=" .. ORDER_BY_TERMS[data[ORDER_BY_FILTER] + 1] .. "&page=" .. data[PAGE]

	local d = GETDocument(url)
	return map(d:select("div.one div.img-home > a"), function(v)
		return Novel {
			title = v:attr("title"),
			link = shrinkURL(v:attr("href")),
			imageURL = v:select("img"):attr("src"):gsub("-150x150", "")
		}
	end)
end

local function getPassage(chapterURL)
	local d = GETDocument(expandURL(chapterURL))
	local chap = d:selectFirst(".entry-content")
	chap:select(".adblock-service"):remove()
	chap:child(0):before("<h1>" .. d:select(".entry-title"):text() .. "</h1>");

	return pageOfElem(chap, true)
end

local function parseNovel(novelURL, loadChapters)
	local d = GETDocument(expandURL(novelURL))

	local novel = NovelInfo {
		title = d:select('h1[itemprop="name"]'):text(),
		imageURL = d:select(".img-book > img"):attr("src"),
		description = d:select("#desc-tab"):text()
	}

	map(d:select('#info-book > p'), function(v)
		local str = v:text()
		if str:match("Автор:") then
			novel:setAuthors(split(str:gsub("Автор: ", ""), ", "))
		elseif str:match("Жанры:") then
			novel:setGenres(split(str:gsub("Жанры: ", ""), ", "))
		elseif str:match("Статус:") then
			if str:match("продолжается") then
				novel:setStatus(NovelStatus(0))
			else
				novel:setStatus(NovelStatus(1))
			end
		end
	end)

	if loadChapters then
		local chapterHtml = d:select(".download-chapter div.title")
		local order = chapterHtml:size()
		local chapterList = map(chapterHtml, function(v, i)
			return NovelChapter {
				title = v:select("a"):attr("title"),
				link = shrinkURL(v:select("a"):attr("href")),
				release = v:select("time"):text(),
				order = order - i
			}
		end)
		novel:setChapters(AsList(chapterList))
	end
	return novel
end

return {
	id = 74,
	name = "Jaomix",
	baseURL = baseURL,
	imageURL = "https://jaomix.ru/wp-content/uploads/2019/08/cropped-logo-2.png",
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
		DropdownFilter(ORDER_BY_FILTER, "Сортировка", ORDER_BY_VALUES),
		FilterGroup("Страна", map(LANGUAGE_VALUES, function(v, i)
			return CheckboxFilter(LANGUAGE_FILTER + i, v)
		end)),
		FilterGroup("Жанры", map(GENRE_VALUES, function(v, i)
			return CheckboxFilter(GENRE_FILTER + i, v)
		end))
	},

	shrinkURL = shrinkURL,
	expandURL = expandURL
}
