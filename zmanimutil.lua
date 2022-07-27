local libzmanim = require("libzmanim_load")
local DataStorage = require("datastorage")
local LuaSettings = require("luasettings")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local _ = require("gettext")
local ffi = require("ffi")
local C = ffi.C
local cchar = ffi.typeof("char[?]")

local ZmanimUtil = WidgetContainer:new{
    name = "ZmanimUtil",
    location = ffi.new("location"),
    places = LuaSettings:open(DataStorage:getSettingsDir() .. "/zmanim_locations.lua"),
}


function ZmanimUtil:setLocation(place)
    self.location.latitude = place.latitude
    self.location.longitude = place.longitude
    ffi.C.setenv("TZ", place.timezone, 1)
end

function ZmanimUtil:getLocation()
    return self.location
end

function ZmanimUtil:setPlace(place)
    if place then
        G_reader_settings:saveSetting("zmanim_place", place)
        local v = self.places:readSetting(place)
        if v then
            self:setLocation(v)
            return
	    end
	    G_reader_settings:delSetting("zmanim_place")
    end
    self:setLocation({
        latitude = 40.66896,
        longitude = -73.94284,
        timezone = "EST5EDT,M3.2.0/2:00:00,M11.1.0/2:00:00",
    })
end

function ZmanimUtil:getPlace()
    return G_reader_settings:readSetting("zmanim_place")
end

function ZmanimUtil:newPlace()
    local MultiInputDialog = require("ui/widget/multiinputdialog")
    local location_dialog
    location_dialog = MultiInputDialog:new{
        title = _("New Location"),
        fields = {
            {
                description = _("Name"),
                hint = "NY",
            },
            {
                description = _("Latitude"),
                input_type = "number",
                hint = 40.66896,
            },
            {
                description = _("Longitude"),
                input_type = "number",
                hint = -73.94284,
            },
            {
                description = _("Time zone"),
                hint = "EST5EDT,M3.2.0/2:00:00,M11.1.0/2:00:00",
            },
        },
        buttons = {{
            {
                text = _("Cancel"),
                id = "close",
                callback = function()
                    UIManager:close(location_dialog)
                end
            },
            {
                text = _("Save"),
                callback = function(touchmenu_instance)
                    local fields = MultiInputDialog:getFields()
                    if fields[1] ~= "" and fields[2] ~= ""
                        and fields[3] ~= "" and fields[4] ~= "" then
                        self.places:saveSetting(fields[1], {
                            latitude = tonumber(fields[2]),
                            longitude = tonumber(fields[3]),
                            timezone = fields[4],
                        })
                        self.places:flush()
                        ZmanimUtil:setPlace(fields[1])
                        UIManager:close(location_dialog)
                        if touchmenu_instance then
                            touchmenu_instance:updateItems()
                        end
                    end
                end,
            },
        },},
    }
    UIManager:show(location_dialog)
end

function ZmanimUtil:genLocationTable()
    local sub_item_table = {
        {
            text = _("New Location"),
            callback = function(touchmenu_instance) ZmanimUtil:newPlace() end,
            separator = true,
        },
    }
    for k, v in pairs(self.places.data) do
        table.insert(sub_item_table,
        {
            text = k,
            checked_func = function() return k == ZmanimUtil:getPlace() end,
            callback = function(touchmenu_instance)
                ZmanimUtil:setPlace(k)
                if touchmenu_instance then touchmenu_instance:updateItems() end
            end,
            hold_callback = function(touchmenu_instance)
                local ConfirmBox = require("ui/widget/confirmbox")
                UIManager:show(ConfirmBox:new{
                    text = _("Delete location?"),
                    ok_text = _("Delete"),
                    ok_callback = function()
                        self.places:delSetting(k)
                        self.places:flush()
                    end,
                    })
            end,
        })
    end
    return sub_item_table
end

function ZmanimUtil:toggleRound()
    G_reader_settings:flipFalse("zmanim_rounding")
end

function ZmanimUtil:getRound()
    return G_reader_settings:nilOrTrue("zmanim_rounding")
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

function ZmanimUtil:getZman(hdate, zman, text, round)
    local result = libzmanim[zman](hdate, self.location)
    if round then
        libzmanim.hdateaddsecond(result, 60-result.sec)
    end
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
    local round = ZmanimUtil:getRound()
    local day = {}
    local yt = self:getYomtov(hdate)
    if yt ~= "" then
        table.insert(day, {"", yt})
        table.insert(day, "-")
    end
    table.insert(day, self:getZman(hdate, "getalosbaalhatanya", "עלות השחר"))
    table.insert(day, self:getZman(hdate, "getmisheyakir10p2degrees", "משיכיר", round))
    table.insert(day, self:getZman(hdate, "getsunrise", "נץ החמה", round))
    table.insert(day, self:getZman(hdate, "getshmabaalhatanya", "סו״ז ק״ש"))
    table.insert(day, self:getZman(hdate, "gettefilabaalhatanya", "סו״ז תפלה"))
    if libzmanim.getyomtov(hdate) == libzmanim.EREV_PESACH then
        table.insert(day, self:getZman(hdate, "getachilaschometzbaalhatanya", "סו״ז אכילת חמץ"))
        table.insert(day, self:getZman(hdate, "getbiurchometzbaalhatanya", "סו״ז ביעור חמץ"))
    end
    table.insert(day, self:getZman(hdate, "getchatzosbaalhatanya", "חצות"))
    table.insert(day, self:getZman(hdate, "getminchagedolabaalhatanya", "מנחה גדולה", round))
    table.insert(day, self:getZman(hdate, "getminchaketanabaalhatanya", "מנחה קטנה", round))
    table.insert(day, self:getZman(hdate, "getplagbaalhatanya", "פלג המנחה", round))
    if libzmanim.iscandlelighting(hdate) == 1 then
        table.insert(day, self:getZman(hdate, "getcandlelighting", "הדלקת נרות"))
    end
    table.insert(day, self:getZman(hdate, "getsunset", "שקיעה"))
    if libzmanim.iscandlelighting(hdate) == 2 then
        table.insert(day, self:getZman(hdate, "gettzais8p5", "הדלקת נרות"))
        table.insert(day, self:getZman(hdate, "gettzais8p5", "צאת הכוכבים", round))
    elseif libzmanim.isassurbemelachah(hdate) and hdate.wday ~= 6 then
        if hdate.wday == 0 then
            table.insert(day, self:getZman(hdate, "gettzais8p5", "יציאת השבת", round))
        else
            table.insert(day, self:getZman(hdate, "gettzais8p5", "יציאת החג", round))
        end
    else
        table.insert(day, self:getZman(hdate, "gettzaisbaalhatanya", "צאת הכוכבים", round))
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
