-- {"id":701,"ver":"2.0.0","libVer":"1.0.0","author":"Rider21","dep":["dkjson>=1.0.1"]}

local baseURL = "https://renovels.org"

local json = Require("dkjson")

local ORDER_BY_FILTER = 3
local ORDER_BY_VALUES = { "Рейтинг", "Просмотры", "Лайкам", "Дате добавления", "Дате обновления", "Количество глав" }
local ORDER_BY_TERMS = { "rating", "views", "votes", "id", "chapter_date", "count_chapters" }

local function shrinkURL(url)
	return url:gsub(baseURL .. "/", "")
end

local function expandURL(url, key)
	if key == KEY_NOVEL_URL then
		return baseURL .. "/novel/" .. url
	end
	return baseURL .. "/" .. url
end

local function getSearch(data)
	local url = "api/search?query=" .. data[QUERY] .. "&count=30&field=titles&page=" .. data[PAGE]
	local response = json.GET(expandURL(url))
	return map(response["content"], function(v)
		return Novel {
			title = v.main_name or v.secondary_name,
			link = v.dir,
			imageURL = baseURL .. (v.img.high or v.img.mid or v.img.low)
		}
	end)
end

local function getPassage(chapterURL)
	local doc = json.GET(expandURL("api/titles/chapters" .. chapterURL))
	local chap = Document(doc.content.content)
	chap:child(0):before("<h1>" .. "Том " .. doc.content.tome .. " Глава " .. doc.content.chapter .. ": " .. doc.content.name .. "</h1>");

	return pageOfElem(chap)
end

local function parseNovel(novelURL, loadChapters)
	local response = json.GET(expandURL("api/titles/" .. novelURL))

	local novel = NovelInfo {
		title = response.content.main_name or response.content.secondary_name,
		genres = map(response.content.genres, function(v) return v.name end),
		tags = map(response.content.categories, function(v) return v.name end),
		imageURL = baseURL .. (response.content.img.high or response.content.img.mid or response.content.img.low),
		description = Document(response.content.description):text(),
		status = NovelStatus(
			response.content.status.name == "Закончен" and 1 or
			response.content.status.name == "Заморожен" and 2 or
			response.content.status.name == "Продолжается" and 0 or 3
		)
	}

	if loadChapters then
		local all = response.content.branches[1].count_chapters / 100
		local chapterList = {}
		for i = 0, all do
			local chapterJson = json.GET(expandURL("api/titles/chapters?branch_id=" .. response.content.branches[1].id .. "&count=100&page=" .. (i + 1)))
			for k, v in pairs(chapterJson.content) do
				if not v.is_paid or v.is_bought then
					table.insert(chapterList, NovelChapter {
						title = "Том " .. v.tome .. " Глава " .. v.chapter .. ": " .. v.name,
						link = "/" .. v.id .. "/",
						release = v.upload_date,
						order = response.content.branches[1].count_chapters - k - i * 100
					});
				end
			end
		end
		novel:setChapters(AsList(chapterList))
	end
	return novel
end

return {
	id = 701,
	name = "Renovels",
	baseURL = baseURL,
	imageURL = "https://github.com/Rider21/shosetsu-extensions/raw/main/icons/Renovels.png",
	chapterType = ChapterType.HTML,

	listings = {
		Listing("Novel List", true, function(data)
			local url = "api/search/catalog?count=30&ordering=-" .. ORDER_BY_TERMS[data[ORDER_BY_FILTER] + 1]

			for k, v in pairs(data) do
				if v then
					if (k > 10 and k < 17) then
						url = url .. "&types=" .. k - 10
					elseif (k > 20 and k < 26) then
						url = url .. "&status=" .. k - 20
					elseif (k > 30 and k < 33) then
						url = url .. "&age_limit=" .. k - 30
					elseif (k > 100 and k < 199) then
						url = url .. "&genres=" .. k - 10
					elseif (k > 200 and k < 901) then
						url = url .. "&categories=" .. k - 100
					end
				end
			end

			local response = json.GET(expandURL(url .. "&page=" .. data[PAGE]))
			return map(response["content"], function(v)
				return Novel {
					title = v.main_name or v.secondary_name,
					link = v.dir,
					imageURL = baseURL .. (v.img.high or v.img.mid or v.img.low)
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
		FilterGroup("Жанры", { --offset: 10
			CheckboxFilter(122, "Боевик"), --ID: 112
			CheckboxFilter(133, "Война"), --ID: 123
			CheckboxFilter(124, "Детектив"), --ID: 114
			CheckboxFilter(135, "Драма"), --ID: 125
			CheckboxFilter(125, "Историческая проза"), --ID: 115
			CheckboxFilter(119, "ЛитРПГ"), --ID: 109
			CheckboxFilter(126, "Любовные романы"), --ID: 116
			CheckboxFilter(113, "Мистика"), --ID: 103
			CheckboxFilter(131, "Научная фантастика"), --ID: 121
			CheckboxFilter(138, "Повседневность"), --ID: 128
			CheckboxFilter(123, "Подростковая проза"), --ID: 113
			CheckboxFilter(129, "Политический роман"), --ID: 119
			CheckboxFilter(118, "Попаданцы"), --ID: 108
			CheckboxFilter(115, "Поэзия"), --ID: 105
			CheckboxFilter(121, "Разное"), --ID: 111
			CheckboxFilter(127, "РеалРПГ"), --ID: 117
			CheckboxFilter(136, "Романтика"), --ID: 126
			CheckboxFilter(112, "Современная проза"), --ID: 102
			CheckboxFilter(137, "Современная фантастика"), --ID: 127
			CheckboxFilter(132, "Спорт"), --ID: 122
			CheckboxFilter(139, "Трагедия"), --ID: 129
			CheckboxFilter(120, "Триллер"), --ID: 110
			CheckboxFilter(134, "Триллер и саспенс"), --ID: 124
			CheckboxFilter(116, "Ужасы"), --ID: 106
			CheckboxFilter(111, "Фантастика"), --ID: 101
			CheckboxFilter(117, "Фанфик"), --ID: 107
			CheckboxFilter(130, "Фьюжн роман"), --ID: 120
			CheckboxFilter(110, "Фэнтези"), --ID: 100
			CheckboxFilter(128, "Эротика"), --ID: 118
			CheckboxFilter(114, "Юмор"), --ID: 104
		}),
		FilterGroup("Теги", { --offset: 100
			CheckboxFilter(763, "Абьюзеры"), --ID: 663
			CheckboxFilter(536, "Авантюристы"), --ID: 436
			CheckboxFilter(693, "Автоматоны"), --ID: 593
			CheckboxFilter(602, "Агрессивные персонажи"), --ID: 502
			CheckboxFilter(669, "Ад"), --ID: 569
			CheckboxFilter(681, "Адаптация в радиопостановку"), --ID: 581
			CheckboxFilter(253, "Академия"), --ID: 153
			CheckboxFilter(727, "Актеры озвучки"), --ID: 627
			CheckboxFilter(351, "Активный главный герой"), --ID: 251
			CheckboxFilter(333, "Алхимия"), --ID: 233
			CheckboxFilter(247, "Альтернативная история"), --ID: 147
			CheckboxFilter(256, "Альтернативный мир"), --ID: 156
			CheckboxFilter(444, "Амнезия/Потеря памяти"), --ID: 344
			CheckboxFilter(785, "Анабиоз"), --ID: 685
			CheckboxFilter(283, "Ангелы"), --ID: 183
			CheckboxFilter(421, "Андрогинные персонажи"), --ID: 321
			CheckboxFilter(303, "Андроиды"), --ID: 203
			CheckboxFilter(633, "Анти-магия"), --ID: 533
			CheckboxFilter(532, "Антигерой"), --ID: 432
			CheckboxFilter(723, "Антикварный магазин"), --ID: 623
			CheckboxFilter(713, "Антисоциальный главный герой"), --ID: 613
			CheckboxFilter(242, "Антиутопия"), --ID: 142
			CheckboxFilter(257, "Апатичный протагонист"), --ID: 157
			CheckboxFilter(502, "Апокалипсис"), --ID: 402
			CheckboxFilter(475, "Аранжированный брак"), --ID: 375
			CheckboxFilter(739, "Армия"), --ID: 639
			CheckboxFilter(334, "Артефакты"), --ID: 234
			CheckboxFilter(623, "Артисты"), --ID: 523
			CheckboxFilter(730, "Банды"), --ID: 630
			CheckboxFilter(799, "БДСМ"), --ID: 699
			CheckboxFilter(498, "Бедный главный герой"), --ID: 398
			CheckboxFilter(361, "Безжалостный главный герой"), --ID: 261
			CheckboxFilter(538, "Беззаботный главный герой"), --ID: 438
			CheckboxFilter(779, "Безусловная любовь"), --ID: 679
			CheckboxFilter(350, "Беременность"), --ID: 250
			CheckboxFilter(425, "Бесполый главный герой"), --ID: 325
			CheckboxFilter(468, "Бессмертные"), --ID: 368
			CheckboxFilter(756, "Бесстрашный протагонист"), --ID: 656
			CheckboxFilter(452, "Бесстыдный главный герой"), --ID: 352
			CheckboxFilter(816, "Бесчестный главный герой"), --ID: 716
			CheckboxFilter(528, "Библиотека"), --ID: 428
			CheckboxFilter(221, "Бизнес-литература"), --ID: 121
			CheckboxFilter(869, "Бизнесмен"), --ID: 769
			CheckboxFilter(338, "Биочип"), --ID: 238
			CheckboxFilter(873, "Бисексуальный главный герой"), --ID: 773
			CheckboxFilter(363, "Близнецы"), --ID: 263
			CheckboxFilter(417, "Боги"), --ID: 317
			CheckboxFilter(539, "Богини"), --ID: 439
			CheckboxFilter(550, "Боевая академия"), --ID: 450
			CheckboxFilter(249, "Боевая фантастика"), --ID: 149
			CheckboxFilter(204, "Боевое фэнтези"), --ID: 104
			CheckboxFilter(533, "Боевые духи"), --ID: 433
			CheckboxFilter(593, "Боевые соревнования"), --ID: 493
			CheckboxFilter(521, "Божественная защита"), --ID: 421
			CheckboxFilter(427, "Божественные силы"), --ID: 327
			CheckboxFilter(699, "Борьба за власть"), --ID: 599
			CheckboxFilter(546, "Брак"), --ID: 446
			CheckboxFilter(288, "Брак по расчету"), --ID: 188
			CheckboxFilter(259, "Братский комплекс"), --ID: 159
			CheckboxFilter(587, "Братство"), --ID: 487
			CheckboxFilter(677, "Братья и сестры"), --ID: 577
			CheckboxFilter(845, "Буддизм"), --ID: 745
			CheckboxFilter(466, "Быстрая культивация"), --ID: 366
			CheckboxFilter(424, "Быстрообучаемый"), --ID: 324
			CheckboxFilter(792, "Валькирии"), --ID: 692
			CheckboxFilter(460, "Вампиры"), --ID: 360
			CheckboxFilter(802, "Ваншот"), --ID: 702
			CheckboxFilter(381, "Ведьмы"), --ID: 281
			CheckboxFilter(479, "Вежливый главный герой"), --ID: 379
			CheckboxFilter(428, "Верные подчиненные"), --ID: 328
			CheckboxFilter(395, "Взрослый главный герой"), --ID: 295
			CheckboxFilter(771, "Видит то, чего не видят другие"), --ID: 671
			CheckboxFilter(501, "Виртуальная реальность"), --ID: 401
			CheckboxFilter(781, "Владелец магазина"), --ID: 681
			CheckboxFilter(555, "Внезапная сила"), --ID: 455
			CheckboxFilter(865, "Внезапное богатство"), --ID: 765
			CheckboxFilter(519, "Внешний вид отличается от факт"), --ID: 419
			CheckboxFilter(843, "Военные Летописи"), --ID: 743
			CheckboxFilter(796, "Возвращение из другого мира"), --ID: 696
			CheckboxFilter(281, "Войны"), --ID: 181
			CheckboxFilter(801, "Вокалоид"), --ID: 701
			CheckboxFilter(639, "Волшебники/Волшебницы"), --ID: 539
			CheckboxFilter(408, "Волшебные звери"), --ID: 308
			CheckboxFilter(751, "Воображаемый друг"), --ID: 651
			CheckboxFilter(514, "Воры"), --ID: 414
			CheckboxFilter(299, "Воскрешение"), --ID: 199
			CheckboxFilter(598, "Враги становятся возлюбленными"), --ID: 498
			CheckboxFilter(662, "Враги становятся союзниками"), --ID: 562
			CheckboxFilter(709, "Врата в другой мир"), --ID: 609
			CheckboxFilter(476, "Врачи"), --ID: 376
			CheckboxFilter(375, "Временной парадокс"), --ID: 275
			CheckboxFilter(269, "Всемогущий главный герой"), --ID: 169
			CheckboxFilter(298, "Вторжение на землю"), --ID: 198
			CheckboxFilter(331, "Второй шанс"), --ID: 231
			CheckboxFilter(890, "Вуайеризм"), --ID: 790
			CheckboxFilter(480, "Выживание"), --ID: 380
			CheckboxFilter(461, "Высокомерные персонажи"), --ID: 361
			CheckboxFilter(695, "Гадание"), --ID: 595
			CheckboxFilter(877, "Гарем рабов"), --ID: 777
			CheckboxFilter(286, "Гг - женщина"), --ID: 186
			CheckboxFilter(266, "Гг - мужчина"), --ID: 166
			CheckboxFilter(271, "Гг силен с самого начала"), --ID: 171
			CheckboxFilter(492, "Геймеры"), --ID: 392
			CheckboxFilter(426, "Генералы"), --ID: 326
			CheckboxFilter(757, "Генетические модификации"), --ID: 657
			CheckboxFilter(717, "Гениальный главный герой"), --ID: 617
			CheckboxFilter(385, "Герои"), --ID: 285
			CheckboxFilter(683, "Героиня — сорванец"), --ID: 583
			CheckboxFilter(240, "Героическая фантастика"), --ID: 140
			CheckboxFilter(207, "Героическое фэнтези"), --ID: 107
			CheckboxFilter(287, "Герой влюбляется первым"), --ID: 187
			CheckboxFilter(670, "Гетерохромия"), --ID: 570
			CheckboxFilter(511, "Гильдии"), --ID: 411
			CheckboxFilter(855, "Гипнотизм"), --ID: 755
			CheckboxFilter(647, "Главный герой — бог"), --ID: 547
			CheckboxFilter(736, "Главный герой — гуманоид"), --ID: 636
			CheckboxFilter(545, "Главный герой — наполовину чел"), --ID: 445
			CheckboxFilter(892, "Главный герой — отец"), --ID: 792
			CheckboxFilter(880, "Главный герой — раб"), --ID: 780
			CheckboxFilter(588, "Главный герой — ребенок"), --ID: 488
			CheckboxFilter(576, "Главный герой — рубака"), --ID: 476
			CheckboxFilter(783, "Главный герой влюбляется первы"), --ID: 683
			CheckboxFilter(572, "Главный герой играет роль"), --ID: 472
			CheckboxFilter(772, "Главный герой носит очки"), --ID: 672
			CheckboxFilter(798, "Главный герой пацифист"), --ID: 698
			CheckboxFilter(703, "Гладиаторы"), --ID: 603
			CheckboxFilter(485, "Глуповатый главный герой"), --ID: 385
			CheckboxFilter(686, "Гоблины"), --ID: 586
			CheckboxFilter(720, "Големы"), --ID: 620
			CheckboxFilter(889, "Гомункул"), --ID: 789
			CheckboxFilter(559, "Горничные"), --ID: 459
			CheckboxFilter(205, "Городское фэнтези"), --ID: 105
			CheckboxFilter(900, "Госпиталь"), --ID: 800
			CheckboxFilter(402, "Готовка"), --ID: 302
			CheckboxFilter(493, "Гриндинг"), --ID: 393
			CheckboxFilter(562, "Дао Компаньон"), --ID: 462
			CheckboxFilter(860, "Даосизм"), --ID: 760
			CheckboxFilter(423, "Дварфы"), --ID: 323
			CheckboxFilter(742, "Двойная личность"), --ID: 642
			CheckboxFilter(701, "Двойник"), --ID: 601
			CheckboxFilter(760, "Дворецкий"), --ID: 660
			CheckboxFilter(268, "Дворяне"), --ID: 168
			CheckboxFilter(537, "Дворянство/Аристократия"), --ID: 437
			CheckboxFilter(769, "Девушки-монстры"), --ID: 669
			CheckboxFilter(822, "Демоническая техника культивац"), --ID: 722
			CheckboxFilter(252, "Демоны"), --ID: 152
			CheckboxFilter(883, "Денежный долг"), --ID: 783
			CheckboxFilter(655, "Депрессия"), --ID: 555
			CheckboxFilter(216, "Детектив"), --ID: 116
			CheckboxFilter(712, "Детективы"), --ID: 612
			CheckboxFilter(223, "Детская литература"), --ID: 123
			CheckboxFilter(262, "Дискриминация"), --ID: 162
			CheckboxFilter(496, "Добыча денег в приоритете"), --ID: 396
			CheckboxFilter(222, "Документальная проза"), --ID: 122
			CheckboxFilter(407, "Долгая разлука"), --ID: 307
			CheckboxFilter(390, "Домашние дела"), --ID: 290
			CheckboxFilter(570, "Домогательство"), --ID: 470
			CheckboxFilter(403, "Драконы"), --ID: 303
			CheckboxFilter(707, "Драконьи всадники"), --ID: 607
			CheckboxFilter(321, "Древние времена"), --ID: 221
			CheckboxFilter(474, "Древний Китай"), --ID: 374
			CheckboxFilter(317, "Дружба"), --ID: 217
			CheckboxFilter(382, "Друзья детства"), --ID: 282
			CheckboxFilter(667, "Друзья становятся врагами"), --ID: 567
			CheckboxFilter(597, "Друиды"), --ID: 497
			CheckboxFilter(884, "Дух лисы"), --ID: 784
			CheckboxFilter(272, "Духи/призраки"), --ID: 172
			CheckboxFilter(535, "Духовный советник"), --ID: 435
			CheckboxFilter(733, "Душевность"), --ID: 633
			CheckboxFilter(354, "Души"), --ID: 254
			CheckboxFilter(621, "Европейская атмосфера"), --ID: 521
			CheckboxFilter(675, "Ёкаи"), --ID: 575
			CheckboxFilter(254, "Есть аниме-адаптация"), --ID: 154
			CheckboxFilter(652, "Есть видеоигра по мотивам"), --ID: 552
			CheckboxFilter(255, "Есть манга"), --ID: 155
			CheckboxFilter(617, "Есть манхва-адаптация"), --ID: 517
			CheckboxFilter(488, "Есть маньхуа-адаптация"), --ID: 388
			CheckboxFilter(592, "Есть сериал-адаптация"), --ID: 492
			CheckboxFilter(273, "Есть фильм"), --ID: 173
			CheckboxFilter(605, "Женища-наставник"), --ID: 505
			CheckboxFilter(446, "Жесткая, двуличная личность"), --ID: 346
			CheckboxFilter(603, "Жестокие персонажи"), --ID: 503
			CheckboxFilter(754, "Жестокое обращение с ребенком"), --ID: 654
			CheckboxFilter(345, "Жестокость"), --ID: 245
			CheckboxFilter(854, "Животноводство"), --ID: 754
			CheckboxFilter(628, "Животные черты"), --ID: 528
			CheckboxFilter(706, "Жизнь в квартире"), --ID: 606
			CheckboxFilter(715, "Жрицы"), --ID: 615
			CheckboxFilter(388, "Заботливый главный герой"), --ID: 288
			CheckboxFilter(728, "Забывчивый главный герой"), --ID: 628
			CheckboxFilter(389, "Заговоры"), --ID: 289
			CheckboxFilter(462, "Закалка тела"), --ID: 362
			CheckboxFilter(856, "Законники"), --ID: 756
			CheckboxFilter(689, "Замкнутый главный герой"), --ID: 589
			CheckboxFilter(530, "Запечатанная сила"), --ID: 430
			CheckboxFilter(608, "Застенчивые персонажи"), --ID: 508
			CheckboxFilter(337, "Звери"), --ID: 237
			CheckboxFilter(401, "Звери-компаньоны"), --ID: 301
			CheckboxFilter(343, "Злой протагонист"), --ID: 243
			CheckboxFilter(604, "Злые боги"), --ID: 504
			CheckboxFilter(663, "Злые организации"), --ID: 563
			CheckboxFilter(834, "Злые религии"), --ID: 734
			CheckboxFilter(573, "Знаменитости"), --ID: 473
			CheckboxFilter(631, "Знаменитый главный герой"), --ID: 531
			CheckboxFilter(397, "Знания современного мира"), --ID: 297
			CheckboxFilter(509, "Зомби"), --ID: 409
			CheckboxFilter(374, "Игра на выживание"), --ID: 274
			CheckboxFilter(817, "Игривый протагонист"), --ID: 717
			CheckboxFilter(491, "Игровая система рейтинга"), --ID: 391
			CheckboxFilter(366, "Игровые элементы"), --ID: 266
			CheckboxFilter(776, "Игрушки (18+)"), --ID: 676
			CheckboxFilter(516, "Из грязи в князи"), --ID: 416
			CheckboxFilter(809, "Из женщины в мужчину"), --ID: 709
			CheckboxFilter(815, "Из мужчины в женщину"), --ID: 715
			CheckboxFilter(867, "Из полного в худого"), --ID: 767
			CheckboxFilter(302, "Из слабого в сильного"), --ID: 202
			CheckboxFilter(534, "Извращенный главный герой"), --ID: 434
			CheckboxFilter(634, "Изгои"), --ID: 534
			CheckboxFilter(764, "Изменение расы"), --ID: 664
			CheckboxFilter(400, "Изменения внешнего вида"), --ID: 300
			CheckboxFilter(319, "Изменения личности"), --ID: 219
			CheckboxFilter(329, "Изнасилование"), --ID: 229
			CheckboxFilter(455, "Изображения жестокости"), --ID: 355
			CheckboxFilter(335, "ИИ"), --ID: 235
			CheckboxFilter(848, "Империи"), --ID: 748
			CheckboxFilter(784, "Инвалидность"), --ID: 684
			CheckboxFilter(392, "Индустриализация"), --ID: 292
			CheckboxFilter(263, "Инженер"), --ID: 163
			CheckboxFilter(625, "Инцест"), --ID: 525
			CheckboxFilter(336, "Искусственный интеллект"), --ID: 236
			CheckboxFilter(770, "Исследования"), --ID: 670
			CheckboxFilter(219, "Историческая проза"), --ID: 119
			CheckboxFilter(220, "Исторические приключения"), --ID: 120
			CheckboxFilter(217, "Исторический детектив"), --ID: 117
			CheckboxFilter(238, "Исторический любовный роман"), --ID: 138
			CheckboxFilter(210, "Историческое фэнтези"), --ID: 110
			CheckboxFilter(556, "Каннибализм"), --ID: 456
			CheckboxFilter(782, "Карточные игры"), --ID: 682
			CheckboxFilter(241, "Киберпанк"), --ID: 141
			CheckboxFilter(786, "Киберспорт"), --ID: 686
			CheckboxFilter(896, "Кланы"), --ID: 796
			CheckboxFilter(835, "Класс безработного"), --ID: 735
			CheckboxFilter(547, "Клоны"), --ID: 447
			CheckboxFilter(316, "Клубы"), --ID: 216
			CheckboxFilter(527, "Книги"), --ID: 427
			CheckboxFilter(500, "Книги навыков"), --ID: 400
			CheckboxFilter(619, "Книжный червь"), --ID: 519
			CheckboxFilter(330, "Коварство"), --ID: 230
			CheckboxFilter(804, "Коллеги"), --ID: 704
			CheckboxFilter(826, "Колледж/Университет"), --ID: 726
			CheckboxFilter(876, "Кома"), --ID: 776
			CheckboxFilter(596, "Командная работа"), --ID: 496
			CheckboxFilter(682, "Комедийный оттенок"), --ID: 582
			CheckboxFilter(650, "Комплекс неполноценности"), --ID: 550
			CheckboxFilter(323, "Комплекс семейных отношений"), --ID: 223
			CheckboxFilter(846, "Конкуренция"), --ID: 746
			CheckboxFilter(457, "Контроль разума/сознания"), --ID: 357
			CheckboxFilter(525, "Копейщик"), --ID: 425
			CheckboxFilter(897, "Королевская битва"), --ID: 797
			CheckboxFilter(278, "Королевская власть"), --ID: 178
			CheckboxFilter(359, "Королевства"), --ID: 259
			CheckboxFilter(236, "Короткий любовный роман"), --ID: 136
			CheckboxFilter(557, "Коррупция"), --ID: 457
			CheckboxFilter(246, "Космическая фантастика"), --ID: 146
			CheckboxFilter(797, "Космические войны"), --ID: 697
			CheckboxFilter(326, "Красивый герой"), --ID: 226
			CheckboxFilter(477, "Крафт"), --ID: 377
			CheckboxFilter(740, "Кризис личности"), --ID: 640
			CheckboxFilter(453, "Кругосветное путешествие"), --ID: 353
			CheckboxFilter(606, "Кудере"), --ID: 506
			CheckboxFilter(818, "Кузены"), --ID: 718
			CheckboxFilter(618, "Кузнец"), --ID: 518
			CheckboxFilter(601, "Кукловоды"), --ID: 501
			CheckboxFilter(724, "Куклы/марионетки"), --ID: 624
			CheckboxFilter(341, "Культивация"), --ID: 241
			CheckboxFilter(767, "Куннилингус"), --ID: 667
			CheckboxFilter(600, "Легенды"), --ID: 500
			CheckboxFilter(744, "Легкая жизнь"), --ID: 644
			CheckboxFilter(721, "Ленивый главный герой"), --ID: 621
			CheckboxFilter(594, "Лидерство"), --ID: 494
			CheckboxFilter(313, "Лоли"), --ID: 213
			CheckboxFilter(577, "Лотерея"), --ID: 477
			CheckboxFilter(235, "Любовное фэнтези"), --ID: 135
			CheckboxFilter(318, "Любовный треугольник"), --ID: 218
			CheckboxFilter(660, "Любовь детства"), --ID: 560
			CheckboxFilter(837, "Любовь с первого взгляда"), --ID: 737
			CheckboxFilter(553, "Магические надписи"), --ID: 453
			CheckboxFilter(469, "Магические печати"), --ID: 369
			CheckboxFilter(540, "Магические технологии"), --ID: 440
			CheckboxFilter(265, "Магия"), --ID: 165
			CheckboxFilter(518, "Магия призыва"), --ID: 418
			CheckboxFilter(788, "Мазохистские персонажи"), --ID: 688
			CheckboxFilter(349, "Манипулятивные персонажи"), --ID: 249
			CheckboxFilter(312, "Мания"), --ID: 212
			CheckboxFilter(566, "Мастер на все руки"), --ID: 466
			CheckboxFilter(888, "Мастурбация"), --ID: 788
			CheckboxFilter(656, "Махо-сёдзё"), --ID: 556
			CheckboxFilter(607, "Медицинские знания"), --ID: 507
			CheckboxFilter(332, "Медленная романтическая линия"), --ID: 232
			CheckboxFilter(794, "Медленное развитие на старте"), --ID: 694
			CheckboxFilter(504, "Межпространственные путешестви"), --ID: 404
			CheckboxFilter(394, "Менеджмент"), --ID: 294
			CheckboxFilter(861, "Мертвый главный герой"), --ID: 761
			CheckboxFilter(309, "Месть"), --ID: 209
			CheckboxFilter(435, "Метаморфы"), --ID: 335
			CheckboxFilter(280, "Меч и магия"), --ID: 180
			CheckboxFilter(747, "Мечник"), --ID: 647
			CheckboxFilter(838, "Мечты"), --ID: 738
			CheckboxFilter(825, "Милая история"), --ID: 725
			CheckboxFilter(737, "Милое дитя"), --ID: 637
			CheckboxFilter(814, "Милый главный герой"), --ID: 714
			CheckboxFilter(563, "Мировое дерево"), --ID: 463
			CheckboxFilter(251, "Мистика"), --ID: 151
			CheckboxFilter(583, "Мистический ореол вокруг семьи"), --ID: 483
			CheckboxFilter(591, "Мифические звери"), --ID: 491
			CheckboxFilter(630, "Мифология"), --ID: 530
			CheckboxFilter(885, "Младшие братья"), --ID: 785
			CheckboxFilter(627, "Младшие сестры"), --ID: 527
			CheckboxFilter(495, "ММОРПГ (ЛитРПГ)"), --ID: 395
			CheckboxFilter(649, "Множество перемещенных людей"), --ID: 549
			CheckboxFilter(470, "Множество реальностей"), --ID: 370
			CheckboxFilter(430, "Множество реинкарнированных лю"), --ID: 330
			CheckboxFilter(778, "Модели"), --ID: 678
			CheckboxFilter(821, "Молчаливый персонаж"), --ID: 721
			CheckboxFilter(292, "Монстры"), --ID: 192
			CheckboxFilter(806, "Мужская гей-пара"), --ID: 706
			CheckboxFilter(367, "Мужчина-яндере"), --ID: 267
			CheckboxFilter(735, "Музыка"), --ID: 635
			CheckboxFilter(734, "Музыкальные группы"), --ID: 634
			CheckboxFilter(793, "Мутации"), --ID: 693
			CheckboxFilter(505, "Мутированные существа"), --ID: 405
			CheckboxFilter(762, "Навык кражи"), --ID: 662
			CheckboxFilter(306, "Навязчивая любовь"), --ID: 206
			CheckboxFilter(512, "Наемники"), --ID: 412
			CheckboxFilter(661, "Назойливый возлюбленный"), --ID: 561
			CheckboxFilter(289, "Наивный главный герой"), --ID: 189
			CheckboxFilter(789, "Наркотики"), --ID: 689
			CheckboxFilter(632, "Нарциссический главный герой"), --ID: 532
			CheckboxFilter(874, "Насилие сексуального характера"), --ID: 774
			CheckboxFilter(552, "Наследование"), --ID: 452
			CheckboxFilter(244, "Научная фантастика"), --ID: 144
			CheckboxFilter(506, "Национализм"), --ID: 406
			CheckboxFilter(515, "Не блещущий внешне главный гер"), --ID: 415
			CheckboxFilter(626, "Не родные братья и сестры"), --ID: 526
			CheckboxFilter(668, "Небеса"), --ID: 568
			CheckboxFilter(467, "Небесное испытание"), --ID: 367
			CheckboxFilter(759, "Негуманоидный главный герой"), --ID: 659
			CheckboxFilter(646, "Недоверчивый главный герой"), --ID: 546
			CheckboxFilter(358, "Недооцененный главный герой"), --ID: 258
			CheckboxFilter(409, "Недоразумения"), --ID: 309
			CheckboxFilter(296, "Неизлечимая болезнь"), --ID: 196
			CheckboxFilter(497, "Некромант"), --ID: 397
			CheckboxFilter(369, "Нелинейная история"), --ID: 269
			CheckboxFilter(648, "Ненавистный главный герой"), --ID: 548
			CheckboxFilter(377, "Ненадежный рассказчик"), --ID: 277
			CheckboxFilter(872, "Нерезиденты"), --ID: 772
			CheckboxFilter(844, "Нерешительный главный герой"), --ID: 744
			CheckboxFilter(484, "Несерьезный главный герой"), --ID: 384
			CheckboxFilter(676, "Несколько временных линий"), --ID: 576
			CheckboxFilter(368, "Несколько гг"), --ID: 268
			CheckboxFilter(637, "Несколько главных героев"), --ID: 537
			CheckboxFilter(752, "Несколько идентичностей"), --ID: 652
			CheckboxFilter(636, "Несколько личностей"), --ID: 536
			CheckboxFilter(832, "Нетораре"), --ID: 732
			CheckboxFilter(614, "Нетори"), --ID: 514
			CheckboxFilter(718, "Неудачливый главный герой"), --ID: 618
			CheckboxFilter(541, "Ниндзя"), --ID: 441
			CheckboxFilter(203, "Новелла"), --ID: 103
			CheckboxFilter(842, "Обещание из детства"), --ID: 742
			CheckboxFilter(585, "Обманщик"), --ID: 485
			CheckboxFilter(314, "Обмен телами"), --ID: 214
			CheckboxFilter(590, "Обнаженка"), --ID: 490
			CheckboxFilter(831, "Обольщение"), --ID: 731
			CheckboxFilter(761, "Оборотни"), --ID: 661
			CheckboxFilter(451, "Обратный гарем"), --ID: 351
			CheckboxFilter(429, "Общество монстров"), --ID: 329
			CheckboxFilter(702, "Обязательство"), --ID: 602
			CheckboxFilter(391, "Огнестрельное оружие"), --ID: 291
			CheckboxFilter(294, "Ограниченное время жизни"), --ID: 194
			CheckboxFilter(612, "Одержимость"), --ID: 512
			CheckboxFilter(494, "Одинокий главный герой"), --ID: 394
			CheckboxFilter(406, "Одиночество"), --ID: 306
			CheckboxFilter(413, "Одиночное проживание"), --ID: 313
			CheckboxFilter(859, "Околосмертные переживания"), --ID: 759
			CheckboxFilter(697, "Оммёдзи"), --ID: 597
			CheckboxFilter(438, "Омоложение"), --ID: 338
			CheckboxFilter(640, "Организованная преступность"), --ID: 540
			CheckboxFilter(875, "Оргия"), --ID: 775
			CheckboxFilter(431, "Орки"), --ID: 331
			CheckboxFilter(436, "Освоение навыков"), --ID: 336
			CheckboxFilter(705, "Основано на аниме"), --ID: 605
			CheckboxFilter(820, "Основано на видео игре"), --ID: 720
			CheckboxFilter(893, "Основано на визуальной новелле"), --ID: 793
			CheckboxFilter(800, "Основано на песне"), --ID: 700
			CheckboxFilter(704, "Основано на фильме"), --ID: 604
			CheckboxFilter(340, "Осторожный главный герой"), --ID: 240
			CheckboxFilter(671, "Отаку"), --ID: 571
			CheckboxFilter(364, "Открытый космос"), --ID: 264
			CheckboxFilter(827, "Отношения в сети"), --ID: 727
			CheckboxFilter(411, "Отношения между людьми и нелюд"), --ID: 311
			CheckboxFilter(891, "Отношения на расстоянии"), --ID: 791
			CheckboxFilter(672, "Отношения Сенпай-Коухай"), --ID: 572
			CheckboxFilter(615, "Отношения ученика и учителя"), --ID: 515
			CheckboxFilter(529, "Отношения учитель-ученик"), --ID: 429
			CheckboxFilter(412, "Отношения хозяин-слуга"), --ID: 312
			CheckboxFilter(833, "Отомэ игра"), --ID: 733
			CheckboxFilter(745, "Отсутствие здравого смысла"), --ID: 645
			CheckboxFilter(725, "Отсутствие родителей"), --ID: 625
			CheckboxFilter(807, "Офисный роман"), --ID: 707
			CheckboxFilter(803, "Официанты"), --ID: 703
			CheckboxFilter(478, "Охотники"), --ID: 378
			CheckboxFilter(787, "Очаровательный главный герой"), --ID: 687
			CheckboxFilter(755, "Падшее дворянство"), --ID: 655
			CheckboxFilter(665, "Падшие ангелы"), --ID: 565
			CheckboxFilter(765, "Пайзури"), --ID: 665
			CheckboxFilter(691, "Паразиты"), --ID: 591
			CheckboxFilter(307, "Параллельные миры"), --ID: 207
			CheckboxFilter(365, "Парк"), --ID: 265
			CheckboxFilter(732, "Парк развлечений"), --ID: 632
			CheckboxFilter(507, "Пародия"), --ID: 407
			CheckboxFilter(839, "Певцы/Певицы"), --ID: 739
			CheckboxFilter(829, "Первая любовь"), --ID: 729
			CheckboxFilter(711, "Первоисточник новеллы — манга"), --ID: 611
			CheckboxFilter(887, "Первый раз"), --ID: 787
			CheckboxFilter(688, "Перемещение в игровой мир"), --ID: 588
			CheckboxFilter(850, "Перемещение в иной мир"), --ID: 750
			CheckboxFilter(851, "Перерождение в ином мире"), --ID: 751
			CheckboxFilter(357, "Переселение души/трансмиграция"), --ID: 257
			CheckboxFilter(766, "Персонаж использует щит"), --ID: 666
			CheckboxFilter(300, "Петля времени"), --ID: 200
			CheckboxFilter(871, "Пираты"), --ID: 771
			CheckboxFilter(582, "Писатели"), --ID: 482
			CheckboxFilter(449, "Питомцы"), --ID: 349
			CheckboxFilter(481, "Племенное общество"), --ID: 381
			CheckboxFilter(383, "Повелитель демонов"), --ID: 283
			CheckboxFilter(422, "Подземелья"), --ID: 322
			CheckboxFilter(214, "Подростковая проза"), --ID: 114
			CheckboxFilter(378, "Пожелания"), --ID: 278
			CheckboxFilter(543, "Познание Дао"), --ID: 443
			CheckboxFilter(690, "Покинутое дитя"), --ID: 590
			CheckboxFilter(486, "Полигамия"), --ID: 386
			CheckboxFilter(270, "Политика"), --ID: 170
			CheckboxFilter(233, "Политический роман"), --ID: 133
			CheckboxFilter(864, "Полиция"), --ID: 764
			CheckboxFilter(520, "Полулюди"), --ID: 420
			CheckboxFilter(442, "Популярный любовный интерес"), --ID: 342
			CheckboxFilter(245, "Постапокалипсис"), --ID: 145
			CheckboxFilter(284, "Постапокалиптика"), --ID: 184
			CheckboxFilter(849, "Потерянные цивилизации"), --ID: 749
			CheckboxFilter(823, "Похищения людей"), --ID: 723
			CheckboxFilter(211, "Поэзия"), --ID: 111
			CheckboxFilter(813, "Правонарушители"), --ID: 713
			CheckboxFilter(692, "Прагматичный главный герой"), --ID: 592
			CheckboxFilter(325, "Преданный любовный интерес"), --ID: 225
			CheckboxFilter(322, "Предательство"), --ID: 222
			CheckboxFilter(277, "Предвидение"), --ID: 177
			CheckboxFilter(258, "Прекрасная героиня"), --ID: 158
			CheckboxFilter(836, "Преступники"), --ID: 736
			CheckboxFilter(304, "Преступность"), --ID: 204
			CheckboxFilter(362, "Призванный герой"), --ID: 262
			CheckboxFilter(276, "Призраки"), --ID: 176
			CheckboxFilter(743, "Принуждение к отношениям"), --ID: 643
			CheckboxFilter(895, "Принцессы"), --ID: 795
			CheckboxFilter(741, "Притворная пара"), --ID: 641
			CheckboxFilter(487, "Причудливые персонажи"), --ID: 387
			CheckboxFilter(297, "Пришельцы/инопланетяне"), --ID: 197
			CheckboxFilter(791, "Программист"), --ID: 691
			CheckboxFilter(274, "Проклятия"), --ID: 174
			CheckboxFilter(678, "Промывание мозгов"), --ID: 578
			CheckboxFilter(356, "Пропуск времени"), --ID: 256
			CheckboxFilter(599, "Пророчества"), --ID: 499
			CheckboxFilter(886, "Проститутки"), --ID: 786
			CheckboxFilter(420, "Прошлое играет большую роль"), --ID: 320
			CheckboxFilter(841, "Прыжки между мирами"), --ID: 741
			CheckboxFilter(459, "Психические силы"), --ID: 359
			CheckboxFilter(370, "Психопаты"), --ID: 270
			CheckboxFilter(224, "Публицистика"), --ID: 124
			CheckboxFilter(301, "Путешествие во времени"), --ID: 201
			CheckboxFilter(380, "Пытка"), --ID: 280
			CheckboxFilter(878, "Рабы"), --ID: 778
			CheckboxFilter(225, "Развитие личности"), --ID: 125
			CheckboxFilter(858, "Развод"), --ID: 758
			CheckboxFilter(386, "Разумные предметы"), --ID: 286
			CheckboxFilter(508, "Расизм"), --ID: 408
			CheckboxFilter(285, "Рассказ"), --ID: 185
			CheckboxFilter(443, "Расторжения помолвки"), --ID: 343
			CheckboxFilter(415, "Расы зооморфов"), --ID: 315
			CheckboxFilter(346, "Реализм"), --ID: 246
			CheckboxFilter(830, "Ревность"), --ID: 730
			CheckboxFilter(805, "Редакторы"), --ID: 705
			CheckboxFilter(472, "Реинкарнация"), --ID: 372
			CheckboxFilter(410, "Реинкарнация в монстра"), --ID: 310
			CheckboxFilter(811, "Реинкарнация в объект"), --ID: 711
			CheckboxFilter(716, "Религии"), --ID: 616
			CheckboxFilter(881, "Репортеры"), --ID: 781
			CheckboxFilter(780, "Ресторан"), --ID: 680
			CheckboxFilter(342, "Решительный главный герой"), --ID: 242
			CheckboxFilter(863, "Робкий главный герой"), --ID: 763
			CheckboxFilter(808, "Родитель одиночка"), --ID: 708
			CheckboxFilter(687, "Родительский комплекс"), --ID: 587
			CheckboxFilter(339, "Родословная"), --ID: 239
			CheckboxFilter(232, "Романтическая эротика"), --ID: 132
			CheckboxFilter(371, "Романтический подсюжет"), --ID: 271
			CheckboxFilter(315, "Рост персонажа"), --ID: 215
			CheckboxFilter(360, "Рыцари"), --ID: 260
			CheckboxFilter(774, "Садистские персонажи"), --ID: 674
			CheckboxFilter(847, "Самоотверженный главный герой"), --ID: 747
			CheckboxFilter(777, "Самурай"), --ID: 677
			CheckboxFilter(620, "Сборник коротких историй"), --ID: 520
			CheckboxFilter(635, "Связанные сюжетные линии"), --ID: 535
			CheckboxFilter(852, "Святые"), --ID: 752
			CheckboxFilter(513, "Священники"), --ID: 413
			CheckboxFilter(862, "Сдержанный главный герой"), --ID: 762
			CheckboxFilter(517, "Секретные организации"), --ID: 417
			CheckboxFilter(726, "Секреты"), --ID: 626
			CheckboxFilter(879, "Секс рабы"), --ID: 779
			CheckboxFilter(857, "Семейный конфликт"), --ID: 757
			CheckboxFilter(434, "Семь добродетелей"), --ID: 334
			CheckboxFilter(353, "Семь смертных грехов"), --ID: 253
			CheckboxFilter(447, "Семья"), --ID: 347
			CheckboxFilter(790, "Сёнэн-ай подсюжет"), --ID: 690
			CheckboxFilter(657, "Серийные убийцы"), --ID: 557
			CheckboxFilter(658, "Сестринский комплекс"), --ID: 558
			CheckboxFilter(473, "Сила духа"), --ID: 373
			CheckboxFilter(679, "Сила, требующая платы за польз"), --ID: 579
			CheckboxFilter(328, "Сильная пара"), --ID: 228
			CheckboxFilter(542, "Сильный в сильнейшего"), --ID: 442
			CheckboxFilter(373, "Сильный любовный интерес"), --ID: 273
			CheckboxFilter(311, "Синдром восьмиклассника"), --ID: 211
			CheckboxFilter(419, "Сироты"), --ID: 319
			CheckboxFilter(405, "Система уровней"), --ID: 305
			CheckboxFilter(638, "Системный администратор"), --ID: 538
			CheckboxFilter(226, "Сказка"), --ID: 126
			CheckboxFilter(551, "Скрытие истинной личности"), --ID: 451
			CheckboxFilter(448, "Скрытие истинных способностей"), --ID: 348
			CheckboxFilter(352, "Скрытный главный герой"), --ID: 252
			CheckboxFilter(347, "Скрытые способности"), --ID: 247
			CheckboxFilter(548, "Скульпторы"), --ID: 448
			CheckboxFilter(418, "Слабо выраженная романтическая"), --ID: 318
			CheckboxFilter(398, "Слабый главный герой"), --ID: 298
			CheckboxFilter(894, "Слепой главный герой"), --ID: 794
			CheckboxFilter(433, "Слуги"), --ID: 333
			CheckboxFilter(231, "Слэш"), --ID: 131
			CheckboxFilter(275, "Смерть"), --ID: 175
			CheckboxFilter(544, "Смерть близких"), --ID: 444
			CheckboxFilter(327, "Собственнические персонажи"), --ID: 227
			CheckboxFilter(250, "Современная проза"), --ID: 150
			CheckboxFilter(267, "Современность"), --ID: 167
			CheckboxFilter(237, "Современный любовный роман"), --ID: 137
			CheckboxFilter(644, "Сожительство"), --ID: 544
			CheckboxFilter(387, "Создание армии"), --ID: 287
			CheckboxFilter(482, "Создание артефактов"), --ID: 382
			CheckboxFilter(613, "Создание клана"), --ID: 513
			CheckboxFilter(393, "Создание королевства"), --ID: 293
			CheckboxFilter(437, "Создание навыков"), --ID: 337
			CheckboxFilter(569, "Создание секты"), --ID: 469
			CheckboxFilter(293, "Солдаты/военные"), --ID: 193
			CheckboxFilter(722, "Сон"), --ID: 622
			CheckboxFilter(290, "Состоятельные персонажи"), --ID: 190
			CheckboxFilter(355, "Социальная иерархия по силе"), --ID: 255
			CheckboxFilter(248, "Социальная фантастика"), --ID: 148
			CheckboxFilter(642, "Социальные изгои"), --ID: 542
			CheckboxFilter(738, "Спасение мира"), --ID: 638
			CheckboxFilter(279, "Специальные способности"), --ID: 179
			CheckboxFilter(260, "Спокойный главный герой"), --ID: 160
			CheckboxFilter(819, "Справедливый главный герой"), --ID: 719
			CheckboxFilter(396, "Средневековье"), --ID: 296
			CheckboxFilter(483, "Ссорящаяся пара"), --ID: 383
			CheckboxFilter(810, "Сталкеры"), --ID: 710
			CheckboxFilter(399, "Старение"), --ID: 299
			CheckboxFilter(239, "Стимпанк"), --ID: 139
			CheckboxFilter(609, "Стоические персонажи"), --ID: 509
			CheckboxFilter(775, "Стокгольмский синдром"), --ID: 675
			CheckboxFilter(595, "Стратег"), --ID: 495
			CheckboxFilter(372, "Стратегические битвы"), --ID: 272
			CheckboxFilter(898, "Стратегия"), --ID: 798
			CheckboxFilter(622, "Стрелки"), --ID: 522
			CheckboxFilter(561, "Стрельба из лука"), --ID: 461
			CheckboxFilter(651, "Студенческий совет"), --ID: 551
			CheckboxFilter(464, "Судьба"), --ID: 364
			CheckboxFilter(645, "Суккубы"), --ID: 545
			CheckboxFilter(899, "Супер герои"), --ID: 799
			CheckboxFilter(456, "Суровая подготовка"), --ID: 356
			CheckboxFilter(295, "Таинственная болезнь"), --ID: 195
			CheckboxFilter(458, "Таинственное прошлое"), --ID: 358
			CheckboxFilter(499, "Тайная личность"), --ID: 399
			CheckboxFilter(868, "Тайные отношения"), --ID: 768
			CheckboxFilter(882, "Танцоры"), --ID: 782
			CheckboxFilter(616, "Телохранители"), --ID: 516
			CheckboxFilter(206, "Темное фэнтези"), --ID: 106
			CheckboxFilter(812, "Тентакли"), --ID: 712
			CheckboxFilter(674, "Террористы"), --ID: 574
			CheckboxFilter(758, "Технологический разрыв"), --ID: 658
			CheckboxFilter(700, "Тихие персонажи"), --ID: 600
			CheckboxFilter(489, "Толстый главный герой"), --ID: 389
			CheckboxFilter(589, "Торговцы"), --ID: 489
			CheckboxFilter(310, "Травля/буллинг"), --ID: 210
			CheckboxFilter(824, "Травник"), --ID: 724
			CheckboxFilter(376, "Трагическое прошлое"), --ID: 276
			CheckboxFilter(549, "Трансплантация воспоминаний"), --ID: 449
			CheckboxFilter(234, "Триллер"), --ID: 134
			CheckboxFilter(264, "Трудолюбивый главный герой"), --ID: 164
			CheckboxFilter(641, "Тюрьма"), --ID: 541
			CheckboxFilter(305, "Убийства"), --ID: 205
			CheckboxFilter(445, "Убийцы"), --ID: 345
			CheckboxFilter(746, "Убийцы драконов"), --ID: 646
			CheckboxFilter(463, "Уверенный главный герой"), --ID: 363
			CheckboxFilter(578, "Удачливый главный герой"), --ID: 478
			CheckboxFilter(212, "Ужасы"), --ID: 112
			CheckboxFilter(522, "Укротитель монстров"), --ID: 422
			CheckboxFilter(471, "Умения из прошлой жизни"), --ID: 371
			CheckboxFilter(654, "Умная пара"), --ID: 554
			CheckboxFilter(261, "Умный главный герой"), --ID: 161
			CheckboxFilter(450, "Уникальная техника Культивации"), --ID: 350
			CheckboxFilter(526, "Уникальное оружие"), --ID: 426
			CheckboxFilter(503, "Управление бизнесом"), --ID: 403
			CheckboxFilter(379, "Управление временем"), --ID: 279
			CheckboxFilter(853, "Управление кровью"), --ID: 753
			CheckboxFilter(795, "Упрямый главный герой"), --ID: 695
			CheckboxFilter(866, "Уродливый главный герой"), --ID: 766
			CheckboxFilter(490, "Ускоренный рост"), --ID: 390
			CheckboxFilter(643, "Усыновленные дети"), --ID: 543
			CheckboxFilter(586, "Усыновленный главный герой"), --ID: 486
			CheckboxFilter(574, "Уход за детьми"), --ID: 474
			CheckboxFilter(531, "Учителя"), --ID: 431
			CheckboxFilter(696, "Фамильяры"), --ID: 596
			CheckboxFilter(750, "Фанатизм"), --ID: 650
			CheckboxFilter(510, "Фантастические существа"), --ID: 410
			CheckboxFilter(215, "Фантастический детектив"), --ID: 115
			CheckboxFilter(213, "Фанфик"), --ID: 113
			CheckboxFilter(564, "Фанфикшн"), --ID: 464
			CheckboxFilter(828, "Фармацевт"), --ID: 728
			CheckboxFilter(558, "Фарминг"), --ID: 458
			CheckboxFilter(416, "Феи"), --ID: 316
			CheckboxFilter(731, "Фелляция"), --ID: 631
			CheckboxFilter(227, "Фемслэш"), --ID: 127
			CheckboxFilter(554, "Фениксы"), --ID: 454
			CheckboxFilter(659, "Фетиш груди"), --ID: 559
			CheckboxFilter(308, "Философия"), --ID: 208
			CheckboxFilter(579, "Фильмы"), --ID: 479
			CheckboxFilter(685, "Флэшбэки"), --ID: 585
			CheckboxFilter(320, "Фобии"), --ID: 220
			CheckboxFilter(629, "Фольклор"), --ID: 529
			CheckboxFilter(719, "Футанари"), --ID: 619
			CheckboxFilter(560, "Футуристический сеттинг"), --ID: 460
			CheckboxFilter(344, "Фэнтези мир"), --ID: 244
			CheckboxFilter(575, "Хакеры"), --ID: 475
			CheckboxFilter(567, "Харизматический герой"), --ID: 467
			CheckboxFilter(624, "Хикикомори/Затворники"), --ID: 524
			CheckboxFilter(324, "Хитроумный главный герой"), --ID: 224
			CheckboxFilter(708, "Хозяин подземелий"), --ID: 608
			CheckboxFilter(454, "Холодный главный герой"), --ID: 354
			CheckboxFilter(666, "Хорошие отношения с семьей"), --ID: 566
			CheckboxFilter(291, "Хранители могил"), --ID: 191
			CheckboxFilter(565, "Целители"), --ID: 465
			CheckboxFilter(840, "Цзянши"), --ID: 740
			CheckboxFilter(610, "Цундэрэ"), --ID: 510
			CheckboxFilter(729, "Чаты"), --ID: 629
			CheckboxFilter(680, "Человеческое оружие"), --ID: 580
			CheckboxFilter(441, "Честный главный герой"), --ID: 341
			CheckboxFilter(439, "Читы"), --ID: 339
			CheckboxFilter(684, "Шантаж"), --ID: 584
			CheckboxFilter(440, "Шеф-повар"), --ID: 340
			CheckboxFilter(698, "Шикигами"), --ID: 598
			CheckboxFilter(768, "Школа только для девочек"), --ID: 668
			CheckboxFilter(673, "Шота"), --ID: 573
			CheckboxFilter(581, "Шоу-бизнес"), --ID: 481
			CheckboxFilter(218, "Шпионский детектив"), --ID: 118
			CheckboxFilter(714, "Шпионы"), --ID: 614
			CheckboxFilter(404, "Эволюция"), --ID: 304
			CheckboxFilter(694, "Эгоистичный главный герой"), --ID: 594
			CheckboxFilter(568, "Эйдетическая память"), --ID: 468
			CheckboxFilter(664, "Экзорсизм"), --ID: 564
			CheckboxFilter(653, "Экономика"), --ID: 553
			CheckboxFilter(773, "Эксгибиционизм"), --ID: 673
			CheckboxFilter(348, "Эксперименты с людьми"), --ID: 248
			CheckboxFilter(571, "Элементальная магия"), --ID: 471
			CheckboxFilter(384, "Эльфы"), --ID: 284
			CheckboxFilter(870, "Эмоционально слабый гг"), --ID: 770
			CheckboxFilter(749, "Эпизодический"), --ID: 649
			CheckboxFilter(209, "Эпическое фэнтези"), --ID: 109
			CheckboxFilter(229, "Эротическая фантастика"), --ID: 129
			CheckboxFilter(228, "Эротический фанфик"), --ID: 128
			CheckboxFilter(230, "Эротическое фэнтези"), --ID: 130
			CheckboxFilter(243, "Юмористическая фантастика"), --ID: 143
			CheckboxFilter(208, "Юмористическое фэнтези"), --ID: 108
			CheckboxFilter(611, "Юный любовный интерес"), --ID: 511
			CheckboxFilter(584, "Яды"), --ID: 484
			CheckboxFilter(580, "Языкастые персонажи"), --ID: 480
			CheckboxFilter(282, "Языковой барьер"), --ID: 182
			CheckboxFilter(414, "Яндере"), --ID: 314
			CheckboxFilter(710, "Японские силы самообороны"), --ID: 610
			CheckboxFilter(465, "Ярко выраженная романтика"), --ID: 365
			CheckboxFilter(432, "R-15 Японское возрастное огр."), --ID: 332
			CheckboxFilter(524, "R-18"), --ID: 424
			CheckboxFilter(748, "[Награжденная работа]"), --ID: 648
			CheckboxFilter(523, "18+"), --ID: 423
		}),
		FilterGroup("Типы", { --offset: 10
			CheckboxFilter(11, "Авторское"), --ID: 1
			CheckboxFilter(17, "Другое"), --ID: 7
			CheckboxFilter(15, "Запад"), --ID: 5
			CheckboxFilter(14, "Китай"), --ID: 4
			CheckboxFilter(13, "Корея"), --ID: 3
			CheckboxFilter(16, "Фанфики"), --ID: 6
			CheckboxFilter(12, "Япония"), --ID: 2
		}),
		FilterGroup("Статус проекта", { --offset: 20
			CheckboxFilter(24, "Анонс"), --ID: 4
			CheckboxFilter(20, "Закончен"), --ID: 0
			CheckboxFilter(22, "Заморожен"), --ID: 2
			CheckboxFilter(25, "Лицензировано"), --ID: 5
			CheckboxFilter(23, "Нет переводчика"), --ID: 3
			CheckboxFilter(21, "Продолжается"), --ID: 1
		}),
		FilterGroup("Возрастной рейтинг", { --offset: 30
			CheckboxFilter(30, "Для всех"), --ID: 0
			CheckboxFilter(31, "16+"), --ID: 1
			CheckboxFilter(32, "18+"), --ID: 2
		}),
	},

	shrinkURL = shrinkURL,
	expandURL = expandURL,
}
