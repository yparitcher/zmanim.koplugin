local Device = require("device")
local Dispatcher = require("dispatcher")
local FFIUtil = require("ffi/util")
local Font = require("ui/font")
local InfoMessage = require("ui/widget/infomessage")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local util = require("util")
local _ = require("gettext")
local ffi = require("ffi")
local C = ffi.C
require("ffi/rtc_h")
local libzmanim
if Device:isKindle() then
    libzmanim = ffi.load("plugins/chitad.koplugin/libzmanim.so")
elseif Device:isEmulator() then
    libzmanim = ffi.load("plugins/zmanim.koplugin/libzmanim-linux.so")
else
    return { disabled = true, }
end
require("libzmanim")

local Zmanim = WidgetContainer:new{
    name = "zmanim",
}

function Zmanim:onDispatcherRegisterActions()
    Dispatcher:registerAction("zmanimcalendar", {category="none", event="ShowZmanimCalendar", title=_("Zmanim calendar"), filemanager=true,})
end

function Zmanim:init()
    self:onDispatcherRegisterActions()
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
        nb_book_spans = self.calendar_nb_book_spans,
    }
end

function Zmanim:getDay(day_ts)
    return {}
end

function Zmanim:popup(text, timeout)
    local popup = InfoMessage:new{
        face = Font:getFace("ezra.ttf", 32),
        show_icon = false,
        text = text,
        lang = "he",
        para_direction_rtl = true,
        timeout = timeout,
        name = "Zmanim_popup",
    }
    UIManager:show(popup)
end

function Zmanim:getShuir(func, offset)
    local t = ffi.new("time_t[1]")
    t[0] = C.time(nil)
    local tm = ffi.new("struct tm") -- luacheck: ignore
    tm = C.localtime(t)
    local hdate = ffi.new("hdate[1]")
    hdate[0] = libzmanim.convertDate(tm[0])
    if offset then
        libzmanim.hdateaddday(hdate, offset)
    end
    local shuir = ffi.new("char[?]", 100)
    func(hdate[0], shuir)
    return ffi.string(shuir)
end

function Zmanim:getParshah()
    local shuir = self:getShuir(libzmanim.chumash)
    local _, _, parshah, day = shuir:find("(.-)\n(.-) עם פירש״י")
    return parshah:gsub(" ", "_"), day
end

function Zmanim:displayTanya()
    if FFIUtil.basename(self.document.file) == "tanya.epub" then
        local shuir = self:getShuir(libzmanim.tanya)
        local tomorrow = self:getShuir(libzmanim.tanya, 1)
        local _, _, text = tomorrow:find("תניא\n(.*)\n.*")
        if not text then text = tomorrow or " " end
        self:popup(shuir .. "\n    ~~~\n" .. text)
        return true
    end
    return false
end

function Zmanim:onChumash()
    local root = "/mnt/us/ebooks/epub/חומש/"
    local parshah, day = self:getParshah()
    if self.ui.view and self.ui.toc.toc ~= nil and self.ui.document.file == root .. parshah .. ".epub" then
        self:goToChapter(parshah:gsub("_", " ") .. " - " .. day)
    else
        self:switchToShuir(root, parshah)
    end
end
function Zmanim:onRambam()
    local root = "/mnt/us/ebooks/epub/רמבם/"
    local shuir = self:getShuir(libzmanim.rambam)
    local _, _, perek = shuir:find("רמב״ם\n(.*)")
--require("logger").warn("@@@@", perek)
    perek = perek:gsub("\n", " - ")
--require("logger").warn("@@@@", perek)
    if self.ui.view and self.ui.toc.toc ~= nil and util.stringStartsWith(self.ui.document.file, root) then
        self:goToChapter(" " .. perek)
--require("logger").warn("@@@@", self.ui.toc.toc)
    else
        self:onZmanimDirectory(root)
    end
end

return Zmanim
