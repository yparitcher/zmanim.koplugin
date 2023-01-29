-- Requires libzmanim
-- luarocks --lua-version=5.1 install libzmanim CC=arm-kindlepw2-linux-gnueabi-gcc --tree=rocks
-- libzmanim.lua (ffi cdecl) in lua package path /usr/local/ or ~/luarocks/ lua/5.1/libzmanim.lua
-- libzmanim.so in linker path /usr/lib/
local libzmanim = require("libzmanim_load")

if not libzmanim then
    return { disabled = true, }
end

local Device = require("device")
local Dispatcher = require("dispatcher")
local KeyValuePage = require("ui/widget/keyvaluepage")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local ZmanimSS = require("zmanimSS")
local ZmanimUtil = require("zmanimutil")
local _ = require("gettext")
local Screen = Device.screen
local T = require("ffi/util").template
local ffi = require("ffi")
require("ffi/rtc_h")

ffi.cdef[[
char *getenv(const char *) __attribute__((__nothrow__, __leaf__));
int setenv(const char *, const char *, int) __attribute__((__nothrow__, __leaf__));
]]

local zmanlist = { -- luacheck: no unused
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


local Zmanim = WidgetContainer:extend{
    name = "zmanim",
    screensaverwidget = nil,
    orig_rotation_mode = nil,
}

function Zmanim:onDispatcherRegisterActions()
    Dispatcher:registerAction("zmanimcalendar", {category="none", event="ShowZmanimCalendar", title=_("Zmanim calendar"), filemanager=true,})
    Dispatcher:registerAction("todayszmanim", {category="none", event="TodaysZmanim", title=_("Today's Zmanim"), filemanager=true,})
    Dispatcher:registerAction("ZmanimSS", {category="none", event="ZmanimSS", title=_("Zmanim SS"), filemanager=true,})
end

function Zmanim:init()
    self:onDispatcherRegisterActions()
    ZmanimUtil:setPlace(ZmanimUtil:getPlace())
    self.ui.menu:registerToMainMenu(self)
end

function Zmanim:addToMainMenu(menu_items)
    menu_items.zmanim = {
        text = _("Zmanim"),
        sorting_hint = "tools",
        sub_item_table = {
        {
            text = _("Zmanim calendar"),
            callback = function() Zmanim:onShowZmanimCalendar() end,
        },
        {
            text = _("Todays Zmanim"),
            callback = function() Zmanim:onTodaysZmanim() end,
            separator = true,
        },
        {
            text = _("Zmanim screensaver"),
            checked_func = function() return G_reader_settings:isTrue("zmanim_screensaver") end,
            callback = function() G_reader_settings:flipNilOrFalse("zmanim_screensaver") end,
        },
        {
            text = _("Round Zmanim"),
            checked_func = function() return ZmanimUtil:getRound() end,
            callback = function() ZmanimUtil:toggleRound() end,
            separator = true,
        },
        {
            text_func = function() return T(_("Zmanim location (%1)"), ZmanimUtil:getPlace() or _("Default")) end,
            sub_item_table_func = function() return ZmanimUtil:genLocationTable() end,
        },
        }
    }
end

function Zmanim:onShowZmanimCalendar()
    UIManager:show(self:getZmanimCalendar())
end

function Zmanim:onTodaysZmanim()
    local hdate = ZmanimUtil:tsToHdate(os.time())
    UIManager:show(KeyValuePage:new{
        title = ZmanimUtil:getDateString(hdate),
        value_align = "right",
        kv_pairs = ZmanimUtil:getDay(hdate),
        callback_return = function() end -- to just have that return button shown
    })
end

function Zmanim:getZmanimCalendar()
    local ZmanimCalendar = require("zmanimcalendar")
    return ZmanimCalendar:new{}
end

function Zmanim:onZmanimSS()
    UIManager:show(ZmanimSS:new{})
end

local function screensaverCallback()
    Zmanim:_screensaverCallback()
end

function Zmanim:_screensaverCallback()
require("logger").info("@@@ screensaver callback")
    if Zmanim.screensaverwidget then
        UIManager:close(Zmanim.screensaverwidget)
        Zmanim.screensaverwidget = nil
    end
    Zmanim.screensaverwidget = ZmanimSS:new{}
    UIManager:show(Zmanim.screensaverwidget, "full")
    --Device.wakeup_mgr:addTask(8 * 60, screensaverCallback)
    Device.wakeup_mgr:addTask(ZmanimUtil:getNextDateChange(), screensaverCallback)
end

function Zmanim:onSuspend()
require("logger").info("@@@ Suspend")
    if G_reader_settings:isTrue("zmanim_screensaver") and Device.wakeup_mgr then
        self.orig_rotation_mode = Screen:getRotationMode()
        if bit.band(self.orig_rotation_mode, 1) ~= 1 then
            Screen:setRotationMode(Screen.DEVICE_ROTATED_COUNTER_CLOCKWISE)
        else
            self.orig_rotation_mode = nil
        end
        screensaverCallback()
    end
end

function Zmanim:onResume()
    if G_reader_settings:isTrue("zmanim_screensaver") and Device.wakeup_mgr then
        if Zmanim.screensaverwidget then
            UIManager:close(Zmanim.screensaverwidget)
        Zmanim.screensaverwidget = nil
        end
        Device.wakeup_mgr:removeTasks(nil, screensaverCallback)
        -- Restore to previous rotation mode, if need be.
        if self.orig_rotation_mode then
            Screen:setRotationMode(self.orig_rotation_mode)
            self.orig_rotation_mode = nil
        end
        UIManager:setDirty(nil, "full")
    end
end

return Zmanim
