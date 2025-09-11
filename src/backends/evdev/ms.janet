(import ./evdev)


(def ABS-X-MIN evdev/MOUSE-ABS-X-MIN)
(def ABS-X-MAX evdev/MOUSE-ABS-X-MAX)
(def ABS-Y-MIN evdev/MOUSE-ABS-Y-MIN)
(def ABS-Y-MAX evdev/MOUSE-ABS-Y-MAX)


(def BTN-NAME-TO-CODE
  {"left"    evdev/BTN_LEFT
   "right"   evdev/BTN_RIGHT
   "middle"  evdev/BTN_MIDDLE
   "side"    evdev/BTN_SIDE
   "x1"      evdev/BTN_SIDE
   "extra"   evdev/BTN_EXTRA
   "x2"      evdev/BTN_EXTRA
   "forward" evdev/BTN_FORWARD
   "back"    evdev/BTN_BACK
  })


(def WHEEL-STEPS-UNIT 120)


(var ms-dev nil)

(defn get-device []
  (if ms-dev
    ms-dev
    (set ms-dev (evdev/create-uinput-device :mouse))))


(defn write-event-and-sync [dev ev-type code value]
  (evdev/call-interface 'uinput_write_event dev ev-type code value)
  (evdev/call-interface 'uinput_write_event dev evdev/EV_SYN evdev/SYN_REPORT 0))


(defn send-movement [dx dy &opt absolute? all-monitors?]
  (default absolute? false)
  (default all-monitors? false)

  (def [ev-type ev-code-x ev-code-y]
    (if absolute?
      [evdev/EV_ABS evdev/ABS_X evdev/ABS_Y]
      # else
      [evdev/EV_REL evdev/REL_X evdev/REL_Y]))

  (def dev (get-device))
  (write-event-and-sync dev ev-type ev-code-x dx)
  (write-event-and-sync dev ev-type ev-code-y dy))


(defn send-button [btn-name btn-state]
  (if-let [bc (in BTN-NAME-TO-CODE btn-name)]
    (do
      (def state
        (case btn-state
          :up   0
          :down 1
          (errorf "invalid button state: %n" btn-state)))
      (def dev (get-device))
      (write-event-and-sync dev evdev/EV_KEY bc state))
    # else
    (errorf "invalid mouse button: %n" btn-name)))


(defn send-wheel [direction &opt steps]
  (default steps WHEEL-STEPS-UNIT)

  (def [rel-code val-dir]
    (case direction
      "up"    [evdev/REL_WHEEL_HI_RES  1]
      "down"  [evdev/REL_WHEEL_HI_RES  -1]
      "left"  [evdev/REL_HWHEEL_HI_RES 1]
      "right" [evdev/REL_HWHEEL_HI_RES -1]
      (errorf "invalid mouse wheel direction: %n" direction)))

  (def dev (get-device))
  (def [n r]
    [(div steps WHEEL-STEPS-UNIT)
     (mod steps WHEEL-STEPS-UNIT)])
  (repeat n
    (write-event-and-sync dev evdev/EV_REL rel-code (* val-dir WHEEL-STEPS-UNIT)))
  (write-event-and-sync dev evdev/EV_REL rel-code (* val-dir r)))
