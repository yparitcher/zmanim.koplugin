local BD = require("ui/bidi")
local Blitbuffer = require("ffi/blitbuffer")
local Device = require("device")
--local Event = require("ui/event")
local Font = require("ui/font")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local CenterContainer = require("ui/widget/container/centercontainer")
local FrameContainer = require("ui/widget/container/framecontainer")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local InputContainer = require("ui/widget/container/inputcontainer")
local LeftContainer = require("ui/widget/container/leftcontainer")
local LineWidget = require("ui/widget/linewidget")
local RightContainer = require("ui/widget/container/rightcontainer")
local Size = require("ui/size")
local TextBoxWidget = require("ui/widget/textboxwidget")
local TextWidget = require("ui/widget/textwidget")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local UIManager = require("ui/uimanager")
local Screen = Device.screen
local ffi = require("ffi")

local libzmanim = require("libzmanim_load")
local cchar = ffi.typeof("char[?]")

local ZmanimSS = InputContainer:new{
    name = "ZmanimSS",
    covers_fullscreen = true,
    modal = true,
    content = nil,
    widget = nil,
    orig_rotation_mode = nil,
    zmanim = nil,
    background = Blitbuffer.COLOR_LIGHT_GRAY,
    face = nil,
}

function ZmanimSS:init()
    self.orig_rotation_mode = Screen:getRotationMode()
    if bit.band(self.orig_rotation_mode, 1) ~= 1 then
        Screen:setRotationMode(Screen.ORIENTATION_LANDSCAPE_ROTATED)
    else
        self.orig_rotation_mode = nil
    end

    if Device:hasKeys() then
        self.key_events = {
            Close = { {Device.input.group.Back}, doc = "close widget" },
        }
    end
    if Device:isTouchDevice() then
        local range = Geom:new{
            x = 0, y = 0,
            w = Screen:getWidth(),
            h = Screen:getHeight(),
        }
        self.ges_events = {
            Tap = { GestureRange:new{ ges = "tap", range = range } },
        }
    end
    self.height = Screen:getHeight()
    self.width = Screen:getWidth()

    self:genContent()
    self:genWidget()
    Screen:clear()
    Screen:refreshFull()
    self:update()
end

function ZmanimSS:getZman(hdate, zman, text)
    local result = libzmanim[zman](hdate, self.zmanim.location)
    local zf = os.date("%l:%M", tonumber(libzmanim.hdatetime_t(result)))
    return {zf, text}
end

function ZmanimSS:getShuir(hdate, shuir)
    local cshuir = cchar(100)
    libzmanim[shuir](hdate, cshuir)
    local result = ffi.string(cshuir)
    local sub
    if shuir ~= "chumash" then
        sub, _ = string.gsub(result, "[^\n]-\n", "", 1)
    end
    local sub2, _ = string.gsub(sub or result, "\n", " - ")
    return sub2
end

function ZmanimSS:genContent()
    self.content = {}
    local hdate = self.zmanim:tsToHdate(os.time())
    -- @TODO Night rollover

    local zl = {}
    table.insert(zl, self:getZman(hdate, "getalosbaalhatanya", "עלות"))
    table.insert(zl, self:getZman(hdate, "getmisheyakir10p2degrees", "משיכיר"))
    table.insert(zl, self:getZman(hdate, "getsunrise", "נץ החמה"))
    table.insert(zl, self:getZman(hdate, "getshmabaalhatanya", "קריאת שמע"))
    table.insert(zl, self:getZman(hdate, "gettefilabaalhatanya", "תפלה"))
    table.insert(zl, self:getZman(hdate, "getchatzosbaalhatanya", "חצות"))
    table.insert(zl, self:getZman(hdate, "getminchagedolabaalhatanya", "מנחה גדולה"))
    table.insert(zl, self:getZman(hdate, "getminchaketanabaalhatanya", "מנחה קטנה"))
    table.insert(zl, self:getZman(hdate, "getplagbaalhatanya", "פלג המנחה"))
    if libzmanim.iscandlelighting(hdate) == 1 then
        table.insert(zl, self:getZman(hdate, "getcandlelighting", "הדלקת נרות"))
    end
    table.insert(zl, self:getZman(hdate, "getsunset", "שקיעה"))
    if libzmanim.iscandlelighting(hdate) == 2 then
        table.insert(zl, self:getZman(hdate, "gettzais8p5", "הדלקת נרות"))
        table.insert(zl, self:getZman(hdate, "gettzais8p5", "צאת"))
    elseif libzmanim.isassurbemelachah(hdate) and hdate.wday ~= 6 then
        if hdate.wday == 0 then
            table.insert(zl, self:getZman(hdate, "gettzais8p5", "יציאת השבת"))
        else
            table.insert(zl, self:getZman(hdate, "gettzais8p5", "יציאת החג"))
        end
    else
        table.insert(zl, self:getZman(hdate, "gettzaisbaalhatanya", "צאת"))
    end
    if #zl %2 == 1 then --odd
        table.insert(zl, self:getShuir(hdate, "tehillim"))
    end

    table.insert(self.content, self.zmanim:getDateString(hdate) .. self.zmanim:getYomtov(hdate))
    ziterator = #zl/2
    for k =1,ziterator do
        table.insert(self.content, {zl[ziterator+k], zl[k]})
    end
    table.insert(self.content, self:getShuir(hdate, "chumash"))
    table.insert(self.content, self:getShuir(hdate, "tanya"))
    table.insert(self.content, self:getShuir(hdate, "rambam"))
--[[--    
    self.content = {
        "כ״ז סיון תשפ״ב",
        {{"3:30", "עלות"}, {"1:36", "מנחה גדולה"}},
        {{"4:23", "משיכיר"}, {"5:25", "מנחה קטנה"}},
        {{"5:26", "נץ החמה"}, {"7:00", "פלג המנחה"}},
        {{"9:10", "עלות"}, {"8:30", "שקיעה"}},
        {{"10:26", "תפלה"}, {"9:04", "צאת"}},
        {{"12:58", "חצות"}, "ק״כ - קל״ד"},
        "פרשת קרח - ראשון עם פירש״י",
        "וממלא כל עלמין - ־פד־ גבול ותכלית.",
        "הלכות שבת - פרק ששי",
    }
--]]--
end

function ZmanimSS:genWidget()
    local items = #self.content
    local item_height =  math.floor((self.height - (Size.line.thick * (items - 1))) / items)
    local half_width = math.floor((self.width - Size.line.thick) /2)
    self.face = Font:getFace("ezra", Screen:scaleBySize(19))
    local vg = VerticalGroup:new{}
    for k, v in ipairs(self.content) do
        if k ~= 1 then
            table.insert(vg,
                LineWidget:new{
                    dimen = Geom:new{ w = self.width, h = Size.line.thick },
                })
        end
        local hg = HorizontalGroup:new{}
        if type(v) == "table" then
            for k1, v1 in ipairs(v) do
                if k1 ~= 1 then
                    table.insert(hg,
                        LineWidget:new{
                            dimen = Geom:new{ w = Size.line.thick, h = item_height },
                        })
                end
                local hg1
                if type(v1) == "table" then
                    hg1 = HorizontalGroup:new{}
                    table.insert(hg1, RightContainer:new{
                        dimen = Geom:new{ w = math.floor(half_width * .25), h = item_height },
                        TextWidget:new{
                            text = v1[1],
                            face = self.face,
                            max_width = half_width,
                        }
                    })
                    table.insert(hg1, RightContainer:new{
                        dimen = Geom:new{ w = math.floor(half_width * .65), h = item_height },
                        TextWidget:new{
                            text = v1[2],
                            face = self.face,
                            max_width = half_width,
                        }
                    })
                else
                    hg1 = TextWidget:new{
                        text = v1,
                        face = self.face,
                        max_width = half_width,
                    }
                end
                table.insert(hg, CenterContainer:new{
                    dimen = Geom:new{
                        w = half_width,
                        h = item_height,
                    },
                    hg1
                })
            end
        else
            table.insert(hg, VerticalSpan:new{width = item_height})
            table.insert(hg,
                TextBoxWidget:new{
                    text = v,
                    lang = "he",
                    para_direction_rtl = true,
                    face = self.face,
                    width = self.width,
                    alignment = "center",
                    bgcolor = self.background,
                })
        end
        table.insert(vg, hg)
    end
require("logger").warn("@@@")

    self.widget = CenterContainer:new{
        dimen = Geom:new{
            w = self.width,
            h = self.height,
        },
        vg
    }
end

function ZmanimSS:update()
    self.region = Geom:new{
        x = 0, y = 0,
        w = self.width,
        h = self.height,
    }
    self.main_frame = FrameContainer:new{
        radius = 0,
        bordersize = 0,
        padding = 0,
        margin = 0,
        background = self.background,
        width = self.width,
        height = self.height,
        self.widget,
    }
    self[1] = self.main_frame
    UIManager:setDirty(self, "full")
end

function ZmanimSS:onShow()
    UIManager:setDirty(self, function()
        return "full", self.main_frame.dimen
    end)
    return true
end

function ZmanimSS:onTap(_, ges)
    if ges.pos:intersectWith(self.main_frame.dimen) then
        self:onClose()
    end
    return true
end

function ZmanimSS:onClose()
    UIManager:close(self)
    return true
end

function ZmanimSS:onAnyKeyPressed()
    self:onClose()
    return true
end

function ZmanimSS:onCloseWidget()
    -- Restore to previous rotation mode, if need be.
    if self.orig_rotation_mode then
        Screen:setRotationMode(self.orig_rotation_mode)
        self.orig_rotation_mode = nil
    end

    UIManager:setDirty(nil, "full")
--[[--
    -- Will come after the Resume event, iff screensaver_delay is set.
    -- Comes *before* it otherwise.
    UIManager:broadcastEvent(Event:new("OutOfScreenSaver"))
--]]--
end

return ZmanimSS
