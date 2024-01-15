-- {"id":702,"ver":"1.0.0","libVer":"1.0.0","author":"Rider21","dep":["dkjson>=1.0.1","url>=1.0.0"]}

local url = Require("url")
local dkjson = Require("dkjson")
local baseURL = "https://novel.tl"

local function shrinkURL(url)
	return url:gsub("https://", "")
end

local function expandURL(url)
	return "https://" .. url
end

local function getSearch(data)
	local tags = {}
	local genres = {}

	for k, v in pairs(data) do
		if v then
			if (k > 10 and k < 99) then
				table.insert(genres, k - 10)
			elseif (k > 100) then
				table.insert(tags, k - 100)
			end
		end
	end


	local requestTable = {
		operationName = "Projects",
		query =
		"query Projects($hostname:String! $filter:SearchFilter $page:Int $limit:Int){projects(section:{fullUrl:$hostname}filter:$filter page:{pageSize:$limit,pageNumber:$page}){content{title fullUrl covers{url}}}}",
		variables = {
			hostname = "novel.tl",
			page = data[PAGE],
			limit = 40,
			filter = {
				tags = tags,
				genres = genres
			}
		}
	}

	if data[0] then --search
		requestTable.variables.filter.query = data[0]
	end

	local result = dkjson.POST("https://novel.tl/api/site/v2/graphql", requestTable)
	return map(result.data.projects.content, function(v)
		return Novel {
			title = v.title,
			link = v.fullUrl, --domain different
			imageURL = baseURL .. v.covers[1].url
		}
	end)
end

local function getPassage(chapterURL)
	local result = dkjson.POST("https://novel.tl/api/site/v2/graphql", {
		query = "query($url:String){chapter(chapter:{fullUrl:$url}){title text{text}}}",
		variables = {
			url = expandURL(url.decode(chapterURL)),
		},
	})

	local chap = Document(result.data.chapter.text.text)
	chap:child(0):before("<h1>" .. result.data.chapter.title .. "</h1>");

	map(chap:select("img"), function(v)
		if not string.match(v:attr("src") or v:attr("data-src"), "[a-z]*://[^ >,;]*") then
			v:attr("src", baseURL .. (v:attr("src") or v:attr("data-src")))
		end
	end)

	return pageOfElem(chap)
end

local function parseNovel(novelURL, loadChapters)
	local result = dkjson.POST("https://novel.tl/api/site/v2/graphql", {
		operationName = "Book",
		query =
		'query Book($url:String){project(project:{fullUrl:$url}){title translationStatus fullUrl covers{url}persons(langs:["ru","en","*"],roles:"author"){role name{firstName lastName}}genres{nameRu nameEng}tags{nameRu nameEng}annotation{text}subprojects{content{title volumes{content{shortName chapters{title publishDate fullUrl published}}}}}}}',
		variables = {
			url = novelURL,
		}
	})

	local novel = NovelInfo {
		title = result.data.project.title,
		genres = map(result.data.project.genres, function(v) return v.nameRu or v.nameEng end),
		tags = map(result.data.project.tags, function(v) return v.nameRu or v.nameEng end),
		imageURL = baseURL .. result.data.project.covers[1].url,
		description = Document(result.data.project.annotation.text):text(),
		status = NovelStatus(
			result.data.project.translationStatus == "completed" and 1 or
			result.data.project.translationStatus == "freezed" and 2 or
			result.data.project.translationStatus == "active" and 0 or 3
		)
	}

	if #result.data.project.persons > 0 then
		novel:setAuthors(map(result.data.project.persons, function(v)
			local authorName = ""
			if v.name then
				if v.name.firstName and v.name.lastName then
					authorName = v.name.firstName .. " " .. v.name.lastName
				elseif v.name.firstName then
					authorName = v.name.firstName
				elseif v.name.lastName then
					authorName = v.name.lastName
				end
			end
			return authorName
		end))
	end

	if loadChapters then
		local chapterList = {}
		local chapterOrder = 0
		for k1, work in pairs(result.data.project.subprojects.content) do
			for k2, volumes in pairs(work.volumes.content) do
				for k3, chapter in pairs(volumes.chapters) do
					if chapter.published and chapter.fullUrl then
						table.insert(chapterList, NovelChapter {
							title = (volumes.shortName or "Том " .. k2) .. " " .. chapter.title,
							link = chapter.fullUrl,
							release = chapter.publishDate,
							order = chapterOrder
						});
						chapterOrder = chapterOrder + 1
					end
				end
			end
		end
		novel:setChapters(AsList(chapterList))
	end

	return novel
end

return {
	id = 702,
	name = "NovelTL",
	baseURL = baseURL,
	imageURL = "https://novel.tl/logo.png",
	chapterType = ChapterType.HTML,

	listings = {
		Listing("Novel List", true, function(data)
			return getSearch(data)
		end)
	},
	getPassage = getPassage,
	parseNovel = parseNovel,

	hasSearch = true,
	isSearchIncrementing = false,
	search = getSearch,
	searchFilters = {
		FilterGroup("Жанры", { --offset: 10
			CheckboxFilter(11, "16+"), --ID: 1
			CheckboxFilter(12, "18+"), --ID: 2
			CheckboxFilter(13, "Боевик"), --ID: 3
			CheckboxFilter(14, "Боевые искусства"), --ID: 4
			CheckboxFilter(57, "Вампиры"), --ID: 47
			CheckboxFilter(54, "Военное"), --ID: 44
			CheckboxFilter(15, "Гарем"), --ID: 5
			CheckboxFilter(58, "Демоны"), --ID: 48
			CheckboxFilter(16, "Детектив"), --ID: 6
			CheckboxFilter(60, "Дзёсей"), --ID: 50
			CheckboxFilter(17, "Драма"), --ID: 7
			CheckboxFilter(55, "Игры"), --ID: 45
			CheckboxFilter(18, "Историческое"), --ID: 8
			CheckboxFilter(19, "Киберпанк"), --ID: 9
			CheckboxFilter(20, "Комедия"), --ID: 10
			CheckboxFilter(56, "Космос"), --ID: 46
			CheckboxFilter(52, "Магия"), --ID: 42
			CheckboxFilter(22, "Махо-сёдзё"), --ID: 12
			CheckboxFilter(23, "Меха"), --ID: 13
			CheckboxFilter(24, "Мистика"), --ID: 14
			CheckboxFilter(59, "Музыка"), --ID: 49
			CheckboxFilter(25, "Научная фантастика"), --ID: 15
			CheckboxFilter(26, "Пародия"), --ID: 16
			CheckboxFilter(27, "Повседневность"), --ID: 17
			CheckboxFilter(28, "Приключения"), --ID: 18
			CheckboxFilter(29, "Психологическое"), --ID: 19
			CheckboxFilter(30, "Романтика"), --ID: 20
			CheckboxFilter(31, "Сверхъестественное"), --ID: 21
			CheckboxFilter(32, "Сёдзё"), --ID: 22
			CheckboxFilter(33, "Сёдзё-ай"), --ID: 23
			CheckboxFilter(34, "Сёнэн"), --ID: 24
			CheckboxFilter(35, "Сёнэн-ай"), --ID: 25
			CheckboxFilter(36, "Смена пола"), --ID: 26
			CheckboxFilter(37, "Современность"), --ID: 27
			CheckboxFilter(38, "Спорт"), --ID: 28
			CheckboxFilter(53, "Супер сила"), --ID: 43
			CheckboxFilter(39, "Сэйнэн"), --ID: 29
			CheckboxFilter(42, "Трагедия"), --ID: 32
			CheckboxFilter(43, "Триллер"), --ID: 33
			CheckboxFilter(44, "Ужасы"), --ID: 34
			CheckboxFilter(45, "Уся"), --ID: 35
			CheckboxFilter(46, "Фэнтези"), --ID: 36
			CheckboxFilter(47, "Школьная жизнь"), --ID: 37
			CheckboxFilter(48, "Этти"), --ID: 38
			CheckboxFilter(49, "Юри"), --ID: 39
			CheckboxFilter(50, "Яой"), --ID: 40
			CheckboxFilter(51, "LitRPG"), --ID: 41
		}),
		FilterGroup("Тэги", { --offset: 100
			CheckboxFilter(164, "Автоматы"), --ID: 64
			CheckboxFilter(126, "Агрессивные персонажи"), --ID: 26
			CheckboxFilter(438, "Ад"), --ID: 338
			CheckboxFilter(108, "Адаптация манги"), --ID: 8
			CheckboxFilter(105, "Академия"), --ID: 5
			CheckboxFilter(107, "Актёрское искусство"), --ID: 7
			CheckboxFilter(846, "Актеры озвучки"), --ID: 746
			CheckboxFilter(127, "Алхимия"), --ID: 27
			CheckboxFilter(130, "Альтернативная реальность"), --ID: 30
			CheckboxFilter(131, "Амнезия"), --ID: 31
			CheckboxFilter(270, "Анабиоз"), --ID: 170
			CheckboxFilter(133, "Анал"), --ID: 33
			CheckboxFilter(138, "Ангелы"), --ID: 38
			CheckboxFilter(137, "Андроиды"), --ID: 37
			CheckboxFilter(125, "Анти-рост персонажа"), --ID: 25
			CheckboxFilter(143, "Антигерой"), --ID: 43
			CheckboxFilter(144, "Антикварный магазин"), --ID: 44
			CheckboxFilter(141, "Антимагия"), --ID: 41
			CheckboxFilter(325, "Антиутопия"), --ID: 225
			CheckboxFilter(146, "Апатичный главный герой"), --ID: 46
			CheckboxFilter(147, "Апокалипсис"), --ID: 47
			CheckboxFilter(151, "Аристократия"), --ID: 51
			CheckboxFilter(153, "Армия"), --ID: 53
			CheckboxFilter(158, "Артефакты"), --ID: 58
			CheckboxFilter(142, "Асоциальный главный герой"), --ID: 42
			CheckboxFilter(161, "Ассасины"), --ID: 61
			CheckboxFilter(345, "Атмосфера Европы"), --ID: 245
			CheckboxFilter(402, "Банды"), --ID: 302
			CheckboxFilter(177, "БДСМ"), --ID: 77
			CheckboxFilter(641, "Бедный главный герой"), --ID: 541
			CheckboxFilter(243, "Бездушный главный герой"), --ID: 143
			CheckboxFilter(215, "Беззаботный герой"), --ID: 115
			CheckboxFilter(313, "Безответная любовь"), --ID: 213
			CheckboxFilter(840, "Безответная любовь"), --ID: 740
			CheckboxFilter(477, "Безработные"), --ID: 377
			CheckboxFilter(651, "Беременность"), --ID: 551
			CheckboxFilter(833, "Бескорыстная любовь"), --ID: 733
			CheckboxFilter(459, "Бессмертные"), --ID: 359
			CheckboxFilter(374, "Бесстрашный главный герой"), --ID: 274
			CheckboxFilter(493, "Библиотека"), --ID: 393
			CheckboxFilter(186, "Биография"), --ID: 86
			CheckboxFilter(829, "Близнецы"), --ID: 729
			CheckboxFilter(853, "Богачи"), --ID: 753
			CheckboxFilter(418, "Боги"), --ID: 318
			CheckboxFilter(416, "Богини"), --ID: 316
			CheckboxFilter(414, "Богоподобный протагонист"), --ID: 314
			CheckboxFilter(175, "Боевая академия"), --ID: 75
			CheckboxFilter(647, "Боевая парочка"), --ID: 547
			CheckboxFilter(308, "Божественная защита"), --ID: 208
			CheckboxFilter(417, "Божественная сила"), --ID: 317
			CheckboxFilter(748, "Болеющие персонажи"), --ID: 648
			CheckboxFilter(648, "Борьба за власть"), --ID: 548
			CheckboxFilter(155, "Брак по расчету"), --ID: 55
			CheckboxFilter(206, "Братство"), --ID: 106
			CheckboxFilter(746, "Братья или сёстры"), --ID: 646
			CheckboxFilter(101, "Брошенные дети"), --ID: 1
			CheckboxFilter(390, "Бывший герой"), --ID: 290
			CheckboxFilter(842, "Вампиры"), --ID: 742
			CheckboxFilter(596, "Ваншот"), --ID: 496
			CheckboxFilter(103, "Вдали от родителей"), --ID: 3
			CheckboxFilter(856, "Ведьмы"), --ID: 756
			CheckboxFilter(511, "Везучий главный герой"), --ID: 411
			CheckboxFilter(510, "Верные подданные"), --ID: 410
			CheckboxFilter(524, "Вероломные герои/плетение интриг"), --ID: 424
			CheckboxFilter(124, "Взросление персонажа"), --ID: 24
			CheckboxFilter(717, "Видит то, чего остальной люд не в силах"), --ID: 617
			CheckboxFilter(844, "Виртуальная реальность"), --ID: 744
			CheckboxFilter(777, "Владелец магазина"), --ID: 677
			CheckboxFilter(836, "Владелец уникального оружия"), --ID: 736
			CheckboxFilter(645, "Властные персонажи"), --ID: 545
			CheckboxFilter(617, "Влияние прошлого"), --ID: 517
			CheckboxFilter(791, "Внезапное обогащение"), --ID: 691
			CheckboxFilter(790, "Внезапное обретение силы"), --ID: 690
			CheckboxFilter(849, "Военные хроники"), --ID: 749
			CheckboxFilter(687, "Возвращение в родной мир"), --ID: 587
			CheckboxFilter(850, "Война"), --ID: 750
			CheckboxFilter(845, "Вокалоид"), --ID: 745
			CheckboxFilter(513, "Волшебные твари"), --ID: 413
			CheckboxFilter(686, "Воскрешение"), --ID: 586
			CheckboxFilter(637, "Воспитанный главный герой"), --ID: 537
			CheckboxFilter(383, "Воспоминания прошлого"), --ID: 283
			CheckboxFilter(338, "Враги становятся союзниками"), --ID: 238
			CheckboxFilter(403, "Врата в иной мир"), --ID: 303
			CheckboxFilter(811, "Временной парадокс"), --ID: 711
			CheckboxFilter(328, "Вторжение на Землю"), --ID: 228
			CheckboxFilter(708, "Второй шанс"), --ID: 608
			CheckboxFilter(795, "Выживание"), --ID: 695
			CheckboxFilter(387, "Вынужденные условия проживания"), --ID: 287
			CheckboxFilter(156, "Высокомерный герой"), --ID: 56
			CheckboxFilter(307, "Гадание"), --ID: 207
			CheckboxFilter(289, "Галлюцинации"), --ID: 189
			CheckboxFilter(756, "Гарем рабов"), --ID: 656
			CheckboxFilter(401, "Геймеры"), --ID: 301
			CheckboxFilter(406, "Генетические модификации"), --ID: 306
			CheckboxFilter(441, "Герои"), --ID: 341
			CheckboxFilter(136, "Герои непонятного пола"), --ID: 36
			CheckboxFilter(815, "Героиня девушка-сорванец"), --ID: 715
			CheckboxFilter(181, "Героиня красавица"), --ID: 81
			CheckboxFilter(661, "Герой влюбляется первым"), --ID: 561
			CheckboxFilter(736, "Герой использует щит"), --ID: 636
			CheckboxFilter(429, "Герой красавец"), --ID: 329
			CheckboxFilter(664, "Герой со множеством тел"), --ID: 564
			CheckboxFilter(732, "Герой-бесстыдник"), --ID: 632
			CheckboxFilter(621, "Герой-извращенец"), --ID: 521
			CheckboxFilter(430, "Герой-трудяга"), --ID: 330
			CheckboxFilter(521, "Герой-яндере"), --ID: 421
			CheckboxFilter(442, "Гетерохромия"), --ID: 342
			CheckboxFilter(424, "Гильдии"), --ID: 324
			CheckboxFilter(609, "Гиперопека"), --ID: 509
			CheckboxFilter(377, "Главная героиня — женщина"), --ID: 277
			CheckboxFilter(408, "Главный герой - гений"), --ID: 308
			CheckboxFilter(546, "Главный герой - Моб"), --ID: 446
			CheckboxFilter(363, "Главный герой — знаменитость"), --ID: 263
			CheckboxFilter(519, "Главный герой — мужчина"), --ID: 419
			CheckboxFilter(431, "Главный герой в поисках гарема"), --ID: 331
			CheckboxFilter(657, "Главный герой заранее готовится"), --ID: 557
			CheckboxFilter(588, "Главный герой не человек"), --ID: 488
			CheckboxFilter(120, "Главный герой приёмный"), --ID: 20
			CheckboxFilter(663, "Главный герой сразу силён"), --ID: 563
			CheckboxFilter(410, "Гладиаторы"), --ID: 310
			CheckboxFilter(294, "Глухой к любви герой"), --ID: 194
			CheckboxFilter(413, "Гоблины"), --ID: 313
			CheckboxFilter(419, "Големы"), --ID: 319
			CheckboxFilter(447, "Гомункул"), --ID: 347
			CheckboxFilter(518, "Горничные"), --ID: 418
			CheckboxFilter(312, "Государственные интриги"), --ID: 212
			CheckboxFilter(422, "Гринд"), --ID: 322
			CheckboxFilter(618, "Давняя травма"), --ID: 518
			CheckboxFilter(197, "Двойник"), --ID: 97
			CheckboxFilter(211, "Дворецкие"), --ID: 111
			CheckboxFilter(324, "Дворфы"), --ID: 224
			CheckboxFilter(587, "Дворяне"), --ID: 487
			CheckboxFilter(262, "Двоюродные братья или сёстры"), --ID: 162
			CheckboxFilter(515, "Девочки-волшебницы"), --ID: 415
			CheckboxFilter(293, "Демоны"), --ID: 193
			CheckboxFilter(296, "Депрессия"), --ID: 196
			CheckboxFilter(298, "Детектив"), --ID: 198
			CheckboxFilter(573, "Детективное расследование"), --ID: 473
			CheckboxFilter(225, "Детское насилие"), --ID: 125
			CheckboxFilter(230, "Детское обещание"), --ID: 130
			CheckboxFilter(303, "Дискриминация"), --ID: 203
			CheckboxFilter(500, "Длительный разрыв отношений"), --ID: 400
			CheckboxFilter(145, "Домашняя жизнь"), --ID: 45
			CheckboxFilter(318, "Драконы"), --ID: 218
			CheckboxFilter(134, "Древний Китай"), --ID: 34
			CheckboxFilter(393, "Дружба"), --ID: 293
			CheckboxFilter(228, "Друзья детства"), --ID: 128
			CheckboxFilter(392, "Друзья становятся врагами"), --ID: 292
			CheckboxFilter(773, "Духи"), --ID: 673
			CheckboxFilter(765, "Духовная сила"), --ID: 665
			CheckboxFilter(771, "Духовный наставник"), --ID: 671
			CheckboxFilter(435, "Душещипательная история"), --ID: 335
			CheckboxFilter(766, "Души"), --ID: 666
			CheckboxFilter(292, "Дьявольский путь культивации"), --ID: 192
			CheckboxFilter(863, "Ёкай"), --ID: 763
			CheckboxFilter(110, "Есть аниме-адаптация"), --ID: 10
			CheckboxFilter(113, "Есть видеоигра"), --ID: 13
			CheckboxFilter(111, "Есть дорама-адаптация"), --ID: 11
			CheckboxFilter(114, "Есть манга-адаптация"), --ID: 14
			CheckboxFilter(116, "Есть манхва-адаптация"), --ID: 16
			CheckboxFilter(115, "Есть маньхуа-адаптация"), --ID: 15
			CheckboxFilter(117, "Есть фильм"), --ID: 17
			CheckboxFilter(112, "Есть CD дорама-адаптация"), --ID: 12
			CheckboxFilter(697, "Жёсткий главный герой"), --ID: 597
			CheckboxFilter(104, "Жестокие персонажи"), --ID: 4
			CheckboxFilter(269, "Жёстокие персонажи"), --ID: 169
			CheckboxFilter(178, "Животное-спутник"), --ID: 78
			CheckboxFilter(496, "Жизнь в одиночку"), --ID: 396
			CheckboxFilter(655, "Жрецы"), --ID: 555
			CheckboxFilter(654, "Жрицы"), --ID: 554
			CheckboxFilter(227, "Забота о детях"), --ID: 127
			CheckboxFilter(216, "Заботливый главный герой"), --ID: 116
			CheckboxFilter(571, "Загадочное заболевание"), --ID: 471
			CheckboxFilter(570, "Загадочное прошлое родителей"), --ID: 470
			CheckboxFilter(254, "Заговоры"), --ID: 154
			CheckboxFilter(196, "Закалка тела"), --ID: 96
			CheckboxFilter(782, "Закон джунглей"), --ID: 682
			CheckboxFilter(703, "Закулисная борба"), --ID: 603
			CheckboxFilter(471, "Замкнутый главный герой"), --ID: 371
			CheckboxFilter(707, "Запечатанная сила"), --ID: 607
			CheckboxFilter(446, "Затворник"), --ID: 346
			CheckboxFilter(180, "Звери"), --ID: 80
			CheckboxFilter(139, "Зверолюди"), --ID: 39
			CheckboxFilter(179, "Звероподобные"), --ID: 79
			CheckboxFilter(368, "Земледелие"), --ID: 268
			CheckboxFilter(843, "Злобные благородные девы"), --ID: 743
			CheckboxFilter(347, "Зловещие организации"), --ID: 247
			CheckboxFilter(348, "Злой главный герой"), --ID: 248
			CheckboxFilter(346, "Злые боги"), --ID: 246
			CheckboxFilter(349, "Злые религии"), --ID: 249
			CheckboxFilter(218, "Знаменитости"), --ID: 118
			CheckboxFilter(653, "Знания из прошлой жизни"), --ID: 553
			CheckboxFilter(867, "Зомби"), --ID: 767
			CheckboxFilter(796, "Игра на выживание"), --ID: 696
			CheckboxFilter(400, "Игровая рейтинговая система"), --ID: 300
			CheckboxFilter(642, "Из грязи в князи"), --ID: 542
			CheckboxFilter(362, "Известные родители"), --ID: 262
			CheckboxFilter(148, "Изменение внешнего вида"), --ID: 48
			CheckboxFilter(674, "Изнасилование"), --ID: 574
			CheckboxFilter(302, "Инвалидность"), --ID: 202
			CheckboxFilter(464, "Индустриализация"), --ID: 364
			CheckboxFilter(341, "Инженер"), --ID: 241
			CheckboxFilter(461, "Инцест"), --ID: 361
			CheckboxFilter(830, "Искажённая личность"), --ID: 730
			CheckboxFilter(159, "Искусственный интеллект"), --ID: 59
			CheckboxFilter(855, "Исполнение желаний"), --ID: 755
			CheckboxFilter(213, "Каннибализм"), --ID: 113
			CheckboxFilter(214, "Карточные игры"), --ID: 114
			CheckboxFilter(421, "Кладбищенский смотритель"), --ID: 321
			CheckboxFilter(234, "Классика"), --ID: 134
			CheckboxFilter(199, "Книги"), --ID: 99
			CheckboxFilter(754, "Книги навыков"), --ID: 654
			CheckboxFilter(200, "Книжный червь"), --ID: 100
			CheckboxFilter(240, "Коллеги"), --ID: 140
			CheckboxFilter(245, "Колледж/Университет"), --ID: 145
			CheckboxFilter(801, "Командная работа"), --ID: 701
			CheckboxFilter(247, "Комедийный подтекст"), --ID: 147
			CheckboxFilter(205, "Комплекс брата"), --ID: 105
			CheckboxFilter(465, "Комплекс неполноценности"), --ID: 365
			CheckboxFilter(255, "Контракты"), --ID: 155
			CheckboxFilter(541, "Контроль разума"), --ID: 441
			CheckboxFilter(361, "Конфликт в семье"), --ID: 261
			CheckboxFilter(253, "Конфликт верности"), --ID: 153
			CheckboxFilter(768, "Копейщик"), --ID: 668
			CheckboxFilter(696, "Королевская особа"), --ID: 596
			CheckboxFilter(482, "Королевства"), --ID: 382
			CheckboxFilter(738, "Короткий рассказ"), --ID: 638
			CheckboxFilter(257, "Коррупция"), --ID: 157
			CheckboxFilter(258, "Космические Войны"), --ID: 158
			CheckboxFilter(607, "Космос"), --ID: 507
			CheckboxFilter(259, "Косплей"), --ID: 159
			CheckboxFilter(102, "Кража способностей"), --ID: 2
			CheckboxFilter(264, "Крафтинг"), --ID: 164
			CheckboxFilter(457, "Кризис личности"), --ID: 357
			CheckboxFilter(420, "Кровь"), --ID: 320
			CheckboxFilter(238, "Кружки, клубы"), --ID: 138
			CheckboxFilter(484, "Кудэрэ"), --ID: 384
			CheckboxFilter(190, "Кузнец"), --ID: 90
			CheckboxFilter(667, "Кукловоды"), --ID: 567
			CheckboxFilter(311, "Куклы/Марионетки"), --ID: 211
			CheckboxFilter(256, "Кулинария"), --ID: 156
			CheckboxFilter(271, "Культивация"), --ID: 171
			CheckboxFilter(272, "Куннилингус"), --ID: 172
			CheckboxFilter(491, "Легенды"), --ID: 391
			CheckboxFilter(329, "Легкая жизнь"), --ID: 229
			CheckboxFilter(434, "Лекари"), --ID: 334
			CheckboxFilter(489, "Ленивый главный герой"), --ID: 389
			CheckboxFilter(490, "Лидерство"), --ID: 390
			CheckboxFilter(865, "Любит персонажа младше себя"), --ID: 765
			CheckboxFilter(594, "Любит персонажа старше себя"), --ID: 494
			CheckboxFilter(506, "Любовное соперничество"), --ID: 406
			CheckboxFilter(507, "Любовные треугольники"), --ID: 407
			CheckboxFilter(229, "Любовь детства"), --ID: 129
			CheckboxFilter(504, "Любовь с первого взгляда"), --ID: 404
			CheckboxFilter(315, "Любящие родители"), --ID: 215
			CheckboxFilter(857, "Маги"), --ID: 757
			CheckboxFilter(517, "Магические технологии"), --ID: 417
			CheckboxFilter(512, "Магия"), --ID: 412
			CheckboxFilter(794, "Магия призыва"), --ID: 694
			CheckboxFilter(497, "Маленькие девочки"), --ID: 397
			CheckboxFilter(523, "Мангака"), --ID: 423
			CheckboxFilter(592, "Маниакальная любовь"), --ID: 492
			CheckboxFilter(608, "Марти Сью"), --ID: 508
			CheckboxFilter(322, "Мастер подземелий"), --ID: 222
			CheckboxFilter(532, "Мастурбация"), --ID: 432
			CheckboxFilter(533, "Матриархат"), --ID: 433
			CheckboxFilter(470, "Межпространственные путешествия"), --ID: 370
			CheckboxFilter(522, "Менеджмент"), --ID: 422
			CheckboxFilter(688, "Месть"), --ID: 588
			CheckboxFilter(797, "Мечи и магия"), --ID: 697
			CheckboxFilter(798, "Мечники"), --ID: 698
			CheckboxFilter(276, "Миленькие дети"), --ID: 176
			CheckboxFilter(539, "Милитаризм"), --ID: 439
			CheckboxFilter(278, "Миловидная история"), --ID: 178
			CheckboxFilter(277, "Милый главный герой"), --ID: 177
			CheckboxFilter(375, "Минет"), --ID: 275
			CheckboxFilter(860, "Мировое древо"), --ID: 760
			CheckboxFilter(610, "Миролюбивый главный герой"), --ID: 510
			CheckboxFilter(575, "Мифология"), --ID: 475
			CheckboxFilter(866, "Младшие сёстры"), --ID: 766
			CheckboxFilter(545, "ММОРПГ"), --ID: 445
			CheckboxFilter(563, "Множество временных линий"), --ID: 463
			CheckboxFilter(547, "Модели"), --ID: 447
			CheckboxFilter(149, "Молод не по годам"), --ID: 49
			CheckboxFilter(554, "Монстры"), --ID: 454
			CheckboxFilter(283, "Мрачность"), --ID: 183
			CheckboxFilter(566, "Музыка"), --ID: 466
			CheckboxFilter(168, "Музыкальные группы"), --ID: 68
			CheckboxFilter(568, "Мутации"), --ID: 468
			CheckboxFilter(579, "На волосок от смерти"), --ID: 479
			CheckboxFilter(474, "На все руки мастер"), --ID: 374
			CheckboxFilter(250, "Навыки имеют стоимость"), --ID: 150
			CheckboxFilter(590, "Нагота"), --ID: 490
			CheckboxFilter(316, "Наездники на драконах"), --ID: 216
			CheckboxFilter(537, "Наёмники"), --ID: 437
			CheckboxFilter(576, "Наивный главный герой"), --ID: 476
			CheckboxFilter(466, "Наследие"), --ID: 366
			CheckboxFilter(300, "Настоящая любовь"), --ID: 200
			CheckboxFilter(640, "Настоящий гарем"), --ID: 540
			CheckboxFilter(437, "Небесное испытание"), --ID: 337
			CheckboxFilter(838, "Невезучий главный герой"), --ID: 738
			CheckboxFilter(306, "Недоверчивый протагонист"), --ID: 206
			CheckboxFilter(834, "Недооцененный главный герой"), --ID: 734
			CheckboxFilter(544, "Недопонимание"), --ID: 444
			CheckboxFilter(580, "Некромант"), --ID: 480
			CheckboxFilter(589, "Нелинейное повествование"), --ID: 489
			CheckboxFilter(167, "Неловкий главный герой"), --ID: 67
			CheckboxFilter(433, "Нелюбимый протагонист"), --ID: 333
			CheckboxFilter(569, "Немой персонаж"), --ID: 469
			CheckboxFilter(839, "Ненадежный рассказчик"), --ID: 739
			CheckboxFilter(165, "Непримечательный герой"), --ID: 65
			CheckboxFilter(463, "Нерешительный протагонист"), --ID: 363
			CheckboxFilter(776, "Несгибаемый главный герой"), --ID: 676
			CheckboxFilter(560, "Несколько главных героев"), --ID: 460
			CheckboxFilter(561, "Несколько миров"), --ID: 461
			CheckboxFilter(562, "Несколько перерожденцев"), --ID: 462
			CheckboxFilter(564, "Несколько попаданцев"), --ID: 464
			CheckboxFilter(369, "Несравненная скорость культивации"), --ID: 269
			CheckboxFilter(485, "Нехватка/отсутствие здравого смысла"), --ID: 385
			CheckboxFilter(305, "Нечестный протагонист"), --ID: 205
			CheckboxFilter(581, "НИИТ"), --ID: 481
			CheckboxFilter(586, "Ниндзя"), --ID: 486
			CheckboxFilter(195, "Обмен телами"), --ID: 95
			CheckboxFilter(854, "Оборотни"), --ID: 754
			CheckboxFilter(505, "Объект любви влюбился первым"), --ID: 405
			CheckboxFilter(643, "Объект любви популярен"), --ID: 543
			CheckboxFilter(380, "Огнестрельное оружие"), --ID: 280
			CheckboxFilter(494, "Ограничение на время жизни"), --ID: 394
			CheckboxFilter(644, "Одержимость"), --ID: 544
			CheckboxFilter(751, "Один родитель"), --ID: 651
			CheckboxFilter(499, "Одинокий главный герой"), --ID: 399
			CheckboxFilter(498, "Одиночество"), --ID: 398
			CheckboxFilter(734, "Одно тело на двоих"), --ID: 634
			CheckboxFilter(353, "Око силы"), --ID: 253
			CheckboxFilter(598, "Оммёдзи"), --ID: 498
			CheckboxFilter(600, "Организованная преступность"), --ID: 500
			CheckboxFilter(601, "Оргия"), --ID: 501
			CheckboxFilter(599, "Орки"), --ID: 499
			CheckboxFilter(174, "Основано на аниме"), --ID: 74
			CheckboxFilter(172, "Основано на видеоигре"), --ID: 72
			CheckboxFilter(173, "Основано на визуальной новелле"), --ID: 73
			CheckboxFilter(170, "Основано на песне"), --ID: 70
			CheckboxFilter(169, "Основано на фильме"), --ID: 69
			CheckboxFilter(217, "Осторожный главный герой"), --ID: 117
			CheckboxFilter(339, "От ненависти до любви один шаг"), --ID: 239
			CheckboxFilter(784, "От сильного с сильнейшему"), --ID: 684
			CheckboxFilter(852, "От слабого к сильному"), --ID: 752
			CheckboxFilter(603, "Отаку"), --ID: 503
			CheckboxFilter(480, "Отзывчивая любовь"), --ID: 380
			CheckboxFilter(439, "Отзывчивый главный герой"), --ID: 339
			CheckboxFilter(530, "Отношение учитель-ученик"), --ID: 430
			CheckboxFilter(415, "Отношения бог-человек"), --ID: 315
			CheckboxFilter(787, "Отношения между учителем и учеником"), --ID: 687
			CheckboxFilter(201, "Отношения начальник-подчинённый"), --ID: 101
			CheckboxFilter(386, "Отношения против воли"), --ID: 286
			CheckboxFilter(453, "Отношения с нечеловеком"), --ID: 353
			CheckboxFilter(721, "Отношения сэмпай-кохай"), --ID: 621
			CheckboxFilter(531, "Отношения хозяин-слуга"), --ID: 431
			CheckboxFilter(604, "Отомэ-игры"), --ID: 504
			CheckboxFilter(662, "ОТП"), --ID: 562
			CheckboxFilter(605, "Отшельники"), --ID: 505
			CheckboxFilter(700, "Офисный работник"), --ID: 600
			CheckboxFilter(848, "Официанты"), --ID: 748
			CheckboxFilter(455, "Охотники"), --ID: 355
			CheckboxFilter(355, "Падшие ангелы"), --ID: 255
			CheckboxFilter(356, "Падшие дворяне"), --ID: 256
			CheckboxFilter(611, "Пайзури"), --ID: 511
			CheckboxFilter(613, "Паразиты"), --ID: 513
			CheckboxFilter(612, "Параллельные миры"), --ID: 512
			CheckboxFilter(132, "Парк развлечений"), --ID: 32
			CheckboxFilter(615, "Пародия"), --ID: 515
			CheckboxFilter(858, "Перемещение между мирами"), --ID: 758
			CheckboxFilter(267, "Переодевание"), --ID: 167
			CheckboxFilter(629, "Переплавка пилюль"), --ID: 529
			CheckboxFilter(520, "Перерождение в девушку"), --ID: 420
			CheckboxFilter(680, "Перерождение в другом мире"), --ID: 580
			CheckboxFilter(820, "Перерождение в другом мире"), --ID: 720
			CheckboxFilter(679, "Перерождение в игровом мире"), --ID: 579
			CheckboxFilter(677, "Перерождение в монстра"), --ID: 577
			CheckboxFilter(529, "Персонажи с мазохистскими наклонностями"), --ID: 429
			CheckboxFilter(698, "Персонажи с садистскими наклонностями"), --ID: 598
			CheckboxFilter(809, "Петля времени"), --ID: 709
			CheckboxFilter(428, "Петтинг"), --ID: 328
			CheckboxFilter(861, "Писатели"), --ID: 761
			CheckboxFilter(622, "Питомцы"), --ID: 522
			CheckboxFilter(826, "Племенное общество"), --ID: 726
			CheckboxFilter(291, "Повелитель демонов"), --ID: 191
			CheckboxFilter(559, "Повествование от нескольких лиц"), --ID: 459
			CheckboxFilter(753, "Поглощение навыков"), --ID: 653
			CheckboxFilter(323, "Подземелья"), --ID: 223
			CheckboxFilter(487, "Поздно начинающаяся романтическая линия"), --ID: 387
			CheckboxFilter(638, "Политика"), --ID: 538
			CheckboxFilter(290, "Полулюди"), --ID: 190
			CheckboxFilter(340, "Помолвка"), --ID: 240
			CheckboxFilter(823, "Попаданец в другой мир"), --ID: 723
			CheckboxFilter(822, "Попаданец в игровой мир"), --ID: 722
			CheckboxFilter(646, "Постапокалипсис"), --ID: 546
			CheckboxFilter(281, "Постижение Дао"), --ID: 181
			CheckboxFilter(382, "Потеря девственности"), --ID: 282
			CheckboxFilter(516, "Потустороннее пространство"), --ID: 416
			CheckboxFilter(479, "Похищения"), --ID: 379
			CheckboxFilter(649, "Прагматичный главный герой"), --ID: 549
			CheckboxFilter(183, "Предательство"), --ID: 83
			CheckboxFilter(650, "Предвидение"), --ID: 550
			CheckboxFilter(774, "Преследователи"), --ID: 674
			CheckboxFilter(265, "Преступление"), --ID: 165
			CheckboxFilter(266, "Преступность"), --ID: 166
			CheckboxFilter(119, "Приёмные дети"), --ID: 19
			CheckboxFilter(793, "Призванный герой"), --ID: 693
			CheckboxFilter(409, "Призраки"), --ID: 309
			CheckboxFilter(122, "Приключения"), --ID: 22
			CheckboxFilter(208, "Принуждение"), --ID: 108
			CheckboxFilter(553, "Приручатель"), --ID: 453
			CheckboxFilter(725, "Прислуга"), --ID: 625
			CheckboxFilter(236, "Приставучий любовник"), --ID: 136
			CheckboxFilter(652, "Притворная любовь"), --ID: 552
			CheckboxFilter(128, "Пришельцы"), --ID: 28
			CheckboxFilter(658, "Программист"), --ID: 558
			CheckboxFilter(166, "Произведение - обладатель наград"), --ID: 66
			CheckboxFilter(275, "Проклятия"), --ID: 175
			CheckboxFilter(202, "Промывка мозгов"), --ID: 102
			CheckboxFilter(812, "Пропуск времени"), --ID: 712
			CheckboxFilter(659, "Пророчества"), --ID: 559
			CheckboxFilter(412, "Протагонист в очках"), --ID: 312
			CheckboxFilter(757, "Протагонист раб"), --ID: 657
			CheckboxFilter(665, "Психокинез"), --ID: 565
			CheckboxFilter(666, "Психопаты"), --ID: 566
			CheckboxFilter(859, "Путешествия"), --ID: 759
			CheckboxFilter(813, "Путешествия во времени"), --ID: 713
			CheckboxFilter(816, "Пытки"), --ID: 716
			CheckboxFilter(758, "Рабы"), --ID: 658
			CheckboxFilter(260, "Развитие отношений"), --ID: 160
			CheckboxFilter(219, "Развитие персонажа"), --ID: 119
			CheckboxFilter(558, "Раздвоение личности"), --ID: 458
			CheckboxFilter(761, "Размеренная романтика"), --ID: 661
			CheckboxFilter(301, "Разница в статусе"), --ID: 201
			CheckboxFilter(204, "Разорванная помолвка"), --ID: 104
			CheckboxFilter(722, "Разумные предметы"), --ID: 622
			CheckboxFilter(436, "Рай"), --ID: 336
			CheckboxFilter(327, "Раняя романтика"), --ID: 227
			CheckboxFilter(673, "Расизм"), --ID: 573
			CheckboxFilter(472, "Расследования"), --ID: 372
			CheckboxFilter(226, "Ребенок — главный герой"), --ID: 126
			CheckboxFilter(689, "Реверс-гарем"), --ID: 589
			CheckboxFilter(690, "Реверс-изнасилование"), --ID: 590
			CheckboxFilter(620, "Резкая смена характера"), --ID: 520
			CheckboxFilter(681, "Реинкарнация"), --ID: 581
			CheckboxFilter(682, "Религии"), --ID: 582
			CheckboxFilter(685, "Ресторан"), --ID: 585
			CheckboxFilter(299, "Решительный главный герой"), --ID: 199
			CheckboxFilter(814, "Робкий протагонист"), --ID: 714
			CheckboxFilter(614, "Родительсткий комплекс"), --ID: 514
			CheckboxFilter(747, "Родные не связанные кровью"), --ID: 647
			CheckboxFilter(194, "Родословные"), --ID: 94
			CheckboxFilter(492, "РПГ-система"), --ID: 392
			CheckboxFilter(483, "Рыцари"), --ID: 383
			CheckboxFilter(577, "Самовлюбленный главный герой"), --ID: 477
			CheckboxFilter(792, "Самоубийства"), --ID: 692
			CheckboxFilter(701, "Самураи"), --ID: 601
			CheckboxFilter(244, "Сборник коротких историй"), --ID: 144
			CheckboxFilter(526, "Свадьба"), --ID: 426
			CheckboxFilter(469, "Связанные сюжетные линии"), --ID: 369
			CheckboxFilter(699, "Святые"), --ID: 599
			CheckboxFilter(714, "Секреты"), --ID: 614
			CheckboxFilter(807, "Секс втроём"), --ID: 707
			CheckboxFilter(729, "Секс-рабыня"), --ID: 629
			CheckboxFilter(357, "Семейная любовь"), --ID: 257
			CheckboxFilter(727, "Семь добродетелей"), --ID: 627
			CheckboxFilter(726, "Семь смертных грехов"), --ID: 626
			CheckboxFilter(724, "Серийные убийцы"), --ID: 624
			CheckboxFilter(737, "Сикигами"), --ID: 637
			CheckboxFilter(314, "Сильная любовь от старших"), --ID: 214
			CheckboxFilter(232, "Синдром восьмиклассника"), --ID: 132
			CheckboxFilter(752, "Синдром сестры"), --ID: 652
			CheckboxFilter(602, "Сироты"), --ID: 502
			CheckboxFilter(799, "Системный администратор"), --ID: 699
			CheckboxFilter(509, "Скромный главный герой"), --ID: 409
			CheckboxFilter(123, "Скрытые романтические отношения"), --ID: 23
			CheckboxFilter(443, "Скрытые способности"), --ID: 343
			CheckboxFilter(550, "Скряга"), --ID: 450
			CheckboxFilter(706, "Скульпторы"), --ID: 606
			CheckboxFilter(788, "Слабая романтика"), --ID: 688
			CheckboxFilter(851, "Слабый главный герой"), --ID: 751
			CheckboxFilter(249, "Сложные семейные отношения"), --ID: 149
			CheckboxFilter(672, "Смена расы"), --ID: 572
			CheckboxFilter(804, "Смертельное заболевание"), --ID: 704
			CheckboxFilter(285, "Смерть"), --ID: 185
			CheckboxFilter(286, "Смерть любимых"), --ID: 186
			CheckboxFilter(548, "Современность"), --ID: 448
			CheckboxFilter(549, "Современные знания в слаборазвитых мирах"), --ID: 449
			CheckboxFilter(241, "Сожительство"), --ID: 141
			CheckboxFilter(157, "Создание артефактов"), --ID: 57
			CheckboxFilter(233, "Создание клана"), --ID: 133
			CheckboxFilter(481, "Создание королевства"), --ID: 381
			CheckboxFilter(755, "Создание навыков"), --ID: 655
			CheckboxFilter(444, "Сокрытие истинных способностей"), --ID: 344
			CheckboxFilter(445, "Сокрытие личности"), --ID: 345
			CheckboxFilter(764, "Солдаты"), --ID: 664
			CheckboxFilter(759, "Сон"), --ID: 659
			CheckboxFilter(695, "Соседи по комнате"), --ID: 595
			CheckboxFilter(763, "Социальные изгои"), --ID: 663
			CheckboxFilter(702, "Спасение мира"), --ID: 602
			CheckboxFilter(184, "Спорящая пара"), --ID: 84
			CheckboxFilter(819, "Способность перевоплощения"), --ID: 719
			CheckboxFilter(536, "Средневековье"), --ID: 436
			CheckboxFilter(743, "Стеснительные персонажи"), --ID: 643
			CheckboxFilter(675, "Стокгольмский синдром"), --ID: 575
			CheckboxFilter(775, "Стокгольмский синдром"), --ID: 675
			CheckboxFilter(781, "Стратег"), --ID: 681
			CheckboxFilter(780, "Стратегические битвы"), --ID: 680
			CheckboxFilter(425, "Стрелки"), --ID: 325
			CheckboxFilter(150, "Стрельба из лука"), --ID: 50
			CheckboxFilter(786, "Студенческий совет"), --ID: 686
			CheckboxFilter(297, "Судьба"), --ID: 197
			CheckboxFilter(789, "Суккубы"), --ID: 689
			CheckboxFilter(769, "Суперспособности"), --ID: 669
			CheckboxFilter(432, "Суровая тренировка"), --ID: 332
			CheckboxFilter(295, "Сцены насилия"), --ID: 195
			CheckboxFilter(572, "Таинственное прошлое"), --ID: 472
			CheckboxFilter(710, "Тайная личность"), --ID: 610
			CheckboxFilter(711, "Тайные организации"), --ID: 611
			CheckboxFilter(198, "Телохранители"), --ID: 98
			CheckboxFilter(803, "Тентакли"), --ID: 703
			CheckboxFilter(805, "Террористы"), --ID: 705
			CheckboxFilter(802, "Технологический разрыв"), --ID: 702
			CheckboxFilter(668, "Тихие герои"), --ID: 568
			CheckboxFilter(371, "Толстый протагонист"), --ID: 271
			CheckboxFilter(538, "Торговцы"), --ID: 438
			CheckboxFilter(440, "Травник"), --ID: 340
			CheckboxFilter(818, "Трагичное прошлое"), --ID: 718
			CheckboxFilter(825, "Трап"), --ID: 725
			CheckboxFilter(808, "Триллер"), --ID: 708
			CheckboxFilter(176, "Турнир"), --ID: 76
			CheckboxFilter(656, "Тюрьма"), --ID: 556
			CheckboxFilter(565, "Убийства"), --ID: 465
			CheckboxFilter(251, "Уверенный в себе главный герой"), --ID: 151
			CheckboxFilter(762, "Умная пара"), --ID: 662
			CheckboxFilter(235, "Умный главный герой"), --ID: 135
			CheckboxFilter(835, "Уникальная техника культивации"), --ID: 735
			CheckboxFilter(837, "Уникальные оружия"), --ID: 737
			CheckboxFilter(209, "Управление бизнесом"), --ID: 109
			CheckboxFilter(810, "Управление временем"), --ID: 710
			CheckboxFilter(767, "Управление пространством"), --ID: 667
			CheckboxFilter(106, "Ускоренный рост"), --ID: 6
			CheckboxFilter(705, "Учёные"), --ID: 605
			CheckboxFilter(800, "Учителя"), --ID: 700
			CheckboxFilter(358, "Фамильяры"), --ID: 258
			CheckboxFilter(364, "Фанатизм"), --ID: 264
			CheckboxFilter(623, "Фармацевт"), --ID: 523
			CheckboxFilter(354, "Феи"), --ID: 254
			CheckboxFilter(626, "Фениксы"), --ID: 526
			CheckboxFilter(203, "Фетиш на грудь"), --ID: 103
			CheckboxFilter(411, "Фетиш на очки"), --ID: 311
			CheckboxFilter(624, "Философия"), --ID: 524
			CheckboxFilter(625, "Фобии/Страхи"), --ID: 525
			CheckboxFilter(385, "Фольклор"), --ID: 285
			CheckboxFilter(154, "Формирование армии"), --ID: 54
			CheckboxFilter(395, "Футанари"), --ID: 295
			CheckboxFilter(396, "Футуристический мир"), --ID: 296
			CheckboxFilter(367, "Фэнтези"), --ID: 267
			CheckboxFilter(366, "Фэнтезийные существа"), --ID: 266
			CheckboxFilter(426, "Хакеры"), --ID: 326
			CheckboxFilter(220, "Харизматичный протагонист"), --ID: 120
			CheckboxFilter(273, "Хитрый главный герой"), --ID: 173
			CheckboxFilter(212, "Хладнокровный главный герой"), --ID: 112
			CheckboxFilter(160, "Художники"), --ID: 60
			CheckboxFilter(288, "Хулиганы"), --ID: 188
			CheckboxFilter(828, "Цундере"), --ID: 728
			CheckboxFilter(222, "Чат"), --ID: 122
			CheckboxFilter(452, "Человек-оружие"), --ID: 352
			CheckboxFilter(454, "Человекоподобный главный герой"), --ID: 354
			CheckboxFilter(448, "Честный главный герой"), --ID: 348
			CheckboxFilter(783, "Четкие любовные убеждения"), --ID: 683
			CheckboxFilter(223, "Читы"), --ID: 123
			CheckboxFilter(669, "Чудаковатые герои"), --ID: 569
			CheckboxFilter(821, "Чужие воспоминания"), --ID: 721
			CheckboxFilter(189, "Шантаж"), --ID: 89
			CheckboxFilter(224, "Шеф-повар"), --ID: 124
			CheckboxFilter(129, "Школа для девочек"), --ID: 29
			CheckboxFilter(742, "Шоу-бизнес"), --ID: 642
			CheckboxFilter(770, "Шпионы"), --ID: 670
			CheckboxFilter(350, "Эволюция"), --ID: 250
			CheckboxFilter(718, "Эгоистичный главный герой"), --ID: 618
			CheckboxFilter(352, "Экзорцизм"), --ID: 252
			CheckboxFilter(330, "Экономика"), --ID: 230
			CheckboxFilter(351, "Эксгибиционизм"), --ID: 251
			CheckboxFilter(451, "Эксперименты на людях"), --ID: 351
			CheckboxFilter(334, "Элементальная магия"), --ID: 234
			CheckboxFilter(399, "Элементы игрового мира"), --ID: 299
			CheckboxFilter(694, "Элементы романтики"), --ID: 594
			CheckboxFilter(740, "Элементы юри"), --ID: 640
			CheckboxFilter(741, "Элементы яоя"), --ID: 641
			CheckboxFilter(335, "Эльфы"), --ID: 235
			CheckboxFilter(343, "Эпизодичность"), --ID: 243
			CheckboxFilter(735, "Язвительные персонажи"), --ID: 635
			CheckboxFilter(486, "Языковой барьер"), --ID: 386
			CheckboxFilter(862, "Яндере"), --ID: 762
			CheckboxFilter(394, "Яойщица"), --ID: 294
			CheckboxFilter(478, "Японские силы самообороны"), --ID: 378
			CheckboxFilter(670, "R-15"), --ID: 570
			CheckboxFilter(671, "R-18"), --ID: 571
		}),
	},
	shrinkURL = shrinkURL,
	expandURL = expandURL
}
