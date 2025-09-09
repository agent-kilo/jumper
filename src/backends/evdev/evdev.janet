(import ../../log)


(var interface nil)
(var structs   nil)


(def signatures
  {'new                        [:ptr]
   'new_from_fd                [:int32   :int32 :ptr]       # fd, **dev
   'free                       [:void    :ptr]              # *dev
   'get_phys                   [:string  :ptr]              # *dev
   'get_name                   [:string  :ptr]              # *dev
   'next_event                 [:int32   :ptr :uint32 :ptr] # *dev, flags, *ev
   'set_name                   [:void    :ptr :string]      # *dev, name
   'enable_property            [:int32   :ptr :uint32]      # *dev, prop
   'disable_property           [:int32   :ptr :uint32]      # *dev, prop
   'enable_event_type          [:int32   :ptr :uint32]      # *dev, type
   'disable_event_type         [:int32   :ptr :uint32]      # *dev, type
   'enable_event_code          [:int32   :ptr :uint32 :uint32 :ptr]   # *dev, type, code, *data
   'disable_event_code         [:int32   :ptr :uint32 :uint32]        # *dev, type, code
   'uinput_create_from_device  [:int32   :ptr :int32 :ptr]  # *dev, uinput_fd, **uinput_dev
   'uinput_destroy             [:void    :ptr]              # *uinput_dev
   'uinput_write_event         [:int32   :ptr :uint32 :uint32 :int32] # *uinput_dev, type, code, value
  })


(def func-cache @{})


(defn get-structs []
  (if structs
    structs
    (set structs
         {'input_event (ffi/struct
                         :int64   # time.tv_sec
                         :int64   # time.tv_usec
                         :uint16  # type
                         :uint16  # code
                         :int32   # value
                         # 24 bytes
                         )
          'input_absinfo (ffi/struct
                           :int32  # value
                           :int32  # minimum
                           :int32  # maximum
                           :int32  # fuzz
                           :int32  # flat
                           :int32  # resolution
                           # 24 bytes
                          )})))


(defn load-interface []
  (if interface
    interface
    (set interface (ffi/native "libevdev.so.2"))))


(defn call-interface [name & args]
  (def intf (load-interface))
  (def [sym sig]
    (if-let [cached (in func-cache name)]
      cached
      # else
      (let [ret [(ffi/lookup intf (string "libevdev_" name))
                 (ffi/signature :default ;(in signatures (symbol name)))]]
        (put func-cache name ret)
        ret)))
  (ffi/call sym sig ;args))


(defn open [path flags]
  (def intf (ffi/native))
  (def sym  (ffi/lookup intf "open"))
  (def sig  (ffi/signature :default :int32  :string :int32))
  (ffi/call sym sig path flags))


(defn close [fd]
  (def intf (ffi/native))
  (def sym  (ffi/lookup intf "close"))
  (def sig  (ffi/signature :default :int32  :int32))
  (ffi/call sym sig fd))


(defn fcntl [fd cmd val]
  (def intf (ffi/native))
  (def sym  (ffi/lookup intf "fcntl"))
  (def sig  (ffi/signature :default :int32  :int32 :int32 :int32))
  (ffi/call sym sig fd cmd val))


(defn open-rd-nonblock [path]
  (def O_RDONLY   0x000)
  (def O_NONBLOCK 0x800) # 04000 in octal
  (def F_GETFL    3)
  (def F_SETFL    4)

  (def fd (open path O_RDONLY))
  (when (< fd 0)
    (errorf "failed to open file in read-only mode: %n" path))

  (def flags (fcntl fd F_GETFL 0))
  (when (< flags 0)
    (close fd)
    (errorf "failed to get file status flags: %n" path))

  (def ret (fcntl fd F_SETFL (bor flags O_NONBLOCK)))
  (when (< ret 0)
    (close fd)
    (errorf "failed to set non-blocking flag: %n" path))

  fd)


(def READ_FLAG_SYNC       1)
(def READ_FLAG_NORMAL     2)
(def READ_FLAG_FORCE_SYNC 4)
(def READ_FLAG_BLOCKING   8)


(def READ_STATUS_SUCCESS 0)
(def READ_STATUS_SYNC    1)


(def INPUT_PROP_POINTER         0x00)
(def INPUT_PROP_DIRECT          0x01)
(def INPUT_PROP_BUTTONPAD       0x02)
(def INPUT_PROP_SEMI_MT         0x03)
(def INPUT_PROP_TOPBUTTONPAD    0x04)
(def INPUT_PROP_POINTING_STICK  0x05)
(def INPUT_PROP_ACCELEROMETER   0x06)
(def INPUT_PROP_MAX             0x1f)
(def INPUT_PROP_CNT             (+ 1 INPUT_PROP_MAX))


(def EV_SYN        0x00)
(def EV_KEY        0x01)
(def EV_REL        0x02)
(def EV_ABS        0x03)
(def EV_MSC        0x04)
(def EV_SW         0x05)
(def EV_LED        0x11)
(def EV_SND        0x12)
(def EV_REP        0x14)
(def EV_FF         0x15)
(def EV_PWR        0x16)
(def EV_FF_STATUS  0x17)
(def EV_MAX        0x1f)
(def EV_CNT        (+ 1 EV_MAX))


(def REL_X              0x00)
(def REL_Y              0x01)
(def REL_Z              0x02)
(def REL_RX             0x03)
(def REL_RY             0x04)
(def REL_RZ             0x05)
(def REL_HWHEEL         0x06)
(def REL_DIAL           0x07)
(def REL_WHEEL          0x08)
(def REL_MISC           0x09)
(def REL_RESERVED       0x0a)
(def REL_WHEEL_HI_RES   0x0b)
(def REL_HWHEEL_HI_RES  0x0c)
(def REL_MAX            0x0f)
(def REL_CNT            (+ 1 REL_MAX))


(def ABS_X           0x00)
(def ABS_Y           0x01)
(def ABS_Z           0x02)
(def ABS_RX          0x03)
(def ABS_RY          0x04)
(def ABS_RZ          0x05)
(def ABS_THROTTLE    0x06)
(def ABS_RUDDER      0x07)
(def ABS_WHEEL       0x08)
(def ABS_GAS         0x09)
(def ABS_BRAKE       0x0a)
(def ABS_HAT0X       0x10)
(def ABS_HAT0Y       0x11)
(def ABS_HAT1X       0x12)
(def ABS_HAT1Y       0x13)
(def ABS_HAT2X       0x14)
(def ABS_HAT2Y       0x15)
(def ABS_HAT3X       0x16)
(def ABS_HAT3Y       0x17)
(def ABS_PRESSURE    0x18)
(def ABS_DISTANCE    0x19)
(def ABS_TILT_X      0x1a)
(def ABS_TILT_Y      0x1b)
(def ABS_TOOL_WIDTH  0x1c)
(def ABS_VOLUME      0x20)
(def ABS_PROFILE     0x21)
(def ABS_MISC        0x28)
(def ABS_RESERVED    0x2e)
(def ABS_MT_SLOT         0x2f)
(def ABS_MT_TOUCH_MAJOR  0x30)
(def ABS_MT_TOUCH_MINOR  0x31)
(def ABS_MT_WIDTH_MAJOR  0x32)
(def ABS_MT_WIDTH_MINOR  0x33)
(def ABS_MT_ORIENTATION  0x34)
(def ABS_MT_POSITION_X   0x35)
(def ABS_MT_POSITION_Y   0x36)
(def ABS_MT_TOOL_TYPE    0x37)
(def ABS_MT_BLOB_ID      0x38)
(def ABS_MT_TRACKING_ID  0x39)
(def ABS_MT_PRESSURE     0x3a)
(def ABS_MT_DISTANCE     0x3b)
(def ABS_MT_TOOL_X       0x3c)
(def ABS_MT_TOOL_Y       0x3d)
(def ABS_MAX             0x3f)
(def ABS_CNT             (+ 1 ABS_MAX))


######### Key and Button Codes #########

(def KEY_RESERVED   0)
(def KEY_ESC        1)
(def KEY_1          2)
(def KEY_2          3)
(def KEY_3          4)
(def KEY_4          5)
(def KEY_5          6)
(def KEY_6          7)
(def KEY_7          8)
(def KEY_8          9)
(def KEY_9          10)
(def KEY_0          11)
(def KEY_MINUS      12)
(def KEY_EQUAL      13)
(def KEY_BACKSPACE  14)
(def KEY_TAB        15)
(def KEY_Q          16)
(def KEY_W          17)
(def KEY_E          18)
(def KEY_R          19)
(def KEY_T          20)
(def KEY_Y          21)
(def KEY_U          22)
(def KEY_I          23)
(def KEY_O          24)
(def KEY_P          25)
(def KEY_LEFTBRACE  26)
(def KEY_RIGHTBRACE 27)
(def KEY_ENTER      28)
(def KEY_LEFTCTRL   29)
(def KEY_A          30)
(def KEY_S          31)
(def KEY_D          32)
(def KEY_F          33)
(def KEY_G          34)
(def KEY_H          35)
(def KEY_J          36)
(def KEY_K          37)
(def KEY_L          38)
(def KEY_SEMICOLON  39)
(def KEY_APOSTROPHE 40)
(def KEY_GRAVE      41)
(def KEY_LEFTSHIFT  42)
(def KEY_BACKSLASH  43)
(def KEY_Z          44)
(def KEY_X          45)
(def KEY_C          46)
(def KEY_V          47)
(def KEY_B          48)
(def KEY_N          49)
(def KEY_M          50)
(def KEY_COMMA      51)
(def KEY_DOT        52)
(def KEY_SLASH      53)
(def KEY_RIGHTSHIFT 54)
(def KEY_KPASTERISK 55)
(def KEY_LEFTALT    56)
(def KEY_SPACE      57)
(def KEY_CAPSLOCK   58)
(def KEY_F1         59)
(def KEY_F2         60)
(def KEY_F3         61)
(def KEY_F4         62)
(def KEY_F5         63)
(def KEY_F6         64)
(def KEY_F7         65)
(def KEY_F8         66)
(def KEY_F9         67)
(def KEY_F10        68)
(def KEY_NUMLOCK    69)
(def KEY_SCROLLLOCK 70)
(def KEY_KP7        71)
(def KEY_KP8        72)
(def KEY_KP9        73)
(def KEY_KPMINUS    74)
(def KEY_KP4        75)
(def KEY_KP5        76)
(def KEY_KP6        77)
(def KEY_KPPLUS     78)
(def KEY_KP1        79)
(def KEY_KP2        80)
(def KEY_KP3        81)
(def KEY_KP0        82)
(def KEY_KPDOT      83)
(def KEY_ZENKAKUHANKAKU 85)
(def KEY_102ND      86)
(def KEY_F11        87)
(def KEY_F12        88)
(def KEY_RO         89)
(def KEY_KATAKANA   90)
(def KEY_HIRAGANA   91)
(def KEY_HENKAN     92)
(def KEY_KATAKANAHIRAGANA 93)
(def KEY_MUHENKAN   94)
(def KEY_KPJPCOMMA  95)
(def KEY_KPENTER    96)
(def KEY_RIGHTCTRL  97)
(def KEY_KPSLASH    98)
(def KEY_SYSRQ      99)
(def KEY_RIGHTALT   100)
(def KEY_LINEFEED   101)
(def KEY_HOME       102)
(def KEY_UP         103)
(def KEY_PAGEUP     104)
(def KEY_LEFT       105)
(def KEY_RIGHT      106)
(def KEY_END        107)
(def KEY_DOWN       108)
(def KEY_PAGEDOWN   109)
(def KEY_INSERT     110)
(def KEY_DELETE     111)
(def KEY_MACRO      112)
(def KEY_MUTE       113)
(def KEY_VOLUMEDOWN 114)
(def KEY_VOLUMEUP   115)
(def KEY_POWER      116)
(def KEY_KPEQUAL    117)
(def KEY_KPPLUSMINUS 118)
(def KEY_PAUSE      119)
(def KEY_SCALE      120)
(def KEY_KPCOMMA    121)
(def KEY_HANGEUL    122)
(def KEY_HANGUEL    KEY_HANGEUL)
(def KEY_HANJA      123)
(def KEY_YEN        124)
(def KEY_LEFTMETA   125)
(def KEY_RIGHTMETA  126)
(def KEY_COMPOSE    127)
(def KEY_STOP       128)
(def KEY_AGAIN      129)
(def KEY_PROPS      130)
(def KEY_UNDO       131)
(def KEY_FRONT      132)
(def KEY_COPY       133)
(def KEY_OPEN       134)
(def KEY_PASTE      135)
(def KEY_FIND       136)
(def KEY_CUT        137)
(def KEY_HELP       138)
(def KEY_MENU       139)
(def KEY_CALC       140)
(def KEY_SETUP      141)
(def KEY_SLEEP      142)
(def KEY_WAKEUP     143)
(def KEY_FILE       144)
(def KEY_SENDFILE   145)
(def KEY_DELETEFILE 146)
(def KEY_XFER       147)
(def KEY_PROG1      148)
(def KEY_PROG2      149)
(def KEY_WWW        150)
(def KEY_MSDOS      151)
(def KEY_COFFEE     152)
(def KEY_SCREENLOCK KEY_COFFEE)
(def KEY_ROTATE_DISPLAY 153)
(def KEY_DIRECTION  KEY_ROTATE_DISPLAY)
(def KEY_CYCLEWINDOWS 154)
(def KEY_MAIL       155)
(def KEY_BOOKMARKS  156)
(def KEY_COMPUTER   157)
(def KEY_BACK       158)
(def KEY_FORWARD    159)
(def KEY_CLOSECD    160)
(def KEY_EJECTCD    161)
(def KEY_EJECTCLOSECD 162)
(def KEY_NEXTSONG   163)
(def KEY_PLAYPAUSE  164)
(def KEY_PREVIOUSSONG 165)
(def KEY_STOPCD     166)
(def KEY_RECORD     167)
(def KEY_REWIND     168)
(def KEY_PHONE      169)
(def KEY_ISO        170)
(def KEY_CONFIG     171)
(def KEY_HOMEPAGE   172)
(def KEY_REFRESH    173)
(def KEY_EXIT       174)
(def KEY_MOVE       175)
(def KEY_EDIT       176)
(def KEY_SCROLLUP   177)
(def KEY_SCROLLDOWN 178)
(def KEY_KPLEFTPAREN 179)
(def KEY_KPRIGHTPAREN 180)
(def KEY_NEW        181)
(def KEY_REDO       182)
(def KEY_F13        183)
(def KEY_F14        184)
(def KEY_F15        185)
(def KEY_F16        186)
(def KEY_F17        187)
(def KEY_F18        188)
(def KEY_F19        189)
(def KEY_F20        190)
(def KEY_F21        191)
(def KEY_F22        192)
(def KEY_F23        193)
(def KEY_F24        194)

(def KEY_PLAYCD     200)
(def KEY_PAUSECD    201)
(def KEY_PROG3      202)
(def KEY_PROG4      203)
(def KEY_ALL_APPLICATIONS 204)
(def KEY_DASHBOARD  KEY_ALL_APPLICATIONS)
(def KEY_SUSPEND    205)
(def KEY_CLOSE      206)
(def KEY_PLAY       207)
(def KEY_FASTFORWARD 208)
(def KEY_BASSBOOST  209)
(def KEY_PRINT      210)
(def KEY_HP         211)
(def KEY_CAMERA     212)
(def KEY_SOUND      213)
(def KEY_QUESTION   214)
(def KEY_EMAIL      215)
(def KEY_CHAT       216)
(def KEY_SEARCH     217)
(def KEY_CONNECT    218)
(def KEY_FINANCE    219)
(def KEY_SPORT      220)
(def KEY_SHOP       221)
(def KEY_ALTERASE   222)
(def KEY_CANCEL     223)
(def KEY_BRIGHTNESSDOWN	224)
(def KEY_BRIGHTNESSUP 225)
(def KEY_MEDIA      226)
(def KEY_SWITCHVIDEOMODE 227)
(def KEY_KBDILLUMTOGGLE 228)
(def KEY_KBDILLUMDOWN 229)
(def KEY_KBDILLUMUP 230)
(def KEY_SEND       231)
(def KEY_REPLY      232)
(def KEY_FORWARDMAIL 233)
(def KEY_SAVE       234)
(def KEY_DOCUMENTS  235)
(def KEY_BATTERY    236)
(def KEY_BLUETOOTH  237)
(def KEY_WLAN       238)
(def KEY_UWB        239)
(def KEY_UNKNOWN    240)
(def KEY_VIDEO_NEXT 241)
(def KEY_VIDEO_PREV 242)
(def KEY_BRIGHTNESS_CYCLE 243)
(def KEY_BRIGHTNESS_AUTO 244)
(def KEY_BRIGHTNESS_ZERO KEY_BRIGHTNESS_AUTO)
(def KEY_DISPLAY_OFF 245)
(def KEY_WWAN       246)
(def KEY_WIMAX      KEY_WWAN)
(def KEY_RFKILL     247)
(def KEY_MICMUTE    248)

(def BTN_MISC  0x100)
(def BTN_0     0x100)
(def BTN_1     0x101)
(def BTN_2     0x102)
(def BTN_3     0x103)
(def BTN_4     0x104)
(def BTN_5     0x105)
(def BTN_6     0x106)
(def BTN_7     0x107)
(def BTN_8     0x108)
(def BTN_9     0x109)
(def BTN_MOUSE    0x110)
(def BTN_LEFT     0x110)
(def BTN_RIGHT    0x111)
(def BTN_MIDDLE   0x112)
(def BTN_SIDE     0x113)
(def BTN_EXTRA    0x114)
(def BTN_FORWARD  0x115)
(def BTN_BACK     0x116)
(def BTN_TASK     0x117)
(def BTN_JOYSTICK  0x120)
(def BTN_TRIGGER   0x120)
(def BTN_THUMB     0x121)
(def BTN_THUMB2    0x122)
(def BTN_TOP       0x123)
(def BTN_TOP2      0x124)
(def BTN_PINKIE    0x125)
(def BTN_BASE      0x126)
(def BTN_BASE2     0x127)
(def BTN_BASE3     0x128)
(def BTN_BASE4     0x129)
(def BTN_BASE5     0x12a)
(def BTN_BASE6     0x12b)
(def BTN_DEAD      0x12f)
(def BTN_GAMEPAD   0x130)
(def BTN_SOUTH     0x130)
(def BTN_A         BTN_SOUTH)
(def BTN_EAST      0x131)
(def BTN_B         BTN_EAST)
(def BTN_C         0x132)
(def BTN_NORTH     0x133)
(def BTN_X         BTN_NORTH)
(def BTN_WEST      0x134)
(def BTN_Y         BTN_WEST)
(def BTN_Z         0x135)
(def BTN_TL        0x136)
(def BTN_TR        0x137)
(def BTN_TL2       0x138)
(def BTN_TR2       0x139)
(def BTN_SELECT    0x13a)
(def BTN_START     0x13b)
(def BTN_MODE      0x13c)
(def BTN_THUMBL    0x13d)
(def BTN_THUMBR    0x13e)
(def BTN_DIGI           0x140)
(def BTN_TOOL_PEN       0x140)
(def BTN_TOOL_RUBBER    0x141)
(def BTN_TOOL_BRUSH     0x142)
(def BTN_TOOL_PENCIL    0x143)
(def BTN_TOOL_AIRBRUSH  0x144)
(def BTN_TOOL_FINGER    0x145)
(def BTN_TOOL_MOUSE     0x146)
(def BTN_TOOL_LENS      0x147)
(def BTN_TOOL_QUINTTAP  0x148)
(def BTN_STYLUS3        0x149)
(def BTN_TOUCH          0x14a)
(def BTN_STYLUS         0x14b)
(def BTN_STYLUS2        0x14c)
(def BTN_TOOL_DOUBLETAP 0x14d)
(def BTN_TOOL_TRIPLETAP 0x14e)
(def BTN_TOOL_QUADTAP   0x14f)
(def BTN_WHEEL          0x150)
(def BTN_GEAR_DOWN      0x150)
(def BTN_GEAR_UP        0x151)

(def KEY_OK             0x160)
(def KEY_SELECT         0x161)
(def KEY_GOTO           0x162)
(def KEY_CLEAR          0x163)
(def KEY_POWER2         0x164)
(def KEY_OPTION         0x165)
(def KEY_INFO           0x166)
(def KEY_TIME           0x167)
(def KEY_VENDOR         0x168)
(def KEY_ARCHIVE        0x169)
(def KEY_PROGRAM        0x16a)
(def KEY_CHANNEL        0x16b)
(def KEY_FAVORITES      0x16c)
(def KEY_EPG            0x16d)
(def KEY_PVR            0x16e)
(def KEY_MHP            0x16f)
(def KEY_LANGUAGE       0x170)
(def KEY_TITLE          0x171)
(def KEY_SUBTITLE       0x172)
(def KEY_ANGLE          0x173)
(def KEY_FULL_SCREEN    0x174)
(def KEY_ZOOM           KEY_FULL_SCREEN)
(def KEY_MODE           0x175)
(def KEY_KEYBOARD       0x176)
(def KEY_ASPECT_RATIO   0x177)
(def KEY_SCREEN         KEY_ASPECT_RATIO)
(def KEY_PC             0x178)
(def KEY_TV             0x179)
(def KEY_TV2            0x17a)
(def KEY_VCR            0x17b)
(def KEY_VCR2           0x17c)
(def KEY_SAT            0x17d)
(def KEY_SAT2           0x17e)
(def KEY_CD             0x17f)
(def KEY_TAPE           0x180)
(def KEY_RADIO          0x181)
(def KEY_TUNER          0x182)
(def KEY_PLAYER         0x183)
(def KEY_TEXT           0x184)
(def KEY_DVD            0x185)
(def KEY_AUX            0x186)
(def KEY_MP3            0x187)
(def KEY_AUDIO          0x188)
(def KEY_VIDEO          0x189)
(def KEY_DIRECTORY      0x18a)
(def KEY_LIST           0x18b)
(def KEY_MEMO           0x18c)
(def KEY_CALENDAR       0x18d)
(def KEY_RED            0x18e)
(def KEY_GREEN          0x18f)
(def KEY_YELLOW         0x190)
(def KEY_BLUE           0x191)
(def KEY_CHANNELUP      0x192)
(def KEY_CHANNELDOWN    0x193)
(def KEY_FIRST          0x194)
(def KEY_LAST           0x195)
(def KEY_AB             0x196)
(def KEY_NEXT           0x197)
(def KEY_RESTART        0x198)
(def KEY_SLOW           0x199)
(def KEY_SHUFFLE        0x19a)
(def KEY_BREAK          0x19b)
(def KEY_PREVIOUS       0x19c)
(def KEY_DIGITS         0x19d)
(def KEY_TEEN           0x19e)
(def KEY_TWEN           0x19f)
(def KEY_VIDEOPHONE     0x1a0)
(def KEY_GAMES          0x1a1)
(def KEY_ZOOMIN         0x1a2)
(def KEY_ZOOMOUT        0x1a3)
(def KEY_ZOOMRESET      0x1a4)
(def KEY_WORDPROCESSOR  0x1a5)
(def KEY_EDITOR         0x1a6)
(def KEY_SPREADSHEET    0x1a7)
(def KEY_GRAPHICSEDITOR 0x1a8)
(def KEY_PRESENTATION   0x1a9)
(def KEY_DATABASE       0x1aa)
(def KEY_NEWS           0x1ab)
(def KEY_VOICEMAIL      0x1ac)
(def KEY_ADDRESSBOOK    0x1ad)
(def KEY_MESSENGER      0x1ae)
(def KEY_DISPLAYTOGGLE  0x1af)
(def KEY_BRIGHTNESS_TOGGLE KEY_DISPLAYTOGGLE)
(def KEY_SPELLCHECK     0x1b0)
(def KEY_LOGOFF         0x1b1)
(def KEY_DOLLAR         0x1b2)
(def KEY_EURO           0x1b3)
(def KEY_FRAMEBACK      0x1b4)
(def KEY_FRAMEFORWARD   0x1b5)
(def KEY_CONTEXT_MENU   0x1b6)
(def KEY_MEDIA_REPEAT   0x1b7)
(def KEY_10CHANNELSUP   0x1b8)
(def KEY_10CHANNELSDOWN 0x1b9)
(def KEY_IMAGES         0x1ba)
(def KEY_NOTIFICATION_CENTER 0x1bc)
(def KEY_PICKUP_PHONE   0x1bd)
(def KEY_HANGUP_PHONE   0x1be)
(def KEY_DEL_EOL        0x1c0)
(def KEY_DEL_EOS        0x1c1)
(def KEY_INS_LINE       0x1c2)
(def KEY_DEL_LINE       0x1c3)
(def KEY_FN             0x1d0)
(def KEY_FN_ESC         0x1d1)
(def KEY_FN_F1          0x1d2)
(def KEY_FN_F2          0x1d3)
(def KEY_FN_F3          0x1d4)
(def KEY_FN_F4          0x1d5)
(def KEY_FN_F5          0x1d6)
(def KEY_FN_F6          0x1d7)
(def KEY_FN_F7          0x1d8)
(def KEY_FN_F8          0x1d9)
(def KEY_FN_F9          0x1da)
(def KEY_FN_F10         0x1db)
(def KEY_FN_F11         0x1dc)
(def KEY_FN_F12         0x1dd)
(def KEY_FN_1           0x1de)
(def KEY_FN_2           0x1df)
(def KEY_FN_D           0x1e0)
(def KEY_FN_E           0x1e1)
(def KEY_FN_F           0x1e2)
(def KEY_FN_S           0x1e3)
(def KEY_FN_B           0x1e4)
(def KEY_FN_RIGHT_SHIFT 0x1e5)
(def KEY_BRL_DOT1       0x1f1)
(def KEY_BRL_DOT2       0x1f2)
(def KEY_BRL_DOT3       0x1f3)
(def KEY_BRL_DOT4       0x1f4)
(def KEY_BRL_DOT5       0x1f5)
(def KEY_BRL_DOT6       0x1f6)
(def KEY_BRL_DOT7       0x1f7)
(def KEY_BRL_DOT8       0x1f8)
(def KEY_BRL_DOT9       0x1f9)
(def KEY_BRL_DOT10      0x1fa)
(def KEY_NUMERIC_0      0x200)
(def KEY_NUMERIC_1      0x201)
(def KEY_NUMERIC_2      0x202)
(def KEY_NUMERIC_3      0x203)
(def KEY_NUMERIC_4      0x204)
(def KEY_NUMERIC_5      0x205)
(def KEY_NUMERIC_6      0x206)
(def KEY_NUMERIC_7      0x207)
(def KEY_NUMERIC_8      0x208)
(def KEY_NUMERIC_9      0x209)
(def KEY_NUMERIC_STAR	0x20a)
(def KEY_NUMERIC_POUND	0x20b)
(def KEY_NUMERIC_A      0x20c)
(def KEY_NUMERIC_B      0x20d)
(def KEY_NUMERIC_C      0x20e)
(def KEY_NUMERIC_D      0x20f)
(def KEY_CAMERA_FOCUS   0x210)
(def KEY_WPS_BUTTON     0x211)
(def KEY_TOUCHPAD_TOGGLE 0x212)
(def KEY_TOUCHPAD_ON    0x213)
(def KEY_TOUCHPAD_OFF   0x214)
(def KEY_CAMERA_ZOOMIN  0x215)
(def KEY_CAMERA_ZOOMOUT 0x216)
(def KEY_CAMERA_UP      0x217)
(def KEY_CAMERA_DOWN    0x218)
(def KEY_CAMERA_LEFT    0x219)
(def KEY_CAMERA_RIGHT   0x21a)
(def KEY_ATTENDANT_ON   0x21b)
(def KEY_ATTENDANT_OFF  0x21c)
(def KEY_ATTENDANT_TOGGLE 0x21d)
(def KEY_LIGHTS_TOGGLE  0x21e)

(def BTN_DPAD_UP        0x220)
(def BTN_DPAD_DOWN      0x221)
(def BTN_DPAD_LEFT      0x222)
(def BTN_DPAD_RIGHT     0x223)

(def KEY_ALS_TOGGLE     0x230)
(def KEY_ROTATE_LOCK_TOGGLE 0x231)
(def KEY_REFRESH_RATE_TOGGLE 0x232)
(def KEY_BUTTONCONFIG   0x240)
(def KEY_TASKMANAGER    0x241)
(def KEY_JOURNAL        0x242)
(def KEY_CONTROLPANEL   0x243)
(def KEY_APPSELECT      0x244)
(def KEY_SCREENSAVER    0x245)
(def KEY_VOICECOMMAND   0x246)
(def KEY_ASSISTANT      0x247)
(def KEY_KBD_LAYOUT_NEXT 0x248)
(def KEY_EMOJI_PICKER   0x249)
(def KEY_DICTATE        0x24a)
(def KEY_CAMERA_ACCESS_ENABLE 0x24b)
(def KEY_CAMERA_ACCESS_DISABLE 0x24c)
(def KEY_CAMERA_ACCESS_TOGGLE 0x24d)
(def KEY_ACCESSIBILITY  0x24e)
(def KEY_DO_NOT_DISTURB 0x24f)
(def KEY_BRIGHTNESS_MIN 0x250)
(def KEY_BRIGHTNESS_MAX 0x251)
(def KEY_KBDINPUTASSIST_PREV 0x260)
(def KEY_KBDINPUTASSIST_NEXT 0x261)
(def KEY_KBDINPUTASSIST_PREVGROUP 0x262)
(def KEY_KBDINPUTASSIST_NEXTGROUP 0x263)
(def KEY_KBDINPUTASSIST_ACCEPT 0x264)
(def KEY_KBDINPUTASSIST_CANCEL 0x265)
(def KEY_RIGHT_UP       0x266)
(def KEY_RIGHT_DOWN     0x267)
(def KEY_LEFT_UP        0x268)
(def KEY_LEFT_DOWN      0x269)
(def KEY_ROOT_MENU      0x26a)
(def KEY_MEDIA_TOP_MENU 0x26b)
(def KEY_NUMERIC_11     0x26c)
(def KEY_NUMERIC_12     0x26d)
(def KEY_AUDIO_DESC     0x26e)
(def KEY_3D_MODE        0x26f)
(def KEY_NEXT_FAVORITE  0x270)
(def KEY_STOP_RECORD    0x271)
(def KEY_PAUSE_RECORD   0x272)
(def KEY_VOD            0x273)
(def KEY_UNMUTE         0x274)
(def KEY_FASTREVERSE    0x275)
(def KEY_SLOWREVERSE    0x276)
(def KEY_DATA           0x277)
(def KEY_ONSCREEN_KEYBOARD 0x278)
(def KEY_PRIVACY_SCREEN_TOGGLE 0x279)
(def KEY_SELECTIVE_SCREENSHOT 0x27a)
(def KEY_NEXT_ELEMENT   0x27b)
(def KEY_PREVIOUS_ELEMENT 0x27c)
(def KEY_AUTOPILOT_ENGAGE_TOGGLE 0x27d)
(def KEY_MARK_WAYPOINT  0x27e)
(def KEY_SOS            0x27f)
(def KEY_NAV_CHART      0x280)
(def KEY_FISHING_CHART  0x281)
(def KEY_SINGLE_RANGE_RADAR 0x282)
(def KEY_DUAL_RANGE_RADAR 0x283)
(def KEY_RADAR_OVERLAY  0x284)
(def KEY_TRADITIONAL_SONAR 0x285)
(def KEY_CLEARVU_SONAR  0x286)
(def KEY_SIDEVU_SONAR   0x287)
(def KEY_NAV_INFO       0x288)
(def KEY_BRIGHTNESS_MENU 0x289)
(def KEY_MACRO1         0x290)
(def KEY_MACRO2         0x291)
(def KEY_MACRO3         0x292)
(def KEY_MACRO4         0x293)
(def KEY_MACRO5         0x294)
(def KEY_MACRO6         0x295)
(def KEY_MACRO7         0x296)
(def KEY_MACRO8         0x297)
(def KEY_MACRO9         0x298)
(def KEY_MACRO10        0x299)
(def KEY_MACRO11        0x29a)
(def KEY_MACRO12        0x29b)
(def KEY_MACRO13        0x29c)
(def KEY_MACRO14        0x29d)
(def KEY_MACRO15        0x29e)
(def KEY_MACRO16        0x29f)
(def KEY_MACRO17        0x2a0)
(def KEY_MACRO18        0x2a1)
(def KEY_MACRO19        0x2a2)
(def KEY_MACRO20        0x2a3)
(def KEY_MACRO21        0x2a4)
(def KEY_MACRO22        0x2a5)
(def KEY_MACRO23        0x2a6)
(def KEY_MACRO24        0x2a7)
(def KEY_MACRO25        0x2a8)
(def KEY_MACRO26        0x2a9)
(def KEY_MACRO27        0x2aa)
(def KEY_MACRO28        0x2ab)
(def KEY_MACRO29        0x2ac)
(def KEY_MACRO30        0x2ad)
(def KEY_MACRO_RECORD_START 0x2b0)
(def KEY_MACRO_RECORD_STOP 0x2b1)
(def KEY_MACRO_PRESET_CYCLE 0x2b2)
(def KEY_MACRO_PRESET1  0x2b3)
(def KEY_MACRO_PRESET2  0x2b4)
(def KEY_MACRO_PRESET3  0x2b5)
(def KEY_KBD_LCD_MENU1  0x2b8)
(def KEY_KBD_LCD_MENU2  0x2b9)
(def KEY_KBD_LCD_MENU3  0x2ba)
(def KEY_KBD_LCD_MENU4  0x2bb)
(def KEY_KBD_LCD_MENU5  0x2bc)

(def BTN_TRIGGER_HAPPY  0x2c0)
(def BTN_TRIGGER_HAPPY1 0x2c0)
(def BTN_TRIGGER_HAPPY2 0x2c1)
(def BTN_TRIGGER_HAPPY3 0x2c2)
(def BTN_TRIGGER_HAPPY4 0x2c3)
(def BTN_TRIGGER_HAPPY5 0x2c4)
(def BTN_TRIGGER_HAPPY6 0x2c5)
(def BTN_TRIGGER_HAPPY7 0x2c6)
(def BTN_TRIGGER_HAPPY8 0x2c7)
(def BTN_TRIGGER_HAPPY9 0x2c8)
(def BTN_TRIGGER_HAPPY10 0x2c9)
(def BTN_TRIGGER_HAPPY11 0x2ca)
(def BTN_TRIGGER_HAPPY12 0x2cb)
(def BTN_TRIGGER_HAPPY13 0x2cc)
(def BTN_TRIGGER_HAPPY14 0x2cd)
(def BTN_TRIGGER_HAPPY15 0x2ce)
(def BTN_TRIGGER_HAPPY16 0x2cf)
(def BTN_TRIGGER_HAPPY17 0x2d0)
(def BTN_TRIGGER_HAPPY18 0x2d1)
(def BTN_TRIGGER_HAPPY19 0x2d2)
(def BTN_TRIGGER_HAPPY20 0x2d3)
(def BTN_TRIGGER_HAPPY21 0x2d4)
(def BTN_TRIGGER_HAPPY22 0x2d5)
(def BTN_TRIGGER_HAPPY23 0x2d6)
(def BTN_TRIGGER_HAPPY24 0x2d7)
(def BTN_TRIGGER_HAPPY25 0x2d8)
(def BTN_TRIGGER_HAPPY26 0x2d9)
(def BTN_TRIGGER_HAPPY27 0x2da)
(def BTN_TRIGGER_HAPPY28 0x2db)
(def BTN_TRIGGER_HAPPY29 0x2dc)
(def BTN_TRIGGER_HAPPY30 0x2dd)
(def BTN_TRIGGER_HAPPY31 0x2de)
(def BTN_TRIGGER_HAPPY32 0x2df)
(def BTN_TRIGGER_HAPPY33 0x2e0)
(def BTN_TRIGGER_HAPPY34 0x2e1)
(def BTN_TRIGGER_HAPPY35 0x2e2)
(def BTN_TRIGGER_HAPPY36 0x2e3)
(def BTN_TRIGGER_HAPPY37 0x2e4)
(def BTN_TRIGGER_HAPPY38 0x2e5)
(def BTN_TRIGGER_HAPPY39 0x2e6)
(def BTN_TRIGGER_HAPPY40 0x2e7)

(def KEY_MIN_INTERESTING KEY_MUTE)
(def KEY_MAX             0x2ff)
(def KEY_CNT             (+ 1 KEY_MAX))

######### End of Key and Button Codes #########


(def UINPUT_OPEN_MANAGED -2)


(def SYN_REPORT     0)
(def SYN_CONFIG     1)
(def SYN_MT_REPORT  2)
(def SYN_DROPPED    3)
(def SYN_MAX        0xf)
(def SYN_CNT        (+ 1 SYN_MAX))


(def EAGAIN 11)


######### Helpers #########

(defn init-virtual-keyboard [evd check]
  (call-interface 'set_name evd "Jumper Virtual Keyboard")
  
  (check (call-interface 'enable_event_type evd EV_KEY)
         "failed to enable EV_KEY")

  (for kc 0 KEY_MAX
    (check (call-interface 'enable_event_code evd EV_KEY kc nil)
           (string/format "failed to enable code %n for EV_KEY" kc)))

  (def buf (buffer/new-filled (ffi/size :ptr)))
  (check (call-interface 'uinput_create_from_device evd UINPUT_OPEN_MANAGED buf)
         "failed to create virtual keyboard device")

  (ffi/read :ptr buf))


(defn init-virtual-mouse [evd check]
  (call-interface 'set_name evd "Jumper Virtual Mouse")
  
  (check (call-interface 'enable_property evd INPUT_PROP_POINTER)
         "failed to enable INPUT_PROP_POINTER")

  (check (call-interface 'enable_event_type evd EV_REL)
         "failed to enable EV_REL")
  (check (call-interface 'enable_event_type evd EV_KEY)
         "failed to enable EV_KEY")

  (each rc [REL_X
            REL_Y
            REL_WHEEL
            REL_HWHEEL
            REL_WHEEL_HI_RES
            REL_HWHEEL_HI_RES]
    (check (call-interface 'enable_event_code evd EV_REL rc nil)
           (string/format "failed to enable code %n for EV_REL" rc)))

  (each bc [BTN_LEFT
            BTN_RIGHT
            BTN_MIDDLE
            BTN_SIDE
            BTN_EXTRA
            BTN_FORWARD
            BTN_BACK]
    (check (call-interface 'enable_event_code evd EV_KEY bc nil)
           (string/format "failed to enable code %n for EV_KEY" bc)))

  (def buf (buffer/new-filled (ffi/size :ptr)))
  (check (call-interface 'uinput_create_from_device evd UINPUT_OPEN_MANAGED buf)
         "failed to create virtual mouse device")

  (ffi/read :ptr buf))


(def DEFAULT-ABS-AXIS-MIN 0)
(def DEFAULT-ABS-AXIS-MAX 65535)

(defn init-virtual-joystick [evd check]
  (call-interface 'set_name evd "Jumper Virtual Joystick")
  
  (check (call-interface 'enable_event_type evd EV_ABS)
         "failed to enable EV_ABS")
  (check (call-interface 'enable_event_type evd EV_KEY)
         "failed to enable EV_KEY")

  (def absinfo-struct (in (get-structs) 'input_absinfo))
  (def absinfo-buf (buffer/new-filled (ffi/size absinfo-struct)))
  (for ac 0 ABS_RESERVED
    (ffi/write absinfo-struct
               [0  # value
                DEFAULT-ABS-AXIS-MIN
                DEFAULT-ABS-AXIS-MAX
                0  # fuzz
                0  # flat
                0  # resolution
               ]
               absinfo-buf
               0)
    (check (call-interface 'enable_event_code evd EV_ABS ac absinfo-buf)
           (string/format "failed to enable code %n for EV_ABS" ac)))

  (each bc [BTN_TRIGGER
            BTN_THUMB
            BTN_THUMB2
            BTN_TOP
            BTN_TOP2
            BTN_PINKIE
            BTN_BASE
            BTN_BASE2
            BTN_BASE3
            BTN_BASE4
            BTN_BASE5
            BTN_BASE6
            BTN_DEAD
            BTN_SOUTH
            BTN_A
            BTN_EAST
            BTN_B
            BTN_C
            BTN_NORTH
            BTN_X
            BTN_WEST
            BTN_Y
            BTN_Z
            BTN_TL
            BTN_TR
            BTN_TL2
            BTN_TR2
            BTN_SELECT
            BTN_START
            BTN_MODE
            BTN_THUMBL
            BTN_THUMBR]
    (check (call-interface 'enable_event_code evd EV_KEY bc nil)
           (string/format "failed to enable code %n for EV_KEY" bc)))

  (def buf (buffer/new-filled (ffi/size :ptr)))
  (check (call-interface 'uinput_create_from_device evd UINPUT_OPEN_MANAGED buf)
         "failed to create virtual mouse device")

  (ffi/read :ptr buf))


######### High-level interface #########

(def uinput-device-cache @{})


(defn create-uinput-device [dev-type]
  (with [evd
         (call-interface 'new)
         |(when $ (call-interface 'free $))]
    (when (nil? evd)
      (error "failde to create new evdev device"))

    (defn check [ret err]
      (when (< ret 0)
        (errorf (string err ": %d") ret)))

    (def uinput-dev
      (case dev-type
        :keyboard
        (init-virtual-keyboard evd check)

        :mouse
        (init-virtual-mouse evd check)

        :joystick
        (init-virtual-joystick evd check)

        (errorf "unknown device type: %n" dev-type)))

    uinput-dev))


(defn destroy-uinput-device [dev]
  (call-interface 'uinput_destroy dev))
