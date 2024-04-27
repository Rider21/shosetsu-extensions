-- {"id":73,"ver":"2.1.0","libVer":"1.0.0","author":"Rider21","dep":["dkjson>=1.0.1"]}

local baseURL = "https://ranobelib.me"
local apiURL = "https://api.lib.social/api/manga"
local dkjson = Require("dkjson")

local ORDER_BY_FILTER = 3
local ORDER_BY_VALUES = {
	"По рейтингу",
	"По просмотрам",
	"Количеству глав",
	"Дате обновления",
	"Дате добавления",
	"По названию (A-Z)",
	"По названию (А-Я)"
}
local ORDER_BY_TERMS = {
	"rate_avg",
	"rating_score",
	"views",
	"chap_count",
	"last_chapter",
	"created_at",
	"name",
	"rus_name"
}
local allfields =
"?fields[]=summary&fields[]=genres&fields[]=tags&fields[]=teams&fields[]=authors&fields[]=status_id&fields[]=artists"

local function shrinkURL(url)
	return url:gsub(baseURL .. "/", "")
end

local function expandURL(path, type)
	if type == KEY_NOVEL_URL then
		return baseURL .. "/ru/book/" .. path
	end

	local slug, volume, number, branch_id = string.match(path, "([^/]+)/([^/]+)/([^/]+)")
	if branch_id then
		branch_id = "?bid=" .. branch_id
	else
		branch_id = ""
	end

	local chapterPath = slug .. "/read/v" .. volume .. "/c" .. number .. branch_id
	return baseURL .. "/ru/" .. chapterPath
end

local function getSearch(data)
	local url = apiURL .. "?site_id[]=3&page=" .. data[PAGE]
	if data[ORDER_BY_FILTER] then
		url = url .. "&sort_by=" .. ORDER_BY_TERMS[data[ORDER_BY_FILTER] + 1]
	else
		url = url .. "&sort_by=rating_score"
	end

	for k, v in pairs(data) do
		if v then
			if (k > 9 and k < 16) then
				url = url .. "&types[]=" .. k
			elseif (k > 16 and k < 21) then
				url = url .. "&scanlateStatus[]=" .. k - 16
			elseif (k > 99 and k < 199) then
				url = url .. "&genres[]=" .. k - 100
			elseif (k > 199 and k < 600) then
				url = url .. "&tags[]=" .. k - 200
			end
		end
	end


	if data[0] then --search
		url = url .. "&q=" .. data[0]
	end

	local result = dkjson.GET(url)
	return map(result.data, function(v)
		return Novel {
			title = v.rus_name or v.name,
			link = v.slug_url or v.id .. "--" .. v.slug,
			imageURL = v.cover.default
		}
	end)
end

local function getPassage(chapterURL)
	local slug, volume, number, branch_id = string.match(chapterURL, "([^/]+)/([^/]+)/([^/]+)")
	if branch_id then
		branch_id = "branch_id=" .. branch_id .. "&"
	else
		branch_id = ""
	end

	local url = apiURL .. "/" .. slug .. "/chapter?" .. branch_id .. "number=" .. number .. "&volume=" .. volume
	local doc = dkjson.GET(url)

	local chap = doc.data.content
	if chap.type == "doc" then
		local html = map(chap.content, function(v)
			if v.type == "paragraph" then
				local br = v.text
				if type(v.content) == "table" then
					br = table.concat(map(v.content, function(e) return e.text end), "<br>")
				end
				if br then
					return "<p>" .. br .. "</p>"
				else
					return "<br>"
				end
			end
			if v.type == "image" then
				return '<img alt="" src="' .. v.attrs.images[0].image .. '" />'
			end
		end)
		chap = table.concat(html, "")
	end

	return pageOfElem(Document(chap))
end

local function parseNovel(novelURL, loadChapters)
	local response = dkjson.GET(apiURL .. "/" .. novelURL .. allfields).data

	local novel = NovelInfo {
		title = response.rus_name or response.name,
		genres = map(response.genres, function(v) return v.name end),
		tags = map(response.tags, function(v) return v.name end),
		imageURL = response.cover.default,
		description = response.summary,
		status = ({ NovelStatus.PUBLISHING, NovelStatus.COMPLETED, NovelStatus.PAUSED, NovelStatus.COMPLETED })
			[response.status.id]
	}

	if #response.authors > 0 then
		novel:setAuthors(map(response.authors, function(v)
			return v.name or ""
		end))
	end
	if #response.artists > 0 then
		novel.setArtists(map(response.artists, function(v)
			return v.name or ""
		end))
	end

	if loadChapters then
		local chapterJson = dkjson.GET(apiURL .. "/" .. novelURL .. "/chapters").data
		local chapterList = {}
		for k, chapter in pairs(chapterJson) do
			table.insert(chapterList, NovelChapter {
				title = "Том " .. chapter.volume .. " Глава " .. chapter.number .. " " .. chapter.name,
				release = chapter.branches[1].created_at,
				link = novelURL .. "/" .. chapter.volume .. "/" .. chapter.number .. "/" .. (chapter.branches[1].branch_id or ""),
				order = chapter.index,
			});
		end
		novel:setChapters(AsList(chapterList))
	end
	return novel
end

return {
	id = 73,
	name = "Ranobelib",
	baseURL = baseURL,
	imageURL = "https://ranobelib.me/images/logo/rl/icon.png",
	chapterType = ChapterType.HTML,

	listings = {
		Listing("Novel List", true, function(data)
			return getSearch(data)
		end)
	},
	getPassage = getPassage,
	parseNovel = parseNovel,

	hasCloudFlare = true,
	hasSearch = true,
	isSearchIncrementing = true,
	search = getSearch,
	searchFilters = {
		DropdownFilter(ORDER_BY_FILTER, "Сортировка", ORDER_BY_VALUES),
		FilterGroup("Жанры", { --offset: 100
			CheckboxFilter(132, "Арт"), --ID: 32
			CheckboxFilter(191, "Безумие"), --ID: 91
			CheckboxFilter(134, "Боевик"), --ID: 34
			CheckboxFilter(135, "Боевые искусства"), --ID: 35
			CheckboxFilter(136, "Вампиры"), --ID: 36
			CheckboxFilter(189, "Военное"), --ID: 89
			CheckboxFilter(137, "Гарем"), --ID: 37
			CheckboxFilter(138, "Гендерная интрига"), --ID: 38
			CheckboxFilter(139, "Героическое фэнтези"), --ID: 39
			CheckboxFilter(181, "Демоны"), --ID: 81
			CheckboxFilter(140, "Детектив"), --ID: 40
			CheckboxFilter(141, "Дзёсэй"), --ID: 41
			CheckboxFilter(143, "Драма"), --ID: 43
			CheckboxFilter(144, "Игра"), --ID: 44
			CheckboxFilter(179, "Исекай"), --ID: 79
			CheckboxFilter(145, "История"), --ID: 45
			CheckboxFilter(146, "Киберпанк"), --ID: 46
			CheckboxFilter(176, "Кодомо"), --ID: 76
			CheckboxFilter(147, "Комедия"), --ID: 47
			CheckboxFilter(183, "Космос"), --ID: 83
			CheckboxFilter(185, "Магия"), --ID: 85
			CheckboxFilter(148, "Махо-сёдзё"), --ID: 48
			CheckboxFilter(190, "Машины"), --ID: 90
			CheckboxFilter(149, "Меха"), --ID: 49
			CheckboxFilter(150, "Мистика"), --ID: 50
			CheckboxFilter(180, "Музыка"), --ID: 80
			CheckboxFilter(151, "Научная фантастика"), --ID: 51
			CheckboxFilter(177, "Омегаверс"), --ID: 77
			CheckboxFilter(186, "Пародия"), --ID: 86
			CheckboxFilter(152, "Повседневность"), --ID: 52
			CheckboxFilter(182, "Полиция"), --ID: 82
			CheckboxFilter(153, "Постапокалиптика"), --ID: 53
			CheckboxFilter(154, "Приключения"), --ID: 54
			CheckboxFilter(155, "Психология"), --ID: 55
			CheckboxFilter(156, "Романтика"), --ID: 56
			CheckboxFilter(157, "Самурайский боевик"), --ID: 57
			CheckboxFilter(158, "Сверхъестественное"), --ID: 58
			CheckboxFilter(159, "Сёдзё"), --ID: 59
			CheckboxFilter(160, "Сёдзё-ай"), --ID: 60
			CheckboxFilter(161, "Сёнэн"), --ID: 61
			CheckboxFilter(162, "Сёнэн-ай"), --ID: 62
			CheckboxFilter(163, "Спорт"), --ID: 63
			CheckboxFilter(187, "Супер сила"), --ID: 87
			CheckboxFilter(164, "Сэйнэн"), --ID: 64
			CheckboxFilter(165, "Трагедия"), --ID: 65
			CheckboxFilter(166, "Триллер"), --ID: 66
			CheckboxFilter(167, "Ужасы"), --ID: 67
			CheckboxFilter(168, "Фантастика"), --ID: 68
			CheckboxFilter(169, "Фэнтези"), --ID: 69
			CheckboxFilter(184, "Хентай"), --ID: 84
			CheckboxFilter(170, "Школа"), --ID: 70
			CheckboxFilter(171, "Эротика"), --ID: 71
			CheckboxFilter(172, "Этти"), --ID: 72
			CheckboxFilter(173, "Юри"), --ID: 73
			CheckboxFilter(174, "Яой"), --ID: 74
		}),
		FilterGroup("Теги", { --offset: 200
			CheckboxFilter(528, "Авантюристы"), --ID: 328
			CheckboxFilter(375, "Антигерой"), --ID: 175
			CheckboxFilter(533, "Бессмертные"), --ID: 333
			CheckboxFilter(418, "Боги"), --ID: 218
			CheckboxFilter(509, "Борьба за власть"), --ID: 309
			CheckboxFilter(560, "Брат и сестра"), --ID: 360
			CheckboxFilter(539, "Ведьма"), --ID: 339
			CheckboxFilter(404, "Видеоигры"), --ID: 204
			CheckboxFilter(414, "Виртуальная реальность"), --ID: 214
			CheckboxFilter(549, "Владыка демонов"), --ID: 349
			CheckboxFilter(398, "Военные"), --ID: 198
			CheckboxFilter(510, "Воспоминания из другого мира"), --ID: 310
			CheckboxFilter(412, "Выживание"), --ID: 212
			CheckboxFilter(494, "ГГ женщина"), --ID: 294
			CheckboxFilter(492, "ГГ имба"), --ID: 292
			CheckboxFilter(495, "ГГ мужчина"), --ID: 295
			CheckboxFilter(525, "ГГ не ояш"), --ID: 325
			CheckboxFilter(531, "ГГ не человек"), --ID: 331
			CheckboxFilter(526, "ГГ ояш"), --ID: 326
			CheckboxFilter(524, "Главный герой бог"), --ID: 324
			CheckboxFilter(498, "Глупый ГГ"), --ID: 298
			CheckboxFilter(371, "Горничные"), --ID: 171
			CheckboxFilter(506, "Гуро"), --ID: 306
			CheckboxFilter(397, "Гяру"), --ID: 197
			CheckboxFilter(357, "Демоны"), --ID: 157
			CheckboxFilter(513, "Драконы"), --ID: 313
			CheckboxFilter(517, "Древний мир"), --ID: 317
			CheckboxFilter(363, "Зверолюди"), --ID: 163
			CheckboxFilter(355, "Зомби"), --ID: 155
			CheckboxFilter(523, "Исторические фигуры"), --ID: 323
			CheckboxFilter(358, "Кулинария"), --ID: 158
			CheckboxFilter(361, "Культивация"), --ID: 161
			CheckboxFilter(544, "ЛГБТ"), --ID: 344
			CheckboxFilter(519, "ЛитРПГ"), --ID: 319
			CheckboxFilter(406, "Лоли"), --ID: 206
			CheckboxFilter(370, "Магия"), --ID: 170
			CheckboxFilter(545, "Машинный перевод"), --ID: 345
			CheckboxFilter(359, "Медицина"), --ID: 159
			CheckboxFilter(530, "Межгалактическая война"), --ID: 330
			CheckboxFilter(407, "Монстр Девушки"), --ID: 207
			CheckboxFilter(408, "Монстры"), --ID: 208
			CheckboxFilter(516, "Мрачный мир"), --ID: 316
			CheckboxFilter(558, "Музыка"), --ID: 358
			CheckboxFilter(409, "Музыка"), --ID: 209
			CheckboxFilter(399, "Ниндзя"), --ID: 199
			CheckboxFilter(410, "Обратный Гарем"), --ID: 210
			CheckboxFilter(400, "Офисные Работники"), --ID: 200
			CheckboxFilter(541, "Пираты"), --ID: 341
			CheckboxFilter(514, "Подземелья"), --ID: 314
			CheckboxFilter(511, "Политика"), --ID: 311
			CheckboxFilter(401, "Полиция"), --ID: 201
			CheckboxFilter(405, "Преступники / Криминал"), --ID: 205
			CheckboxFilter(396, "Призраки / Духи"), --ID: 196
			CheckboxFilter(529, "Призыватели"), --ID: 329
			CheckboxFilter(521, "Прыжки между мирами"), --ID: 321
			CheckboxFilter(518, "Путешествие в другой мир"), --ID: 318
			CheckboxFilter(413, "Путешествие во времени"), --ID: 213
			CheckboxFilter(555, "Рабы"), --ID: 355
			CheckboxFilter(512, "Ранги силы"), --ID: 312
			CheckboxFilter(354, "Реинкарнация"), --ID: 154
			CheckboxFilter(402, "Самураи"), --ID: 202
			CheckboxFilter(515, "Скрытие личности"), --ID: 315
			CheckboxFilter(374, "Средневековье"), --ID: 174
			CheckboxFilter(403, "Традиционные игры"), --ID: 203
			CheckboxFilter(503, "Умный ГГ"), --ID: 303
			CheckboxFilter(532, "Характерный рост"), --ID: 332
			CheckboxFilter(367, "Хикикомори"), --ID: 167
			CheckboxFilter(522, "Эволюция"), --ID: 322
			CheckboxFilter(527, "Элементы РПГ"), --ID: 327
			CheckboxFilter(417, "Эльфы"), --ID: 217
			CheckboxFilter(365, "Якудза"), --ID: 165
		}),
		FilterGroup("Страна", {
			CheckboxFilter(10, "Япония"),
			CheckboxFilter(11, "Корея"),
			CheckboxFilter(12, "Китай"),
			CheckboxFilter(13, "Английский"),
			CheckboxFilter(14, "Авторский"),
			CheckboxFilter(15, "Фанфик"),
		}),
		FilterGroup("Статус перевода", { ---offset: 16
			CheckboxFilter(17, "Продолжается"), --ID: 1
			CheckboxFilter(18, "Завершен"), --ID: 2
			CheckboxFilter(19, "Заморожен"), --ID: 3
			CheckboxFilter(20, "Заброшен"), --ID:4
		})
	},
	shrinkURL = shrinkURL,
	expandURL = expandURL,
}
