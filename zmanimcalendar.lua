-- Adapted from the statistics plugins calendarview

local BD = require("ui/bidi")
local Blitbuffer = require("ffi/blitbuffer")
local BottomContainer = require("ui/widget/container/bottomcontainer")
local Button = require("ui/widget/button")
local CenterContainer = require("ui/widget/container/centercontainer")
local CloseButton = require("ui/widget/closebutton")
local Device = require("device")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local InputContainer = require("ui/widget/container/inputcontainer")
local KeyValuePage = require("ui/widget/keyvaluepage")
local LeftContainer = require("ui/widget/container/leftcontainer")
local Math = require("optmath")
local OverlapGroup = require("ui/widget/overlapgroup")
local Size = require("ui/size")
local TextBoxWidget = require("ui/widget/textboxwidget")
local TextWidget = require("ui/widget/textwidget")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local Widget = require("ui/widget/widget")
local Input = Device.input
local Screen = Device.screen
local _ = require("gettext")

local CalendarTitle = VerticalGroup:new{
    calendar_view = nil,
    title = "",
    tface = Font:getFace("tfont"),
    align = "left",
}

function CalendarTitle:init()
    self.close_button = CloseButton:new{ window = self }
    local btn_width = self.close_button:getSize().w
    self.text_w = TextWidget:new{
        text = self.title,
        max_width = self.width - btn_width,
        face = self.tface,
    }
    table.insert(self, OverlapGroup:new{
        dimen = { w = self.width },
        self.text_w,
        self.close_button,
    })
    table.insert(self, VerticalSpan:new{ width = Size.span.vertical_large })
end

function CalendarTitle:setTitle(title)
    self.text_w:setText(title)
end

function CalendarTitle:onClose()
    self.calendar_view:onClose()
    return true
end

local CalendarDay = InputContainer:new{
    daynum = nil,
    filler = false,
    width = nil,
    height = nil,
    border = 0,
    is_future = false,
    font_face = "xx_smallinfofont",
    font_size = nil,
}

function CalendarDay:init()
    self.dimen = Geom:new{w = self.width, h = self.height}
    if self.filler then
        return
    end
    if self.callback and Device:isTouchDevice() then
        self.ges_events.Tap = {
            GestureRange:new{
                ges = "tap",
                range = self.dimen,
            }
        }
        self.ges_events.Hold = {
            GestureRange:new{
                ges = "hold",
                range = self.dimen,
            }
        }
    end

    self.daynum_w = TextWidget:new{
        text = " " .. tostring(self.daynum),
        face = Font:getFace(self.font_face, self.font_size),
        fgcolor = self.is_future and Blitbuffer.COLOR_GRAY or Blitbuffer.COLOR_BLACK,
        padding = 0,
        bold = true,
    }
    self.hebday_w = TextWidget:new{
        text = "",
        face = Font:getFace(self.font_face, self.font_size),
        fgcolor = self.is_future and Blitbuffer.COLOR_GRAY or Blitbuffer.COLOR_BLACK,
        overlap_align = "right",
        padding = 0,
        bold = true,
    }
    local inner_w = self.width - 2*self.border
    self[1] = FrameContainer:new{
        padding = 0,
        color = self.is_future and Blitbuffer.COLOR_GRAY or Blitbuffer.COLOR_BLACK,
        bordersize = self.border,
        width = self.width,
        height = self.height,
        OverlapGroup:new{
            dimen = { w = inner_w },
            self.daynum_w,
            self.hebday_w,
        }
    }
end

function CalendarDay:updateHebDay(text)
    if not self.filler then
        self.hebday_w:setText(text .. " ")
    end
end

function CalendarDay:onTap()
    if self.callback then
        self.callback()
    end
    return true
end

function CalendarDay:onHold()
    return self:onTap()
end


local CalendarWeek = InputContainer:new{
    width = nil,
    height = nil,
    day_width = 0,
    day_padding = 0,
    day_border = 0,
    nb_book_spans = 0,
    span_height = nil,
    font_size = 0,
    font_face = "xx_smallinfofont",
}

function CalendarWeek:init()
    self.calday_widgets = {}
    self.days_books = {}
end

function CalendarWeek:addDay(calday_widget)
    -- Add day widget to this week widget, and update the
    -- list of books read this week for later showing book
    -- spans, that may span multiple days.
    table.insert(self.calday_widgets, calday_widget)

    calday_widget:updateHebDay(calday_widget.hebday)
end

-- Set of { Font color, background color }
local SPAN_COLORS = {
    { Blitbuffer.COLOR_BLACK, Blitbuffer.COLOR_WHITE },
    { Blitbuffer.COLOR_BLACK, Blitbuffer.COLOR_GRAY_E },
    { Blitbuffer.COLOR_BLACK, Blitbuffer.COLOR_LIGHT_GRAY },
    { Blitbuffer.COLOR_BLACK, Blitbuffer.COLOR_GRAY },
    { Blitbuffer.COLOR_WHITE, Blitbuffer.COLOR_WEB_GRAY },
    { Blitbuffer.COLOR_WHITE, Blitbuffer.COLOR_DARK_GRAY },
    { Blitbuffer.COLOR_WHITE, Blitbuffer.COLOR_DIM_GRAY },
    { Blitbuffer.COLOR_WHITE, Blitbuffer.COLOR_BLACK },
}

function CalendarWeek:update()
    self.dimen = Geom:new{w = self.width, h = self.height}
    self.day_container = HorizontalGroup:new{
        dimen = self.dimen:copy(),
    }
    for num, calday in ipairs(self.calday_widgets) do
        table.insert(self.day_container, calday)
        if num < #self.calday_widgets then
            table.insert(self.day_container, HorizontalSpan:new{ width = self.day_padding, })
        end
    end

    local overlaps = OverlapGroup:new{
        self.day_container,
    }
    -- Create and add BookSpans
    local bspan_margin_h = Size.margin.tiny + self.day_border
    local bspan_margin_v = Size.margin.tiny
    local bspan_padding_h = Size.padding.tiny
    local bspan_border = Size.border.thin

    -- We need a smaller font size than the one provided
    local text_height = self.span_height - 2 * (bspan_margin_v + bspan_border)
    -- We don't use any bspan_padding_v, we let that be handled by CenterContainer
    -- and choosing an appropriate font size.
    -- We use TextBoxWidget:getFontSizeToFitHeight() to get a fitting
    -- font size. It's less precise than the TextWidget equivalent,
    -- but it handles padding as 'em'.
    -- Use a 1.3em line height
    local inner_font_size = TextBoxWidget:getFontSizeToFitHeight(text_height, 1, 0.3)
    -- If font size gets really small, get a larger one by using a smaller
    -- line height: tall glyphs may bleed on the border, but we won't notice
    -- at such small size, and we'll appreciate the readability.
    -- (threshold values decided from visual testing)
    if inner_font_size <= 12 then
        inner_font_size = TextBoxWidget:getFontSizeToFitHeight(text_height, 1, 0.1)
    elseif inner_font_size <= 15 then
        inner_font_size = TextBoxWidget:getFontSizeToFitHeight(text_height, 1, 0.2)
    end
    -- But cap it to the day num font size
    inner_font_size = math.min(inner_font_size, self.font_size)

    local offset_y_fixup
    -- No histogram: ensure last book span bottom margin
    -- is equal to bspan_margin_v for a nice fit
    offset_y_fixup = self.height - self.span_height * (self.nb_book_spans + 1) - bspan_margin_v

    for col, day_books in ipairs(self.days_books) do
        for row, book in ipairs(day_books) do
            if book and book.start_day == col then
                local fgcolor, bgcolor = unpack(SPAN_COLORS[(book.id % #SPAN_COLORS)+1])
                local offset_x = (col-1) * (self.day_width + self.day_padding)
                local offset_y = row * self.span_height -- 1st real row used by day num
                offset_y = offset_y + offset_y_fixup
                local width = book.span_days * self.day_width + self.day_padding * (book.span_days-1)
                -- We use two FrameContainers, as (unlike HTML) a FrameContainer
                -- draws the background color outside its borders, in the margins
                local span_w = FrameContainer:new{
                    width = width,
                    height = self.span_height,
                    margin = 0,
                    bordersize = 0,
                    padding_top = bspan_margin_v,
                    padding_bottom = bspan_margin_v,
                    padding_left = bspan_margin_h,
                    padding_right = bspan_margin_h,
                    overlap_offset = {offset_x, offset_y},
                    FrameContainer:new{
                        width = width - 2 * bspan_margin_h,
                        height = self.span_height - 2 * bspan_margin_v,
                        margin = 0,
                        padding = 0,
                        bordersize = bspan_border,
                        background = bgcolor,
                        CenterContainer:new{
                            dimen = Geom:new{
                                w = width - 2 * (bspan_margin_h + bspan_border),
                                h = self.span_height - 2 * (bspan_margin_v + bspan_border),
                            },
                            TextWidget:new{
                                text = BD.auto(book.title),
                                max_width = width - 2 * (bspan_margin_h + bspan_border + bspan_padding_h),
                                face = Font:getFace(self.font_face, inner_font_size),
                                padding = 0,
                                fgcolor = fgcolor,
                            }
                        }
                    }
                }
                table.insert(overlaps, span_w)
            end
        end
    end

    self[1] = LeftContainer:new{
        dimen = self.dimen:copy(),
        overlaps,
    }
end

local ZmanimCalendar = InputContainer:new{
    zmanim = nil,
    monthTranslation = nil,
    shortDayOfWeekTranslation = nil,
    longDayOfWeekTranslation = nil,
    start_day_of_week = 1, -- 1-7 = Sunday-Saturday
    nb_book_spans = 3,
    font_face = "xx_smallinfofont",
    title = "",
    width = nil,
    height = nil,
    cur_month = nil,
    weekdays = { "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" } -- in Lua wday order
        -- (These do not need translations: they are the key into the provided
        -- self.shortDayOfWeekTranslation and self.longDayOfWeekTranslation)
}

function ZmanimCalendar:init()
    self.dimen = Geom:new{
        w = self.width or Screen:getWidth(),
        h = self.height or Screen:getHeight(),
    }
    if self.dimen.w == Screen:getWidth() and self.dimen.h == Screen:getHeight() then
        self.covers_fullscreen = true -- hint for UIManager:_repaint()
    end

    if Device:hasKeys() then
        self.key_events = {
            Close = { {"Back"}, doc = "close page" },
            NextMonth = {{Input.group.PgFwd}, doc = "next page"},
            PrevMonth = {{Input.group.PgBack}, doc = "prev page"},
        }
    end
    if Device:isTouchDevice() then
        self.ges_events.Swipe = {
            GestureRange:new{
                ges = "swipe",
                range = self.dimen,
            }
        }
    end

    local outer_padding = Size.padding.large
    self.inner_padding = Size.padding.small

    -- 7 days in a week
    self.day_width = math.floor((self.dimen.w - 2*outer_padding - 6*self.inner_padding) / 7)
    -- Put back the possible 7px lost in rounding into outer_padding
    outer_padding = math.floor((self.dimen.w - 7*self.day_width - 6*self.inner_padding) / 2)
    self.content_width = self.dimen.w - 2*outer_padding

    local now_ts = os.time()
    if not self.cur_month then
        self.cur_month = os.date("%Y-%m", now_ts)
    end

    -- group for page info
    local chevron_left = "chevron.left"
    local chevron_right = "chevron.right"
    local chevron_first = "chevron.first"
    local chevron_last = "chevron.last"
    if BD.mirroredUILayout() then
        chevron_left, chevron_right = chevron_right, chevron_left
        chevron_first, chevron_last = chevron_last, chevron_first
    end
    self.page_info_left_chev = Button:new{
        icon = chevron_left,
        callback = function() self:prevMonth() end,
        bordersize = 0,
        show_parent = self,
    }
    self.page_info_right_chev = Button:new{
        icon = chevron_right,
        callback = function() self:nextMonth() end,
        bordersize = 0,
        show_parent = self,
    }
    self.page_info_first_chev = Button:new{
        icon = chevron_first,
        callback = function() self:prevMonth(true) end,
        bordersize = 0,
        show_parent = self,
    }
    self.page_info_last_chev = Button:new{
        icon = chevron_last,
        callback = function() self:nextMonth(true) end,
        bordersize = 0,
        show_parent = self,
    }
    self.page_info_spacer = HorizontalSpan:new{
        width = Screen:scaleBySize(32),
    }

    self.page_info_text = Button:new{
        text = "",
        hold_input = {
            title = _("Enter month"),
            input_func = function() return self.cur_month end,
            callback = function(input)
                local year, month = input:match("^(%d%d%d%d)-(%d%d)$")
                if year and month then
                    if tonumber(month) >= 1 and tonumber(month) <= 12 and tonumber(year) >= 1000 then
                        -- Allow seeing arbitrary year-month in the past or future.
                        -- (year >= 1000 to ensure %Y keeps returning 4 digits)
                        self:goToMonth(input)
                        return
                    end
                end
                local InfoMessage = require("ui/widget/infomessage")
                UIManager:show(InfoMessage:new{
                    text = _("Invalid year-month string (YYYY-MM)"),
                })
            end,
        },
        callback = function()
            self:goToMonth(os.date("%Y-%m", os.time()))
            return
        end,
        bordersize = 0,
        margin = Screen:scaleBySize(20),
        text_font_face = "pgfont",
        text_font_bold = false,
    }
    self.page_info = HorizontalGroup:new{
        self.page_info_first_chev,
        self.page_info_spacer,
        self.page_info_left_chev,
        self.page_info_text,
        self.page_info_right_chev,
        self.page_info_spacer,
        self.page_info_last_chev,
    }

    local footer = BottomContainer:new{
        dimen = Geom:new{
            w = self.content_width,
            h = self.dimen.h,
        },
        self.page_info,
    }

    self.title_bar = CalendarTitle:new{
        title = self.title,
        width = self.content_width,
        height = Size.item.height_default,
        calendar_view = self,
    }

    -- week days names header
    self.day_names = HorizontalGroup:new{}
    for i = 0, 6 do
        local dayname = TextWidget:new{
            text = self.shortDayOfWeekTranslation[self.weekdays[(self.start_day_of_week-1+i)%7 + 1]],
            face = Font:getFace("xx_smallinfofont"),
            bold = true,
        }
        table.insert(self.day_names, FrameContainer:new{
            padding = 0,
            bordersize = 0,
            CenterContainer:new{
                dimen = Geom:new{ w = self.day_width, h = dayname:getSize().h },
                dayname,
            }
        })
        if i < 6 then
            table.insert(self.day_names, HorizontalSpan:new{ width = self.inner_padding, })
        end
    end

    -- At most 6 weeks in a month
    local available_height = self.dimen.h - self.title_bar:getSize().h
                            - self.page_info:getSize().h - self.day_names:getSize().h
    self.week_height = math.floor((available_height - 5*self.inner_padding) / 6)
    self.day_border = Size.border.default
    -- day num + nb_book_span: floor() to get some room for bottom padding
    self.span_height = math.floor((self.week_height - 2*self.day_border) / (self.nb_book_spans+1))
    -- Limit font size to 1/3 of available height, and so that
    -- the day number and the +nb-not-shown do not overlap
    local text_height = math.min(self.span_height, self.week_height/3)
    self.span_font_size = TextBoxWidget:getFontSizeToFitHeight(text_height, 1, 0.3)
    local day_inner_width = self.day_width - 2*self.day_border -2*self.inner_padding
    while true do
        local test_w = TextWidget:new{
            text = " 30 + 99 ", -- we want this to be displayed in the available width
            face = Font:getFace(self.font_face, self.span_font_size),
            bold = true,
        }
        if test_w:getWidth() <= day_inner_width then
            test_w:free()
            break
        end
        self.span_font_size = self.span_font_size - 1
        test_w:free()
    end

    self.main_content = VerticalGroup:new{}
    self:_populateItems()

    local content = OverlapGroup:new{
        dimen = Geom:new{
            w = self.content_width,
            h = self.dimen.h,
        },
        allow_mirroring = false,
        VerticalGroup:new{
            align = "left",
            self.title_bar,
            self.day_names,
            self.main_content,
        },
        footer,
    }
    -- assemble page
    self[1] = FrameContainer:new{
        width = self.dimen.w,
        height = self.dimen.h,
        padding = outer_padding,
        bordersize = 0,
        background = Blitbuffer.COLOR_WHITE,
        content
    }
end

function ZmanimCalendar:_populateItems()
    self.page_info:resetLayout()
    self.main_content:clear()

    -- See https://www.lua.org/pil/22.1.html for info about os.time() and os.date()
    local month_start_ts = os.time({
        year = self.cur_month:sub(1,4),
        month = self.cur_month:sub(6),
        day = 1,
        -- When hour is unspecified, Lua defaults to noon 12h00
    })
    -- Update title
    local month_text = self.monthTranslation[os.date("%B", month_start_ts)] .. os.date(" %Y", month_start_ts)
    self.title_bar:setTitle(month_text)
    -- Update footer
    self.page_info_text:setText(self.cur_month)

    local books_by_day = {} --self.reader_statistics:getReadBookByDay(self.cur_month)

    table.insert(self.main_content, VerticalSpan:new{ width = self.inner_padding })
    self.weeks = {}
    local today_s = os.date("%Y-%m-%d", os.time())
    local cur_ts = month_start_ts
    local cur_date = os.date("*t", cur_ts)
    local this_month = cur_date.month
    local cur_week
    while true do
        cur_date = os.date("*t", cur_ts)
        if cur_date.month ~= this_month then
            break
        end
        if not cur_week or cur_date.wday == self.start_day_of_week then
            if cur_week then
                table.insert(self.main_content, VerticalSpan:new{ width = self.inner_padding })
            end
            cur_week = CalendarWeek:new{
                height = self.week_height,
                width = self.content_width,
                day_width = self.day_width,
                day_padding = self.inner_padding,
                day_border = self.day_border,
                nb_book_spans = self.nb_book_spans,
                span_height = self.span_height,
                font_face = self.font_face,
                font_size = self.span_font_size,
                show_parent = self,
            }
            table.insert(self.weeks, cur_week)
            table.insert(self.main_content, cur_week)
            if cur_date.wday ~= self.start_day_of_week then
                -- Add fake days to fill week
                local day = self.start_day_of_week
                while day ~= cur_date.wday do
                    cur_week:addDay(CalendarDay:new{
                        filler = true,
                        height = self.week_height,
                        width = self.day_width,
                        border = self.day_border,
                        show_parent = self,
                    })
                    day = day + 1
                    if day == 8 then
                        day = 1
                    end
                end
            end
        end
        local day_s = os.date("%Y-%m-%d", cur_ts)
        local day_text = string.format("%s (%s)", day_s,
                self.longDayOfWeekTranslation[self.weekdays[cur_date.wday]])
        local day_ts = os.time({
            year = cur_date.year,
            month = cur_date.month,
            day = cur_date.day,
            hour = 0,
        })
        local is_future = false --day_s > today_s
        local hebday = self.zmanim:getDate(day_ts)
        cur_week:addDay(CalendarDay:new{
            font_face = self.font_face,
            font_size = self.span_font_size,
            border = self.day_border,
            is_future = is_future,
            daynum = cur_date.day,
            height = self.week_height,
            width = self.day_width,
            show_parent = self,
            hebday = hebday,
            callback = function()
                -- Just as ReaderStatistics:callbackDaily(), but without any window stacking
                UIManager:show(KeyValuePage:new{
                    title = day_text,
                    value_align = "right",
                    kv_pairs = self.zmanim:getDay(day_ts),
                    callback_return = function() end -- to just have that return button shown
                })
            end
        })
        cur_ts = cur_ts + 86400 -- add one day
    end
    for _, week in ipairs(self.weeks) do
        week:update()
    end

    UIManager:setDirty(self, function()
        return "ui", self.dimen
    end)
end

function ZmanimCalendar:nextMonth(year)
    local t = os.time({
        year = self.cur_month:sub(1,4),
        month = self.cur_month:sub(6),
        day = 15,
    })
    t = t + 86400 * (year and 365 or 30) -- 30 days later
    local next_month = os.date("%Y-%m", t)
    self.cur_month = next_month
    self:_populateItems()
end

function ZmanimCalendar:prevMonth(year)
    local t = os.time({
        year = self.cur_month:sub(1,4),
        month = self.cur_month:sub(6),
        day = 15,
    })
    t = t - 86400 * (year and 365 or 30) -- 30 days before
    local prev_month = os.date("%Y-%m", t)
    self.cur_month = prev_month
    self:_populateItems()
end

function ZmanimCalendar:goToMonth(month)
    self.cur_month = month
    self:_populateItems()
end

function ZmanimCalendar:onNextMonth()
    self:nextMonth()
    return true
end

function ZmanimCalendar:onPrevMonth()
    self:prevMonth()
    return true
end

function ZmanimCalendar:onSwipe(arg, ges_ev)
    local direction = BD.flipDirectionIfMirroredUILayout(ges_ev.direction)
    if direction == "west" then
        self:nextMonth()
        return true
    elseif direction == "east" then
        self:prevMonth()
        return true
    elseif direction == "south" then
        -- Allow easier closing with swipe down
        self:onClose()
    elseif direction == "north" then
        -- no use for now
        do end -- luacheck: ignore 541
    else -- diagonal swipe
        -- trigger full refresh
        UIManager:setDirty(nil, "full")
        -- a long diagonal swipe may also be used for taking a screenshot,
        -- so let it propagate
        return false
    end
end

function ZmanimCalendar:onClose()
    UIManager:close(self)
    return true
end

return ZmanimCalendar
