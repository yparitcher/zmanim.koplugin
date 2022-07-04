
local libzmanim = require("libzmanim_load")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local ffi = require("ffi")
local C = ffi.C
local cchar = ffi.typeof("char[?]")

local ZmanimUtil = WidgetContainer:new{
    name = "ZmanimUtil",
    location = ffi.new("location"),
}


function ZmanimUtil:setLocation(place, set_default)
    self.location.latitude = place.latitude
    self.location.longitude = place.longitude
    ffi.C.setenv("TZ", place.timezone, 1)
    if set_default then
        G_reader_settings:saveSetting("zmanim_place", place)
    end
end

function ZmanimUtil:getLocation()
    return self.location
end

function ZmanimUtil:getParshah(hdate)
    local parshah = libzmanim.parshahformat(libzmanim.getparshah(hdate))
    return ffi.string(parshah)
end

function ZmanimUtil:getYomtov(hdate)
    local yomtov = libzmanim.yomtovformat(libzmanim.getyomtov(hdate))
    return ffi.string(yomtov)
end

function ZmanimUtil:getDate(hdate)
    local date = cchar(7)
    libzmanim.numtohchar(date, 6, hdate.day)
    return ffi.string(date)
end

function ZmanimUtil:getDateString(hdate)
    local date = cchar(32)
    libzmanim.hdateformat(date, 32, hdate)
    return ffi.string(date)
end

function ZmanimUtil:tsToHdate(ts)
    local t = ffi.new("time_t[1]")
    t[0] = ts
    local tm = ffi.new("struct tm") -- luacheck: ignore
    tm = C.localtime(t)
    local hdate = libzmanim.convertDate(tm[0])
    hdate.offset = tm[0].tm_gmtoff
    return hdate
end

function ZmanimUtil:getNightfall(hdate)
    if libzmanim.isassurbemelachah(hdate) then
        return libzmanim.gettzais8p5(hdate, self:getLocation())
    else
        return libzmanim.gettzaisbaalhatanya(hdate, self:getLocation())
    end
end

function ZmanimUtil:getNextDateChange()
    local now = os.time()
    local hdate = ZmanimUtil:tsToHdate(now)
    local nextDate = libzmanim.getalosbaalhatanya(hdate, self:getLocation())
    if libzmanim.hdatecompare(hdate, nextDate) ~= 1 then
        nextDate = self:getNightfall(hdate)
        if libzmanim.hdatecompare(hdate, nextDate) ~= 1 then
            local newDate = ZmanimUtil:tsToHdate(os.time())
            libzmanim.hdateaddday(newDate, 1)
            nextDate = libzmanim.getalosbaalhatanya(newDate, self:getLocation())
        end
    end
    local delta = libzmanim.hdatetime_t(nextDate) - now
    return delta
end

function ZmanimUtil:getZman(hdate, zman, text)
    local result = libzmanim[zman](hdate, self.location)
    local zf = os.date("%I:%M %p %Z", tonumber(libzmanim.hdatetime_t(result)))
    return {zf, text}
end

function ZmanimUtil:getShuir(hdate, shuir)
    local cshuir = cchar(100)
    libzmanim[shuir](hdate, cshuir)
    local result = ffi.string(cshuir)
    return {"", result}
end

function ZmanimUtil:getDay(hdate)
    local day = {}
    local yt = self:getYomtov(hdate)
    if yt ~= "" then
        table.insert(day, {"", yt})
        table.insert(day, "-")
    end
    table.insert(day, self:getZman(hdate, "getalosbaalhatanya", "עלות השחר"))
    table.insert(day, self:getZman(hdate, "getmisheyakir10p2degrees", "משיכיר"))
    table.insert(day, self:getZman(hdate, "getsunrise", "נץ החמה"))
    table.insert(day, self:getZman(hdate, "getshmabaalhatanya", "סו״ז ק״ש"))
    table.insert(day, self:getZman(hdate, "gettefilabaalhatanya", "סו״ז תפלה"))
    if libzmanim.getyomtov(hdate) == libzmanim.EREV_PESACH then
        table.insert(day, self:getZman(hdate, "getachilaschometzbaalhatanya", "סו״ז אכילת חמץ"))
        table.insert(day, self:getZman(hdate, "getbiurchometzbaalhatanya", "סו״ז ביעור חמץ"))
    end
    table.insert(day, self:getZman(hdate, "getchatzosbaalhatanya", "חצות"))
    table.insert(day, self:getZman(hdate, "getminchagedolabaalhatanya", "מנחה גדולה"))
    table.insert(day, self:getZman(hdate, "getminchaketanabaalhatanya", "מנחה קטנה"))
    table.insert(day, self:getZman(hdate, "getplagbaalhatanya", "פלג המנחה"))
    if libzmanim.iscandlelighting(hdate) == 1 then
        table.insert(day, self:getZman(hdate, "getcandlelighting", "הדלקת נרות"))
    end
    table.insert(day, self:getZman(hdate, "getsunset", "שקיעה"))
    if libzmanim.iscandlelighting(hdate) == 2 then
        table.insert(day, self:getZman(hdate, "gettzais8p5", "הדלקת נרות"))
        table.insert(day, self:getZman(hdate, "gettzais8p5", "צאת הכוכבים"))
    elseif libzmanim.isassurbemelachah(hdate) and hdate.wday ~= 6 then
        if hdate.wday == 0 then
            table.insert(day, self:getZman(hdate, "gettzais8p5", "יציאת השבת"))
        else
            table.insert(day, self:getZman(hdate, "gettzais8p5", "יציאת החג"))
        end
    else
        table.insert(day, self:getZman(hdate, "gettzaisbaalhatanya", "צאת הכוכבים"))
    end
    table.insert(day, "-")
    table.insert(day, self:getShuir(hdate, "chumash"))
    table.insert(day, self:getShuir(hdate, "tehillim"))
    table.insert(day, self:getShuir(hdate, "tanya"))
    table.insert(day, self:getShuir(hdate, "rambam"))
--[[
    for k, v in pairs(zmanlist) do
        for l, w in ipairs(v) do
            if w.def == true then
--require("logger").warn(w.func, w.desc)
                --table.insert(day, self:getZman(hdate, w.func, w.desc))
            end
        end
    end
    --table.insert(day, self:getZman(hdate, "getshmabaalhatanya", "krias shema"))
--]]--
    return day
end

return ZmanimUtil
