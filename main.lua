local Device = require("device")
local Dispatcher = require("dispatcher")
local KeyValuePage = require("ui/widget/keyvaluepage")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local _ = require("gettext")
local ffi = require("ffi")
local C = ffi.C
require("ffi/rtc_h")
local libzmanim
if Device:isKindle() then
    libzmanim = ffi.load("plugins/zmanim.koplugin/libzmanim.so")
elseif Device:isEmulator() then
    libzmanim = ffi.load("plugins/zmanim.koplugin/libzmanim-linux.so")
else
    return { disabled = true, }
end
require("libzmanim")

local cchar = ffi.typeof("char[?]")

ffi.cdef[[
char *getenv(const char *) __attribute__((__nothrow__, __leaf__));
int setenv(const char *, const char *, int) __attribute__((__nothrow__, __leaf__));
]]

local zmanlist = {
alos = { { func = "getalos", desc = "16.1°"}, { func = "getalosbaalhatanya", desc = "Baal Hatanya (16.9°)", def = true}, { func = "getalos26degrees", desc = "26°"}, { func = "getalos19p8degrees", desc = "19.8°"}, { func = "getalos18degrees", desc = "18°"}, { func = "getalos120", desc = "120 min"}, { func = "getalos120zmanis", desc = "120 min Zmanis"}, { func = "getalos96", desc = "96 min"}, { func = "getalos96zmanis", desc = "96 min Zmanis"}, { func = "getalos90", desc = "90 min"}, { func = "getalos90zmanis", desc = "90 min Zmanis"}, { func = "getalos72", desc = "72 min"}, { func = "getalos72zmanis", desc = "72 min Zmanis"}, { func = "getalos60", desc = "60 min"} },
misheyakir = { { func = "getmisheyakir11p5degrees", desc = "11.5°"}, { func = "getmisheyakir11degrees", desc = "11°"}, { func = "getmisheyakir10p2degrees", desc = "10.2°", def = true} },
netz = { { func = "getsunrise", desc = "Sea Level", def = true}, { func = "getelevationsunrise", desc = "Elevation Adjusted"} },
shma = { { func = "getshmabaalhatanya", desc = "Baal Hatanya", def = true}, { func = "getshmagra", desc = "Gra"}, { func = "getshmamga", desc = "Magen Avraham"} },
tefila = { { func = "gettefilabaalhatanya", desc = "Baal Hatanya", def = true}, { func = "gettefilagra", desc = "Gra"}, { func = "gettefilamga", desc = "Magen Avraham"} },
achilaschometz = { { func = "getachilaschometzbaalhatanya", desc = "Baal Hatanya", def = true}, { func = "getachilaschometzgra", desc = "Gra"}, { func = "getachilaschometzmga", desc = "Magen Avraham"} },
biurchometz = { { func = "getbiurchometzbaalhatanya", desc = "Baal Hatanya", def = true}, { func = "getbiurchometzgra", desc = "Gra"}, { func = "getbiurchometzmga", desc = "Magen Avraham"} },
chatzos = { { func = "getchatzosbaalhatanya", desc = "Baal Hatanya", def = true}, { func = "getchatzosgra", desc = "Gra"} },
minchagedola = { { func = "getminchagedolabaalhatanya", desc = "Baal Hatanya", def = true}, { func = "getminchagedolagra", desc = "Gra"}, { func = "getminchagedolamga", desc = "Magen Avraham"}, { func = "getminchagedolabaalhatanyag30m", desc = "Baal Hatanya 30 min"}, { func = "getminchagedolagrag30m", desc = "Gra 30 min"}, { func = "getminchagedolamgag30m", desc = "Magen Avraham 30 min"} },
minchaketana = { { func = "getminchaketanabaalhatanya", desc = "Baal Hatanya", def = true}, { func = "getminchaketanagra", desc = "Gra"}, { func = "getminchaketanamga", desc = "Magen Avraham"} },
plag =  {{ func = "getplagbaalhatanya", desc = "Baal Hatanya", def = true}, { func = "getplaggra", desc = "Gra"}, { func = "getplagmga", desc = "Magen Avraham"} },
shkia = { { func = "getsunset", desc = "Sea Level", def = true}, { func = "getelevationsunset", desc = "Elevation Adjusted"} },
tzais = { { func = "gettzaisbaalhatanya", desc = "Baal Hatanya (6°)", def = true}, { func = "gettzais8p5", desc = "8.5°"}, { func = "gettzais72", desc = "72 min"} },
shabbosends = { { func = "gettzaisbaalhatanya", desc = "6°"}, { func = "gettzais8p5", desc = "8.5°", def = true}, { func = "gettzais72", desc = "72 min"} },
--levanastart = { { func = "getmolad7days", desc = "7 days", def = true} },
--levanaend = { { func = "getmoladhalfmonth", desc = "Half month", def = true}, { func = "getmolad15days", desc = "15 days"} },
--shaahzmanis = { { func = "getshaahzmanisbaalhatanya", desc = "Baal Hatanya", def = true}, { func = "getshaahzmanisgra", desc = "Gra"}, { func = "getshaahzmanismga", desc = "Magen Avraham"} }
}


local Zmanim = WidgetContainer:new{
    name = "zmanim",
    location = ffi.new("location"),
    latitude = 40.66896,
    longitude = -73.94284,
    timezone = "EST5EDT,M3.2.0/2:00:00,M11.1.0/2:00:00",
}

function Zmanim:onDispatcherRegisterActions()
    Dispatcher:registerAction("zmanimcalendar", {category="none", event="ShowZmanimCalendar", title=_("Zmanim calendar"), filemanager=true,})
    Dispatcher:registerAction("todayszmanim", {category="none", event="TodaysZmanim", title=_("Today's Zmanim"), filemanager=true,})
end

function Zmanim:init()
    self:onDispatcherRegisterActions()
    self.location.latitude = self.latitude
    self.location.longitude = self.longitude
    ffi.C.setenv("TZ", self.timezone, 0)
    self.ui.menu:registerToMainMenu(self)
end

function Zmanim:setLocation(latitude, longitude, timezone)
    self.location.latitude = latitude
    self.location.longitude = longitude
    ffi.C.setenv("TZ", timezone, 1)
end

function Zmanim:addToMainMenu(menu_items)
    menu_items.zmanim = {
        text = _("Zmanim calendar"),
        sorting_hint = "tools",
        callback = function() Zmanim:onShowZmanimCalendar() end,
    }
end

function Zmanim:onShowZmanimCalendar()
	UIManager:show(self:getZmanimCalendar())
end

function Zmanim:onTodaysZmanim()
    local now_ts = os.time()
    UIManager:show(KeyValuePage:new{
        title = self:getDateString(now_ts),
        value_align = "right",
        kv_pairs = self:getDay(now_ts),
        callback_return = function() end -- to just have that return button shown
    })
end

local shortDayOfWeekTranslation = {
    ["Mon"] = _("Mon"),
    ["Tue"] = _("Tue"),
    ["Wed"] = _("Wed"),
    ["Thu"] = _("Thu"),
    ["Fri"] = _("Fri"),
    ["Sat"] = _("Sat"),
    ["Sun"] = _("Sun"),
}

local longDayOfWeekTranslation = {
    ["Mon"] = _("Monday"),
    ["Tue"] = _("Tuesday"),
    ["Wed"] = _("Wednesday"),
    ["Thu"] = _("Thursday"),
    ["Fri"] = _("Friday"),
    ["Sat"] = _("Saturday"),
    ["Sun"] = _("Sunday"),
}

local monthTranslation = {
    ["January"] = _("January"),
    ["February"] = _("February"),
    ["March"] = _("March"),
    ["April"] = _("April"),
    ["May"] = _("May"),
    ["June"] = _("June"),
    ["July"] = _("July"),
    ["August"] = _("August"),
    ["September"] = _("September"),
    ["October"] = _("October"),
    ["November"] = _("November"),
    ["December"] = _("December"),
}

function Zmanim:getZmanimCalendar()
    local ZmanimCalendar = require("zmanimcalendar")
    return ZmanimCalendar:new{
        zmanim = self,
        monthTranslation = monthTranslation,
        shortDayOfWeekTranslation = shortDayOfWeekTranslation,
        longDayOfWeekTranslation = longDayOfWeekTranslation,
    }
end

function Zmanim:getZman(hdate, zman, text)
    local result = libzmanim[zman](hdate, self.location)
    local zf = os.date("%I:%M %p %Z", tonumber(libzmanim.hdatetime_t(result)))
    return {zf, text}
end

function Zmanim:getShuir(hdate, shuir)
    local cshuir = cchar(100)
    libzmanim[shuir](hdate, cshuir)
    local result = ffi.string(cshuir)
    return {"", result}
end

function Zmanim:getDay(day_ts)
    local day = {}
    local hdate = self:tsToHdate(day_ts)
    local yt ~= "" = self:getYomtov(hdate)
    if yt then
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

function Zmanim:getParshah(hdate)
    local parshah = libzmanim.parshahformat(libzmanim.getparshah(hdate))
    return ffi.string(parshah)
end

function Zmanim:getYomtov(hdate)
    local yomtov = libzmanim.yomtovformat(libzmanim.getyomtov(hdate))
    return ffi.string(yomtov)
end

function Zmanim:getDate(hdate)
    local date = cchar(7)
    libzmanim.numtohchar(date, 6, hdate.day)
    return ffi.string(date)
end

function Zmanim:getDateString(day_ts)
    local hdate = self:tsToHdate(day_ts)
    local date = cchar(32)
    libzmanim.hdateformat(date, 32, hdate)
    return ffi.string(date)
end

function Zmanim:tsToHdate(ts)
    local t = ffi.new("time_t[1]")
    t[0] = ts
    local tm = ffi.new("struct tm") -- luacheck: ignore
    tm = C.localtime(t)
    local hdate = libzmanim.convertDate(tm[0])
    hdate.offset = tm[0].tm_gmtoff
    return hdate
end

return Zmanim
