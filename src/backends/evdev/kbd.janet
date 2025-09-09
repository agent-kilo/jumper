(import ./evdev)


######### Helpers #########

(def key-name-to-code
  {"lwin"    evdev/KEY_LEFTMETA
   "rwin"    evdev/KEY_RIGHTMETA
   "win"     evdev/KEY_LEFTMETA

   "lmeta"   evdev/KEY_LEFTMETA
   "rmeta"   evdev/KEY_RIGHTMETA
   "meta"    evdev/KEY_LEFTMETA

   "lalt"    evdev/KEY_LEFTALT
   "ralt"    evdev/KEY_RIGHTALT
   "alt"     evdev/KEY_LEFTALT

   "lctrl"   evdev/KEY_LEFTCTRL
   "rctrl"   evdev/KEY_RIGHTCTRL
   "ctrl"    evdev/KEY_LEFTCTRL

   "lshift"  evdev/KEY_LEFTSHIFT
   "rshift"  evdev/KEY_RIGHTSHIFT
   "shift"   evdev/KEY_LEFTSHIFT

   "backspace" evdev/KEY_BACKSPACE
   "tab"     evdev/KEY_TAB
   "enter"   evdev/KEY_ENTER
   "pause"   evdev/KEY_PAUSE # XXX: not sure
   "capslock" evdev/KEY_CAPSLOCK
   "esc"     evdev/KEY_ESC
   "space"   evdev/KEY_SPACE
   "pageup"  evdev/KEY_PAGEUP
   "pagedown" evdev/KEY_PAGEDOWN
   "end"     evdev/KEY_END
   "home"    evdev/KEY_HOME
   "left"    evdev/KEY_LEFT
   "up"      evdev/KEY_UP
   "right"   evdev/KEY_RIGHT
   "down"    evdev/KEY_DOWN
   "printscreen" evdev/KEY_PRINT # XXX: not sure
   "insert"  evdev/KEY_INSERT
   "delete"  evdev/KEY_DELETE
   "app"     evdev/KEY_COMPOSE # XXX: not sure
   "scrolllock" evdev/KEY_SCROLLLOCK

   "numlock" evdev/KEY_NUMLOCK

   "numpad0" evdev/KEY_KP0
   "numpad1" evdev/KEY_KP1
   "numpad2" evdev/KEY_KP2
   "numpad3" evdev/KEY_KP3
   "numpad4" evdev/KEY_KP4
   "numpad5" evdev/KEY_KP5
   "numpad6" evdev/KEY_KP6
   "numpad7" evdev/KEY_KP7
   "numpad8" evdev/KEY_KP8
   "numpad9" evdev/KEY_KP9
   "numpad*" evdev/KEY_KPASTERISK
   "numpad+" evdev/KEY_KPPLUS
   "numpad-" evdev/KEY_KPMINUS
   "numpad." evdev/KEY_KPDOT
   "numpad/" evdev/KEY_KPSLASH

   "a" evdev/KEY_A
   "b" evdev/KEY_B
   "c" evdev/KEY_C
   "d" evdev/KEY_D
   "e" evdev/KEY_E
   "f" evdev/KEY_F
   "g" evdev/KEY_G
   "h" evdev/KEY_H
   "i" evdev/KEY_I
   "j" evdev/KEY_J
   "k" evdev/KEY_K
   "l" evdev/KEY_L
   "m" evdev/KEY_M
   "n" evdev/KEY_N
   "o" evdev/KEY_O
   "p" evdev/KEY_P
   "q" evdev/KEY_Q
   "r" evdev/KEY_R
   "s" evdev/KEY_S
   "t" evdev/KEY_T
   "u" evdev/KEY_U
   "v" evdev/KEY_V
   "w" evdev/KEY_W
   "x" evdev/KEY_X
   "y" evdev/KEY_Y
   "z" evdev/KEY_Z
   "0" evdev/KEY_0
   "1" evdev/KEY_1
   "2" evdev/KEY_2
   "3" evdev/KEY_3
   "4" evdev/KEY_4
   "5" evdev/KEY_5
   "6" evdev/KEY_6
   "7" evdev/KEY_7
   "8" evdev/KEY_8
   "9" evdev/KEY_9

   "f1"  evdev/KEY_F1
   "f2"  evdev/KEY_F2
   "f3"  evdev/KEY_F3
   "f4"  evdev/KEY_F4
   "f5"  evdev/KEY_F5
   "f6"  evdev/KEY_F6
   "f7"  evdev/KEY_F7
   "f8"  evdev/KEY_F8
   "f9"  evdev/KEY_F9
   "f10" evdev/KEY_F10
   "f11" evdev/KEY_F11
   "f12" evdev/KEY_F12
   "f13" evdev/KEY_F13
   "f14" evdev/KEY_F14
   "f15" evdev/KEY_F15
   "f16" evdev/KEY_F16
   "f17" evdev/KEY_F17
   "f18" evdev/KEY_F18
   "f19" evdev/KEY_F19
   "f20" evdev/KEY_F20
   "f21" evdev/KEY_F21
   "f22" evdev/KEY_F22
   "f23" evdev/KEY_F23
   "f24" evdev/KEY_F24

   ","   evdev/KEY_COMMA
   "."   evdev/KEY_DOT
   "="   evdev/KEY_EQUAL
   "-"   evdev/KEY_MINUS
   ";"   evdev/KEY_SEMICOLON
   "/"   evdev/KEY_SLASH
   "`"   evdev/KEY_GRAVE
   "["   evdev/KEY_LEFTBRACE # XXX: not sure
   "\\"  evdev/KEY_BACKSLASH
   "]"   evdev/KEY_RIGHTBRACE # XXX: not sure
   "'"   evdev/KEY_APOSTROPHE
  })


(defn write-event-and-sync [dev ev-type code value]
  (evdev/call-interface 'uinput_write_event dev ev-type code value)
  (evdev/call-interface 'uinput_write_event dev evdev/EV_SYN evdev/SYN_REPORT 0))


(var kbd-dev nil)

(defn get-device []
  (if kbd-dev
    kbd-dev
    (set kbd-dev (evdev/create-uinput-device :keyboard))))


######### High-level interface #########

(defn send-keys [keys state]
  (def state-val
    (case state
      :up   0
      :down 1
      (errorf "invalid key state: %n" state)))

  (def dev (get-device))
  (each kn keys
    (write-event-and-sync dev evdev/EV_KEY (in key-name-to-code kn) state-val)))
