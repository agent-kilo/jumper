(var user32-interface nil)
(var user32-structs nil)


(def user32-signatures
  {'SendInput       [:uint32   :uint32 :ptr :int32]  # cInputs, pInputs, cbSize
   'MapVirtualKeyA  [:uint32   :uint32 :uint32]      # uCode, uMapType
  })


(defn get-user32-structs []
  (if user32-structs
    user32-structs
    (set user32-structs
         {'INPUT_KEYBD (ffi/struct
                         :uint32  # type, must be INPUT_KEYBOARD (1)
                         :uint32  # padding

                         :uint16  # wVK
                         :uint16  # wScan
                         :uint32  # dwFlags
                         :uint32  # time
                         :uint32  # padding
                         :uint64  # dwExtraInfo

                         # pad to 40 bytes
                         :uint64)})))


(defn load-user32-interface []
  (if user32-interface
    user32-interface
    (set user32-interface (ffi/native "user32.dll"))))


(defn call-user32-interface [name & args]
  (def user32-interface (load-user32-interface))
  (def sym (ffi/lookup user32-interface (string name)))
  (def sig (ffi/signature :default ;(in user32-signatures (symbol name))))
  (ffi/call sym sig ;args))


(def KEYEVENTF_EXTENDEDKEY 0x01)
(def KEYEVENTF_KEYUP       0x02)
(def KEYEVENTF_UNICODE     0x04)
(def KEYEVENTF_SCANCODE    0x08)


(def MAPVK_VK_TO_VSC 0)
(def MAPVK_VSC_TO_VK 1)
(def MAPVK_VK_TO_CHAR 2)
(def MAPVK_VSC_TO_VK_EX 3)
(def MAPVK_VK_TO_VSC_EX 4)


######### Helpers #########

(defn ascii [ascii-str]
  (in ascii-str 0))

(def key-name-to-code
  {"lwin"    0x5B
   "rwin"    0x5C
   "win"     0x5B

   "lmeta"   0x5B
   "rmeta"   0x5C
   "meta"    0x5B

   "lalt"    0xA4
   "ralt"    0xA5
   "alt"     0xA4

   "lctrl"   0xA2
   "rctrl"   0xA3
   "ctrl"    0xA2

   "lshift"  0xA0
   "rshift"  0xA1
   "shift"   0xA0

   "backspace" 0x08
   "tab"     0x09
   "enter"   0x0D
   "pause"   0x13
   "capslock" 0x14
   "esc"     0x1B
   "space"   0x20
   "pageup"  0x21
   "pagedown" 0x22
   "end"     0x23
   "home"    0x24
   "left"    0x25
   "up"      0x26
   "right"   0x27
   "down"    0x28
   "printscreen" 0x2C
   "insert"  0x2D
   "delete"  0x2E
   "app"     0x5D
   "scrolllock" 0x91

   "numlock" 0x90

   "numpad0" 0x60
   "numpad1" 0x61
   "numpad2" 0x62
   "numpad3" 0x63
   "numpad4" 0x64
   "numpad5" 0x65
   "numpad6" 0x66
   "numpad7" 0x67
   "numpad8" 0x68
   "numpad9" 0x69
   "numpad*" 0x6A
   "numpad+" 0x6B
   "numpad-" 0x6D
   "numpad." 0x6E
   "numpad/" 0x6F

   "a" (ascii "A")
   "b" (ascii "B")
   "c" (ascii "C")
   "d" (ascii "D")
   "e" (ascii "E")
   "f" (ascii "F")
   "g" (ascii "G")
   "h" (ascii "H")
   "i" (ascii "I")
   "j" (ascii "J")
   "k" (ascii "K")
   "l" (ascii "L")
   "m" (ascii "M")
   "n" (ascii "N")
   "o" (ascii "O")
   "p" (ascii "P")
   "q" (ascii "Q")
   "r" (ascii "R")
   "s" (ascii "S")
   "t" (ascii "T")
   "u" (ascii "U")
   "v" (ascii "V")
   "w" (ascii "W")
   "x" (ascii "X")
   "y" (ascii "Y")
   "z" (ascii "Z")
   "0" (ascii "0")
   "1" (ascii "1")
   "2" (ascii "2")
   "3" (ascii "3")
   "4" (ascii "4")
   "5" (ascii "5")
   "6" (ascii "6")
   "7" (ascii "7")
   "8" (ascii "8")
   "9" (ascii "9")

   "f1"  0x70
   "f2"  0x71
   "f3"  0x72
   "f4"  0x73
   "f5"  0x74
   "f6"  0x75
   "f7"  0x76
   "f8"  0x77
   "f9"  0x78
   "f10" 0x79
   "f11" 0x7A
   "f12" 0x7B
   "f13" 0x7C
   "f14" 0x7D
   "f15" 0x7E
   "f16" 0x7F
   "f17" 0x80
   "f18" 0x81
   "f19" 0x82
   "f20" 0x83
   "f21" 0x84
   "f22" 0x85
   "f23" 0x86
   "f24" 0x87

   ","   0xBC
   "."   0xBE
   "="   0xBB
   "-"   0xBD
   ";"   0xBA
   "/"   0xBF
   "`"   0xC0
   "["   0xDB
   "\\"  0xDC
   "]"   0xDD
   "'"   0xDE
  })


(def extended-vks
  {
   0xA3 true # RCtrl
   0xA5 true # RAtl
   0x2D true # Insert
   0x2E true # Delete
   0x24 true # Home
   0x23 true # End
   0x21 true # PageUp
   0x22 true # PageDown
   0x25 true # Left Arrow
   0x26 true # Up Arrow
   0x27 true # Right Arrow
   0x28 true # Down Arrow
   0x90 true # NumLock
   0x2C true # PrintScreen
   0x6F true # Numpad/
  })

(defn is-extended-vk [vk]
  (truthy? (in extended-vks vk)))


######### High-level interface #########

(defn send-keys [keys state]
  (def state-flag
    (case state
      :up   KEYEVENTF_KEYUP
      :down 0x00
      (errorf "invalid key state: %n" state)))

  (def input-struct (in (get-user32-structs) 'INPUT_KEYBD))
  (def key-count (length keys))
  (def struct-size (ffi/size input-struct))
  (def buf (buffer/new-filled (* key-count struct-size)))

  (eachp [idx k] keys
    (def vk (in key-name-to-code k))
    (def vsc (call-user32-interface 'MapVirtualKeyA vk MAPVK_VK_TO_VSC_EX))
    (def extended-flag
      (if (or (> vsc 0xff)
              (is-extended-vk vk))
        KEYEVENTF_EXTENDEDKEY
        # else
        0))
    (def flags
      (bor state-flag
           extended-flag
           KEYEVENTF_SCANCODE))
    (ffi/write input-struct
               [1      # type, INPUT_KEYBOARD
                0      # padding
                vk     # wVK
                vsc    # wScan
                flags  # dwFlags
                0      # time
                0      # padding
                0      # dwExtraInfo
                0      # padding
               ]
               buf
               (* idx struct-size)))
  (call-user32-interface 'SendInput key-count buf struct-size))
