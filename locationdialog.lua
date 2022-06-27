local Blitbuffer = require("ffi/blitbuffer")
local ButtonTable = require("ui/widget/buttontable")
local CenterContainer = require("ui/widget/container/centercontainer")
local DataStorage = require("datastorage")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local InputDialog = require("ui/widget/inputdialog")
local LuaSettings = require("luasettings")
local MovableContainer = require("ui/widget/container/movablecontainer")
local RadioButtonTable = require("ui/widget/radiobuttontable")
local Size = require("ui/size")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local ZmanimUtil = require("zmanimutil")
local _ = require("gettext")
local Screen = require("device").screen

local LocationDialog = InputDialog:extend{}

function LocationDialog:init()
    -- init title and buttons in base class
    InputDialog.init(self)

    self.face = Font:getFace("cfont", 22)
    self.element_width = math.floor(self.width * 0.9)

    local place = G_reader_settings:readSetting("zmanim_place")
    local places = LuaSettings:open(DataStorage:getSettingsDir() .. "/zmanim_locations.lua")

    local radio_buttons = {}
    for k, v in ipairs(places.data) do
        table.insert(radio_buttons, {
            {
            text = v.name,
            checked = place.name == v.name,
            provider = v,
            },
        })
    end
    if next(radio_buttons) == nil then
        table.insert(radio_buttons, {
            {
            text = place.name,
            checked = true,
            provider = place,
            },
        })
    end

    local buttons = {}
    table.insert(buttons, {
            {
                text = _("Cancel"),
                callback = function()
                    UIManager:close(self)
                end,
            },
            {
                text = _("Select"),
                is_enter_default = true,
                callback = function()
                    ZmanimUtil:setLocation(self.radio_button_table.checked_button.provider, true)
                    UIManager:close(self)
                end,
            },
        })

    self.radio_button_table = RadioButtonTable:new{
        radio_buttons = radio_buttons,
        width = self.element_width,
        focused = true,
        scroll = false,
        parent = self,
        face = self.face,
    }

    -- Buttons Table
    self.button_table = ButtonTable:new{
        width = self.width - 2*self.button_padding,
        button_font_face = "cfont",
        button_font_size = 20,
        buttons = buttons,
        zero_sep = true,
        show_parent = self,
    }

    self.dialog_frame = FrameContainer:new{
        radius = Size.radius.window,
        bordersize = Size.border.window,
        padding = 0,
        margin = 0,
        background = Blitbuffer.COLOR_WHITE,
        VerticalGroup:new{
            align = "center",
            self.title_bar,
            VerticalSpan:new{
                width = Size.span.vertical_large*2,
            },
            CenterContainer:new{
                dimen = Geom:new{
                    w = self.title_bar:getSize().w,
                    h = self.radio_button_table:getSize().h,
                },
                self.radio_button_table,
            },
            VerticalSpan:new{
                width = Size.span.vertical_large*2,
            },
            -- buttons
            CenterContainer:new{
                dimen = Geom:new{
                    w = self.title_bar:getSize().w,
                    h = self.button_table:getSize().h,
                },
                self.button_table,
            }
        }
    }

    self._input_widget = self.radio_button_table

    self.movable = MovableContainer:new{
        self.dialog_frame,
    }
    self[1] = CenterContainer:new{
        dimen = Geom:new{
            w = Screen:getWidth(),
            h = Screen:getHeight(),
        },
        self.movable,
    }
end

function LocationDialog:onCloseWidget()
    UIManager:setDirty(nil, function()
        return "ui", self.dialog_frame.dimen
    end)
end

return LocationDialog
