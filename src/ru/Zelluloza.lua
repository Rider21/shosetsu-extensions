-- {"id":722,"ver":"1.0.0","libVer":"1.0.0","author":"Rider21","dep":[]}

local baseURL = "https://zelluloza.ru"

local SORT_BY_FILTER = 3
local SORT_BY_VALUES =
{
  "По рейтингу",
  "По изменению",
  "По длительности чтения",
  "По количеству читателей",
  "По популярности",
}
local SORT_BY_TERMS = { "3", "0", "1", "2", "4" }

local alphabet = {
  ["~"] = "0",
  ["H"] = "1",
  ["^"] = "2",
  ["@"] = "3",
  ["f"] = "4",
  ["0"] = "5",
  ["5"] = "6",
  ["n"] = "7",
  ["r"] = "8",
  ["="] = "9",
  ["W"] = "a",
  ["L"] = "b",
  ["7"] = "c",
  [" "] = "d",
  ["u"] = "e",
  ["c"] = "f",
}

local function decrypt(encrypt)
  -- If the input string is empty, return an empty string.
  if not encrypt then
    return ""
  end

  -- Initialize an empty string to store the decrypted text.
  local decrypted = ""

  -- Iterate through the encrypted string two characters at a time.
  for j = 1, #encrypt, 2 do
    -- Extract the first and second characters from the encrypted string.
    local firstChar = string.sub(encrypt, j, j)
    local secondChar = string.sub(encrypt, j + 1, j + 1)

    -- Concatenate the two characters to form a hex code.
    local hexCode = tonumber(alphabet[firstChar] .. alphabet[secondChar], 16)

    -- Convert the hex code to a character and append it to the decrypted string.
    decrypted = decrypted .. string.char(hexCode)
  end

  -- Return the decrypted string wrapped in <p> tags.
  return "<p>" .. decrypted .. "</p>"
end

local function shrinkURL(url)
  return url:gsub(baseURL .. "/", "")
end

local function expandURL(url)
  return baseURL .. "/books/" .. url
end

local function getSearch(data)
  local response =
      RequestDocument(
        POST(
          baseURL .. "/ajaxcall/",
          nil,
          FormBodyBuilder()
          :add("op", "morebooks")
          :add("par1", data[0] or "")
          :add("par2", "206:0:0:0.0.0.0.0.0.0.10.0.0.0.0.0..0..:" .. data[PAGE])
          :add("par4", "")
          :build()
        )
      )

  return map(response:select('div[style="display: flex;"]'), function(v)
    return Novel {
      title = v:select('span[itemprop="name"]'):text(),
      link = v:select('a[class="txt"]'):attr("href"):gsub("[^%d]", ""),
      imageURL = baseURL .. v:select('img[class="shadow"]'):attr("src"),
    }
  end)
end

local function getPassage(chapterURL)
  local bookID, chapterID = string.match(chapterURL, "(%d+)/(%d+)")

  local response =
      Request(
        POST(
          baseURL .. "/ajaxcall/",
          nil,
          FormBodyBuilder()
          :add("op", "getbook")
          :add("par1", bookID)
          :add("par2", chapterID)
          :build()
        )
      ):body():string()

  local decrypted = ""
  for line in string.gmatch(response:match("^(.-)<END>"), "[^\n]+") do
    decrypted = decrypted .. decrypt(line)
  end

  return pageOfElem(Document(decrypted))
end

local function parseNovel(novelURL, loadChapters)
  local response = GETDocument(expandURL(novelURL))

  local novel = NovelInfo {
    title = response:select('h2[class="bookname"]'):text(),
    genres = map(response:select(".gnres > a"), function(genres)
      return genres:text()
    end),
    imageURL = baseURL .. response:select('img[class="shadow"]'):attr("src"),
    authors = { response:select(".author_link"):text() },
    description =
        response:select("#bann_full"):text() or
        response:select("#bann_short"):text(),
  }

  local status = response:select(".tech_decription"):text()
  if string.find(status, "Пишется") ~= nil then
    novel:setStatus(NovelStatus.PUBLISHING)
  else
    novel:setStatus(NovelStatus.COMPLETED)
  end

  if loadChapters then
    local order = -1
    local chapterList = mapNotNil(
      response:select('ul[class="g0"] div[class="w800_m"]'),
      function(v)
        local releaseDate = v:select('div[class="stat"]'):text()
        order = order + 1
        if v:select('td > span[class="disabled"]'):size() < 1 then
          return NovelChapter {
            title = v:selectFirst('a[class="chptitle"]'):text(),
            link = string.match(
              v:selectFirst('a[class="chptitle"]'):attr("href"),
              "/books/(%d+/%d+)/"
            ),
            release = string.match(
              releaseDate,
              "%d+%.%d+%.%d+"
            ),
            order = order,
          }
        end
      end
    )
    novel:setChapters(AsList(chapterList))
  end
  return novel
end

return {
  id = 722,
  name = "Целлюлоза",
  baseURL = baseURL,
  imageURL = "https://zelluloza.ru/assets/img/icons/Logo.png",
  chapterType = ChapterType.HTML,

  listings = {
    Listing("Novel List", true, function(data)
      local sort = SORT_BY_TERMS[data[SORT_BY_FILTER] + 1]
      local path = "/top/freebooks/?sort_order=" .. sort .. "&page=" .. data[PAGE]

      local response = GETDocument(baseURL .. path)
      return map(response:select('section[class="book-card-item"]'), function(v)
        return Novel {
          title = v:select('span[itemprop="name"]'):text(),
          link = v:select('a[class="txt"]'):attr("href"):gsub("[^%d]", ""),
          imageURL = baseURL .. v:select('img[class="shadow"]'):attr("src"),
        }
      end)
    end)
  },

  getPassage = getPassage,
  parseNovel = parseNovel,

  hasSearch = true,
  isSearchIncrementing = false,
  search = getSearch,
  searchFilters = {
    DropdownFilter(SORT_BY_FILTER, "Сортировка", SORT_BY_VALUES),
  },

  shrinkURL = shrinkURL,
  expandURL = expandURL,
}
