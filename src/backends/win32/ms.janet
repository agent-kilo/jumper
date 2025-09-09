(import ../../log)


(var user32-interface nil)
(var user32-structs nil)


(def user32-signatures
  {'SendInput       [:uint32   :uint32 :ptr :int32]  # cInputs, pInputs, cbSize
  })


(defn get-user32-structs []
  (if user32-structs
    user32-structs
    (set user32-structs
         {'INPUT_MOUSE (ffi/struct
                         :uint32  # type, must be INPUT_MOUSE (0)
                         :uint32  # padding

                         :int32   # dx
                         :int32   # dy
                         :int32   # mouseData, it's in fact a uint32, but MOUSEEVENTF_WHEEL events overload it to send signed numbers
                         :uint32  # dwFlags
                         :uint32  # time
                         :uint32  # padding
                         :uint64  # dwExtraInfo
                         # 40 bytes
                         )})))


(defn load-user32-interface []
  (if user32-interface
    user32-interface
    (set user32-interface (ffi/native "user32.dll"))))


(defn call-user32-interface [name & args]
  (def user32-interface (load-user32-interface))
  (def sym (ffi/lookup user32-interface (string name)))
  (def sig (ffi/signature :default ;(in user32-signatures (symbol name))))
  (ffi/call sym sig ;args))


(def MOUSEEVENTF_MOVE        0x0001)
(def MOUSEEVENTF_LEFTDOWN    0x0002)
(def MOUSEEVENTF_LEFTUP      0x0004)
(def MOUSEEVENTF_RIGHTDOWN   0x0008)
(def MOUSEEVENTF_RIGHTUP     0x0010)
(def MOUSEEVENTF_MIDDLEDOWN  0x0020)
(def MOUSEEVENTF_MIDDLEUP    0x0040)
(def MOUSEEVENTF_XDOWN       0x0080)
(def MOUSEEVENTF_XUP         0x0100)
(def MOUSEEVENTF_WHEEL       0x0800)
(def MOUSEEVENTF_HWHEEL      0x01000)
(def MOUSEEVENTF_MOVE_NOCOALESCE 0x2000)
(def MOUSEEVENTF_VIRTUALDESK 0x4000)
(def MOUSEEVENTF_ABSOLUTE    0x8000)


######### High-level interface #########

(defn send-movement [dx dy &opt absolute? all-monitors?]
  (default absolute? false)
  (default all-monitors? false)

  (def flags (bor MOUSEEVENTF_MOVE
                  (if absolute?
                    MOUSEEVENTF_ABSOLUTE
                    0)
                  (if all-monitors?
                    MOUSEEVENTF_VIRTUALDESK
                    0)))
  (def input-struct (in (get-user32-structs) 'INPUT_MOUSE))
  (def struct-size (ffi/size input-struct))
  (def buf (buffer/new-filled struct-size))
  (ffi/write input-struct
             [0      # type, INPUT_MOUSE
              0      # padding
              dx     # dx
              dy     # dy
              0      # mouseData
              flags  # dwFlags
              0      # time
              0      # padding
              0      # dwExtraInfo
             ]
             buf
             0)
  (call-user32-interface 'SendInput 1 buf struct-size))


(defn send-button [btn-name btn-state]
  (defn check-btn-state [down-val up-val]
    (case btn-state
      :down down-val
      :up   up-val
      (errorf "invalid mouse button state: %n" btn-state)))

  (def [flags data]
    (case [btn-name btn-state]
      ["left"   :up]    [MOUSEEVENTF_LEFTUP     0]
      ["left"   :down]  [MOUSEEVENTF_LEFTDOWN   0]
      ["right"  :up]    [MOUSEEVENTF_RIGHTUP    0]
      ["right"  :down]  [MOUSEEVENTF_RIGHTDOWN  0]
      ["middle" :up]    [MOUSEEVENTF_MIDDLEUP   0]
      ["middle" :down]  [MOUSEEVENTF_MIDDLEDOWN 0]
      ["x1"     :up]    [MOUSEEVENTF_XUP        1]
      ["x1"     :down]  [MOUSEEVENTF_XDOWN      1]
      ["x2"     :up]    [MOUSEEVENTF_XUP        2]
      ["x2"     :down]  [MOUSEEVENTF_XDOWN      2]
      (errorf "invalid mouse button combination: %n"
              [btn-name btn-state])))
  (def input-struct (in (get-user32-structs) 'INPUT_MOUSE))
  (def struct-size (ffi/size input-struct))
  (def buf (buffer/new-filled struct-size))
  (ffi/write input-struct
             [0      # type, INPUT_MOUSE
              0      # padding
              0      # dx
              0      # dy
              data   # mouseData
              flags  # dwFlags
              0      # time
              0      # padding
              0      # dwExtraInfo
             ]
             buf
             0)
  (call-user32-interface 'SendInput 1 buf struct-size))


(defn send-wheel [direction &opt steps]
  (default steps 120)

  (def [flags data]
    (case direction
      "up"    [MOUSEEVENTF_WHEEL  steps]
      "down"  [MOUSEEVENTF_WHEEL  (- steps)]
      "left"  [MOUSEEVENTF_HWHEEL (- steps)]
      "right" [MOUSEEVENTF_HWHEEL steps]
      (errorf "invalid mouse wheel direction: %n" direction)))
  (def input-struct (in (get-user32-structs) 'INPUT_MOUSE))
  (def struct-size (ffi/size input-struct))
  (def buf (buffer/new-filled struct-size))
  (ffi/write input-struct
             [0      # type, INPUT_MOUSE
              0      # padding
              0      # dx
              0      # dy
              data   # mouseData
              flags  # dwFlags
              0      # time
              0      # padding
              0      # dwExtraInfo
             ]
             buf
             0)
  (call-user32-interface 'SendInput 1 buf struct-size))
