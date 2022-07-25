local Blitbuffer = require("ffi/blitbuffer")
local Device = require("device")
--local Event = require("ui/event")
local Font = require("ui/font")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local CenterContainer = require("ui/widget/container/centercontainer")
local FrameContainer = require("ui/widget/container/framecontainer")
local HorizontalGroup = require("ui/widget/horizontalgroup")
--local HorizontalSpan = require("ui/widget/horizontalspan")
local InputContainer = require("ui/widget/container/inputcontainer")
--local LeftContainer = require("ui/widget/container/leftcontainer")
local LineWidget = require("ui/widget/linewidget")
local OverlapGroup = require("ui/widget/overlapgroup")
local RightContainer = require("ui/widget/container/rightcontainer")
local Size = require("ui/size")
local TextBoxWidget = require("ui/widget/textboxwidget")
local TextWidget = require("ui/widget/textwidget")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local ZmanimUtil = require("zmanimutil")
local Screen = Device.screen
local ffi = require("ffi")

local libzmanim = require("libzmanim_load")
local cchar = ffi.typeof("char[?]")

local FACE_NAME = "ezra"

local ZmanimSS = InputContainer:new{
    name = "ZmanimSS",
    covers_fullscreen = true,
    modal = true,
    content = nil,
    widget = nil,
    background = Blitbuffer.COLOR_LIGHT_GRAY,
    face = nil,
    round = nil,
}

function ZmanimSS:init()
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
    self:update()
end

function ZmanimSS:getZman(hdate, zman, text, round)
    local result = libzmanim[zman](hdate, ZmanimUtil:getLocation())
    if round then
        libzmanim.hdateaddsecond(result, 60-result.sec)
    end
    local zf = os.date("%l:%M", tonumber(libzmanim.hdatetime_t(result)))
    return {zf, text}
end

function ZmanimSS:getShuir(hdate, shuir)
    local cshuir = cchar(100)
    libzmanim[shuir](hdate, cshuir)
    local result = ffi.string(cshuir)
    local sub, _
    if shuir ~= "chumash" then
        sub, _ = string.gsub(result, "[^\n]-\n", "", 1)
    end
    local sub2, _ = string.gsub(sub or result, "\n", " - ")
    return sub2
end

function ZmanimSS:genContent()
    self.content = {}
    local hdate = ZmanimUtil:tsToHdate(os.time())
    local day_string = ""
    if libzmanim.hdatecompare(hdate, ZmanimUtil:getNightfall(hdate)) <= 0 then
        libzmanim.hdateaddday(hdate, 1)
        day_string = "ליל "
    elseif libzmanim.hdatecompare(hdate, libzmanim.getalosbaalhatanya(hdate, ZmanimUtil:getLocation())) > 0 then
        day_string = "ליל "
    end

    local zl = {}
    table.insert(zl, self:getZman(hdate, "getalosbaalhatanya", "עלות"))
    table.insert(zl, self:getZman(hdate, "getmisheyakir10p2degrees", "משיכיר", self.round))
    table.insert(zl, self:getZman(hdate, "getsunrise", "נץ החמה", self.round))
    table.insert(zl, self:getZman(hdate, "getshmabaalhatanya", "קריאת שמע"))
    table.insert(zl, self:getZman(hdate, "gettefilabaalhatanya", "תפלה"))
    table.insert(zl, self:getZman(hdate, "getchatzosbaalhatanya", "חצות"))
    table.insert(zl, self:getZman(hdate, "getminchagedolabaalhatanya", "מנחה גדולה", self.round))
    table.insert(zl, self:getZman(hdate, "getminchaketanabaalhatanya", "מנחה קטנה", self.round))
    table.insert(zl, self:getZman(hdate, "getplagbaalhatanya", "פלג המנחה", self.round))
    if libzmanim.iscandlelighting(hdate) == 1 then
        table.insert(zl, self:getZman(hdate, "getcandlelighting", "הדלקת נרות"))
    end
    table.insert(zl, self:getZman(hdate, "getsunset", "שקיעה"))
    if libzmanim.iscandlelighting(hdate) == 2 then
        table.insert(zl, self:getZman(hdate, "gettzais8p5", "הדלקת נרות"))
        table.insert(zl, self:getZman(hdate, "gettzais8p5", "צאת", self.round))
    elseif libzmanim.isassurbemelachah(hdate) and hdate.wday ~= 6 then
        if hdate.wday == 0 then
            table.insert(zl, self:getZman(hdate, "gettzais8p5", "יציאת השבת", self.round))
        else
            table.insert(zl, self:getZman(hdate, "gettzais8p5", "יציאת החג", self.round))
        end
    else
        table.insert(zl, self:getZman(hdate, "gettzaisbaalhatanya", "צאת", self.round))
    end
    if #zl %2 == 1 then --odd
        table.insert(zl, self:getShuir(hdate, "tehillim"))
    end

    day_string = day_string .. ZmanimUtil:getDateString(hdate)
    local yt = ZmanimUtil:getYomtov(hdate)
    if yt ~= "" then
        day_string = day_string .." - " .. yt
    end
    table.insert(self.content, day_string)
    local ziterator = #zl/2
    for k =1,ziterator do
        table.insert(self.content, {zl[ziterator+k], zl[k]})
    end
    table.insert(self.content, self:getShuir(hdate, "chumash"))
    table.insert(self.content, self:getShuir(hdate, "tanya"))
    table.insert(self.content, self:getShuir(hdate, "rambam"))
end

function ZmanimSS:genWidget()
    local items = #self.content
    local item_height =  math.floor((self.height - ((Size.line.thick * (items - 1))+ (Size.padding.default*2))) / items)
    local half_width = math.floor((self.width - Size.line.thick) /2)
    self.face = Font:getFace(FACE_NAME, 40) -- Font size is already `scaleBySize` in `Font`
    local vg = VerticalGroup:new{}
    table.insert(vg, VerticalSpan:new{width = Size.padding.default})
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
            --table.insert(hg, VerticalSpan:new{width = item_height})
            table.insert(hg,
                TextBoxWidget:new{
                    text = v,
                    lang = "he",
                    para_direction_rtl = true,
                    face = self.face,
                    width = self.width,
                    alignment = "center",
                    bgcolor = self.background,
                    height = item_height,
                    height_adjust = true,
                })
        end
        table.insert(vg, hg)
    end
    table.insert(vg, VerticalSpan:new{width = Size.padding.default})

    local dimen = Geom:new{w = self.width, h = self.height,}
    self.widget = OverlapGroup:new{
        dimen = dimen,
        CenterContainer:new{
            dimen = dimen,
            vg
        },
        TextWidget:new{
            text = 'ב"ה ', --.. os.date("%T", os.time()),
            face = Font:getFace(FACE_NAME, 10),
            overlap_align = "right",
            padding = Size.padding.tiny
        }
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

return ZmanimSS
