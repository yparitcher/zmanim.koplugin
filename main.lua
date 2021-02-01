local Device = require("device")
local Dispatcher = require("dispatcher")
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

ffi.cdef[[
char *getenv(const char *) __attribute__((__nothrow__, __leaf__));
int setenv(const char *, const char *, int) __attribute__((__nothrow__, __leaf__));
]]

local Zmanim = WidgetContainer:new{
    name = "zmanim",
    location = ffi.new("location"),
    latitude = 40.66896,
    longitude = -73.94284,
    timezone = "EST5EDT,M3.2.0/2:00:00,M11.1.0/2:00:00",
}

function Zmanim:onDispatcherRegisterActions()
    Dispatcher:registerAction("zmanimcalendar", {category="none", event="ShowZmanimCalendar", title=_("Zmanim calendar"), filemanager=true,})
end

function Zmanim:init()
    self:onDispatcherRegisterActions()
    self.location.latitude = self.latitude
    self.location.longitude = self.longitude
    ffi.C.setenv("TZ", self.timezone, 0)
    self.ui.menu:registerToMainMenu(self)
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
    local zman = libzmanim[zman](hdate, self.location)
    local zf = os.date("%I:%M %p %Z", tonumber(libzmanim.hdatetime_t(zman)))
    return {text, zf}
end

function Zmanim:getDay(day_ts)
    local day = {}
    local hdate = self:tsToHdate(day_ts)
    table.insert(day, self:getZman(hdate, "getshmabaalhatanya", "krias shema"))
    return day
end

function Zmanim:getDate(day_ts)
    local hdate = self:tsToHdate(day_ts)
    local date = ffi.new("char[?]", 7)
    libzmanim.numtohchar(date, 6, hdate.day)
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
