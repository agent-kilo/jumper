(import spork/json)
(import spork/argparse)
(import spork/infix)

(import ./backends/vjoy)
(import ./backends/kbd)
(import ./backends/ms)
(import ./resource)
(import ./log)


(def DEFAULT-CONFIG-FILE-PATH "jumper-config.janet")


(def JUMPER-VERSION
  [resource/VERSION_MAJOR
   resource/VERSION_MINOR
   resource/VERSION_PATCH
   resource/VERSION_VCS])


(def json-decode-error-peg
  (peg/compile
   ~{:position :d+
     :header (sequence "decode error at position" :s+ (replace (capture :position) ,scan-number))
     :err-msg (capture (some 1))
     :main (sequence :header :s* ":" :s* :err-msg -1)}))


(defn decode-json-values [buf &opt ret-arr]
  (default ret-arr @[])

  (log/debug "decoding: %n" buf)

  (def [val remaining-buf]
    (try
      (let [v (json/decode buf)]
        [v nil])
      ((err fib)
       (def matched
         (when (string? err)
           (peg/match json-decode-error-peg err)))
       (if matched
         (let [[idx msg] matched]
           (cond
             (= msg "unexpected extra token")
             [(json/decode (buffer/slice buf 0 idx)) (buffer/slice buf idx)]

             (= idx (length buf))
             # XXX: Assume the JSON string is incomplete
             [nil buf]

             (and (= msg "unexpected character")
                  (= (in `"` 0) (in buf idx)))
             # XXX: Incomplete string literal
             [nil buf]

             (and (= msg "bad number")
                  (= (+ 1 idx) (length buf))
                  (= 45 (in buf idx))) # 45 is ASCII '-'
             # XXX: Incomplete number literal
             [nil buf]

             true
             (propagate err fib)))
         # else
         (propagate err fib)))))

  (if val
    (do
      (array/push ret-arr val)
      (if remaining-buf
        (decode-json-values remaining-buf ret-arr)
        # else
        [ret-arr nil]))
    # else
    [ret-arr remaining-buf]))


(def DEFAULT-MOUSE-REL-STEPS 1000)
(def DEFAULT-MOUSE-ABS-SCALE (math/sqrt 2))
(def DEFAULT-MOUSE-TRACK-STEPS 1000)
(def MOUSE-TRACK-STEPS-ADJUSTMENT 0.5)

# States for joystick "trackball" mode
(var ms-track-last-x 0)
(var ms-track-last-y 0)


(defn do-ms-rel [x y steps]
  (ms/start-relative-movement (* x steps) (* (- y) steps)))


(defn do-ms-abs [x y scale]
  (def mouse-x (max ms/ABS-X-MIN
                    (min ms/ABS-X-MAX
                         (math/round (+ ms/ABS-X-MIN
                                        (* (- ms/ABS-X-MAX ms/ABS-X-MIN)
                                           (/ (+ (* x scale) 1) 2)))))))
  (def mouse-y (max ms/ABS-Y-MIN
                    (min ms/ABS-Y-MAX
                         (math/round (+ ms/ABS-Y-MIN
                                        (* (- ms/ABS-Y-MAX ms/ABS-Y-MIN)
                                           (/ (+ (- (* y scale)) 1) 2)))))))
  (ms/send-movement mouse-x mouse-y true true))


(defn do-ms-track [x y steps]
  # XXX: This abuses the fact that DroidPad joysticks are "virtual": they
  # immediately snap back to (0, 0) when released. The code wouldn't work
  # if they emulated real joysticks and emitted intermediate coordinates
  # when moving back to the center.
  (unless (and (= x 0) (= y 0))
    (ms/send-movement (math/round (* (- x ms-track-last-x)
                                     steps
                                     MOUSE-TRACK-STEPS-ADJUSTMENT))
                      (math/round (* -1
                                     (- y ms-track-last-y)
                                     steps
                                     MOUSE-TRACK-STEPS-ADJUSTMENT))))
  (set ms-track-last-x x)
  (set ms-track-last-y y))


(defn handle-default-joystick [msg matched route]
  (def matched-id (in matched :id))
  (def
    {"x" x
     "y" y}
    msg)

  (match matched-id
    ["ms" "rel" rel-steps]
    (do-ms-rel x y rel-steps)

    ["ms" "rel"]
    (do-ms-rel x y DEFAULT-MOUSE-REL-STEPS)

    ["ms" "abs" abs-scale]
    (do-ms-abs x y abs-scale)

    ["ms" "abs"]
    (do-ms-abs x y DEFAULT-MOUSE-ABS-SCALE)

    ["ms" "track" track-steps]
    (do-ms-track x y track-steps)

    ["ms" "track"]
    (do-ms-track x y DEFAULT-MOUSE-TRACK-STEPS)

    ["ms"]
    (do-ms-rel x y DEFAULT-MOUSE-REL-STEPS)

    ["vjoy" dev-id "axes" ax ay]
    (do
      (def dev (vjoy/get-device dev-id))
      (def vjx
        (unless (= ax :none)
          (def [ax-min ax-max] (get-in dev [:controls :axes ax]))
          (def ax-half-range (math/floor (/ (- ax-max ax-min) 2)))
          (def ax-middle-point (math/round (/ (+ ax-max ax-min) 2)))
          (math/round (+ ax-middle-point (* x ax-half-range)))))
      (def vjy
        (unless (= ay :none)
          (def [ay-min ay-max] (get-in dev [:controls :axes ay]))
          (def ay-half-range (math/floor (/ (- ay-max ay-min) 2)))
          (def ay-middle-point (math/round (/ (+ ay-max ay-min) 2)))
          (math/round (+ ay-middle-point (* y ay-half-range)))))
      (when vjx
        (vjoy/set-axis dev ax vjx))
      (when vjy
        (vjoy/set-axis dev ay vjy))
      (vjoy/update dev))

    ["vjoy" dev-id "pov" pov-id]
    (do
      (def dev (vjoy/get-device dev-id))
      (def ds (+ (* x x) (* y y)))
      (if (>= ds 0.04)  # d >= 0.2
        (do
          (def a (* 180 (/ (math/atan (/ x y)) math/pi)))
          (def pov-angle
            (cond
              (> y 0)
              (if (>= a 0)
                a
                (+ a 360))

              (< y 0)
              (+ a 180)

              (= y 0)
              (if (> x 0)
                90
                270)))
          (log/debug "pov-angle = %n" pov-angle)
          (vjoy/set-continuous-pov dev pov-id (math/round (* 100 pov-angle))))
        # else, in neutral position
        (vjoy/set-continuous-pov dev pov-id :neutral))
      (vjoy/update dev))

    (errorf "invalid parsed joystick id: %n" matched-id)))


(defn handle-default-slider [msg matched route]
  (def matched-id (in matched :id))
  (match matched-id
    ["vjoy" dev-id "axis" aslider]
    (do
      (def dev (vjoy/get-device dev-id))
      (def [a-min a-max] (get-in dev [:controls :axes aslider]))
      (def [s-min s-max] (in route :range [0 10]))
      (def a-range (- a-max a-min))
      (def s-range (- s-max s-min))
      (def vjval
        (max a-min
             (min a-max
                  (math/round (+ a-min (* a-range (/ (- (in msg "value") s-min) s-range)))))))
      (vjoy/set-axis dev aslider vjval)
      (vjoy/update dev))

    (errorf "invalid parsed slider id: %n" matched-id)))


(defn handle-default-button-and-switch [msg matched route]
  (def matched-id (in matched :id))
  (def btn-state
    (case (in msg "type")
      "BUTTON"
      (case (in msg "state")
        "PRESS"   :press
        "RELEASE" :release
        "CLICK"   :click
        (errorf "unknown button state: %n" (in msg "state")))

      "SWITCH"
      (case (in msg "state")
        true  :press
        false :release
        (errorf "unknown switch state: %n" (in msg "state")))

      (errorf "unknown control type: %n" (in msg "type"))))

  (match matched-id
    ["kbd" key]
    (case btn-state
      :press
      (kbd/send-keys key :down)

      :release
      (kbd/send-keys (reverse key) :up)

      :click
      (do
        (kbd/send-keys key :down)
        (kbd/send-keys (reverse key) :up)))

    ["ms" "btn" btn-name]
    (case btn-state
      :press
      (ms/send-button btn-name :down)

      :release
      (ms/send-button btn-name :up)

      :click
      (do
        (ms/send-button btn-name :down)
        (ms/send-button btn-name :up)))

    ["ms" "wheel" wheel-dir wheel-steps]
    (case btn-state
      :press
      (ms/send-wheel wheel-dir wheel-steps)

      :click
      (ms/send-wheel wheel-dir wheel-steps))

    ["ms" "wheel" wheel-dir]
    (case btn-state
      :press
      (ms/send-wheel wheel-dir)

      :click
      (ms/send-wheel wheel-dir))

    ["vjoy" dev-id "btn" btn-id]
    (do
      (def dev (vjoy/get-device dev-id))
      (case btn-state
        :press
        (do
          (vjoy/set-button dev btn-id true)
          (vjoy/update dev))

        :release
        (do
          (vjoy/set-button dev btn-id false)
          (vjoy/update dev))

        :click
        (do
          (vjoy/set-button dev btn-id true)
          (vjoy/update dev)
          (vjoy/set-button dev btn-id false)
          (vjoy/update dev))))

    (errorf "invalid parsed button or switch id: %n" matched-id)))


(defn handle-default-dpad [msg matched route]
  (def matched-id (in matched :id))
  (match matched-id
    ["vjoy" dev-id "pov" pov-id]
    (do
      (def dev (vjoy/get-device dev-id))
      (case (in msg "state")
        "PRESS"
        (do
          (def dir
            (case (in msg "button")
              "UP"    :north
              "RIGHT" :east
              "DOWN"  :south
              "LEFT"  :west
              (errorf "unknown pov button: %n" (in msg "button"))))
          (vjoy/set-discrete-pov dev pov-id dir))

        "RELEASE"
        (vjoy/set-discrete-pov dev pov-id :neutral)

        (errorf "unknown dpad button state: %n" (in msg "state")))
      (vjoy/update dev))

    ["vjoy" dev-id "btn" & btns]
    (do
      (def msg-button (in msg "button"))
      (def btn-idx
        (find-index |(= $ msg-button) ["UP" "RIGHT" "DOWN" "LEFT"]))
      (def btn (get-in btns [btn-idx]))
      (unless (nil? btn)
        (def btn-state
          (case (in msg "state")
            "PRESS"   true
            "RELEASE" false
            (errorf "unknown dpad button state: %n" (in msg "state"))))
        (def dev (vjoy/get-device dev-id))
        (vjoy/set-button dev btn btn-state)
        (vjoy/update dev)))

    ["kbd" & keys]
    (do
      (def msg-button (in msg "button"))
      (def key-idx
        (find-index |(= $ msg-button) ["UP" "RIGHT" "DOWN" "LEFT"]))
      (def key (get-in keys [key-idx]))
      (unless (nil? key)
        (case (in msg "state")
          "PRESS"   (kbd/send-keys key :down)
          "RELEASE" (kbd/send-keys (reverse key) :up)
          (errorf "unknown dpad button state: %n" (in msg "state")))))

    (errorf "invalid parsed button or switch id: %n" matched-id)))


(defn handle-default-steering-wheel [msg matched route]
  (def matched-id (in matched :id))
  (match matched-id
    ["vjoy" dev-id "axis" awheel]
    (do
      (def dev (vjoy/get-device dev-id))
      (def [a-min a-max] (get-in dev [:controls :axes awheel]))
      (def [w-min w-max] (in route :range [-360 360]))
      (def a-range (- a-max a-min))
      (def s-range (- w-max w-min))
      (def vjval
        (max a-min
             (min a-max
                  (math/round (+ a-min (* a-range (/ (- (in msg "angle") w-min) s-range)))))))
      (vjoy/set-axis dev awheel vjval)
      (vjoy/update dev))

    (errorf "invalid parsed slider id: %n" matched-id)))


(defn make-simple-moving-average-filter [k fields]
  (def points @[])

  (fn simple-moving-average [msg]
    (array/push points msg)
    (def point-count (length points))
    (when (> point-count k)
      (array/remove points 0 (- point-count k)))
    (def new-count (length points))

    (def sum-msg (table/clone msg))
    # Reset fields to zeros
    (reduce |(put $0 $1 0) sum-msg fields)
    # Calculate sums for each field
    (reduce
      (fn [sum m]
        (reduce |(put $0 $1 (+ (in $0 $1) (in m $1))) sum fields))
      sum-msg
      points)
    # Calculate average values for each field
    (reduce |(put $0 $1 (/ (in $0 $1) new-count)) sum-msg fields)

    sum-msg))


(def axis-names
  ["none" ;(map string (keys vjoy/axis-name-to-id))])


(def default-joystick-id-peg
  # ID formats:
  #   ms               (map to relative mouse movement)
  #   ms:rel:10        (map to relative mouse movement, with speed 10)
  #   ms:abs:1.4       (map to absolute mouse movement, with scale 1.4)
  #   ms:track:100     (map to "trackball" mode, with speed 100)
  #   vjoy:1:axes:x,y  (map to first vjoy device, axes X and Y)
  #   vjoy:1:pov:1     (map to first vjoy device, first continuous pov hat)
  (peg/compile
   ~{:mouse-prefix "ms"
     :vjoy-prefix  "vjoy"
     :mouse-rel-steps (replace (capture :d+) ,scan-number)
     :mouse-rel (sequence (capture "rel") (opt (sequence ":" :mouse-rel-steps)))
     :mouse-abs-scale (replace (capture (choice (sequence :d+ (opt (sequence "." :d+)))
                                                (sequence "." :d+))) ,scan-number)
     :mouse-abs (sequence (capture "abs") (opt (sequence ":" :mouse-abs-scale)))
     :mouse-track-steps (replace (capture :d+) ,scan-number)
     :mouse-track (sequence (capture "track") (opt (sequence ":" :mouse-track-steps)))
     :mouse-id (sequence (capture :mouse-prefix)
                         (opt (sequence ":" (choice :mouse-rel :mouse-abs :mouse-track))))
     :axis-name (choice ,;axis-names)
     :vjoy-axes (sequence (capture "axes")
                          ":"
                          (replace (capture :axis-name) ,keyword)
                          ","
                          (replace (capture :axis-name) ,keyword))
     :vjoy-pov (sequence (capture "pov")
                         ":"
                         (replace (capture :d+) ,scan-number))
     :vjoy-id  (sequence (capture :vjoy-prefix)
                         ":"
                         (replace (capture :d+) ,scan-number)
                         ":"
                         (choice :vjoy-axes :vjoy-pov))
     :main (sequence (choice :mouse-id :vjoy-id) -1)}))


(def default-slider-id-peg
  # ID formats:
  #   vjoy:1:axis:slider0  (map to first vjoy device, axis slider0)
  (peg/compile
   ~{:vjoy-prefix  "vjoy"
     # The first axis name is "none", which is not allowed here
     :axis-name (choice ,;(slice axis-names 1))
     :vjoy-axes (sequence (capture "axis")
                          ":"
                          (replace (capture :axis-name) ,keyword))
     :vjoy-id  (sequence (capture :vjoy-prefix)
                         ":"
                         (replace (capture :d+) ,scan-number)
                         ":"
                         :vjoy-axes)
     :main (sequence :vjoy-id -1)}))


(def default-button-id-peg
  # ID formats:
  #   kbd:ctrl+c      (map to Ctrl+C key combo)
  #   ms:btn:left     (map to left mouse button)
  #   ms:wheel:up:120 (map to moving mouse wheel up, with speed 120)
  #   vjoy:1:btn:1    (map to first vjoy device, first button)
  #   vjoy:1:btn:trigger  (map to first vjoy device, "trigger" button)
  (peg/compile
   ~{:kbd-prefix "kbd"
     :kbd-trigger-key (capture (some 1))
     :kbd-modifier (sequence (capture (some (if-not "+" 1))) "+")
     :kbd-combo (group (sequence (any :kbd-modifier) :kbd-trigger-key))
     :kbd-id (sequence (capture :kbd-prefix)
                       ":"
                       :kbd-combo)
     :ms-prefix "ms"
     :ms-btn (sequence (capture "btn")
                       ":"
                       (capture (some (if-not ":" 1))))
     :ms-wheel-steps (replace (capture :d+) ,scan-number)
     :ms-wheel-dir (capture (some (if-not ":" 1)))
     :ms-wheel (sequence (capture "wheel")
                         ":"
                         :ms-wheel-dir
                         (opt (sequence ":" :ms-wheel-steps)))
     :ms-id (sequence (capture :ms-prefix)
                      ":"
                      (choice :ms-btn :ms-wheel))
     :vjoy-prefix "vjoy"
     :vjoy-id (sequence (capture :vjoy-prefix)
                        ":"
                        (replace (capture :d+) ,scan-number)
                        ":"
                        (capture "btn")
                        ":"
                        (choice
                         (replace (capture :d+) ,scan-number)
                         (replace (capture (some (if-not ":" 1))) ,keyword)))
     :main (sequence (choice :kbd-id :ms-id :vjoy-id) -1)}))


(def default-dpad-id-peg
  # ID formats:
  #   vjoy:1:pov:1        (map to first vjoy device, first pov hat)
  #   vjoy:1:btn:1,2,3,4  (map to buttons of first vjoy device, starting from north, in clockwise order)
  #   kbd:ctrl+c,ctrl+v,none,ctrl+x  (map to key combos, starting from north, in clockwise order)
  (peg/compile
   ~{:vjoy-prefix "vjoy"
     :vjoy-pov (sequence (capture "pov")
                         ":"
                         (replace (capture :d+) ,scan-number))
     :vjoy-btn-id (choice
                   (replace (capture :d+) ,scan-number)
                   (replace (capture (some (if-not (choice ":" ",") 1))) ,keyword))
     :vjoy-btn (sequence (capture "btn") ":" (any (sequence :vjoy-btn-id ",")) :vjoy-btn-id)
     :vjoy-id (sequence (capture :vjoy-prefix)
                        ":"
                        (replace (capture :d+) ,scan-number)
                        ":"
                        (choice :vjoy-pov :vjoy-btn))
     :kbd-prefix "kbd"
     :kbd-trigger-key (capture (choice "," (some (if-not "," 1))))
     :kbd-modifier (sequence (capture (some (if-not (choice "+" ",") 1))) "+")
     :kbd-combo (group (sequence (any :kbd-modifier) :kbd-trigger-key))
     :kbd-id (sequence (capture :kbd-prefix)
                       ":"
                       (any (sequence :kbd-combo ","))
                       :kbd-combo)
     :main (sequence (choice :vjoy-id :kbd-id) -1)}))


(def default-routes
  @[
    @{:type "JOYSTICK"
      :id default-joystick-id-peg
      :handler handle-default-joystick}

    @{:type "SLIDER"
      :id default-slider-id-peg
      :handler handle-default-slider}

    @{:type "BUTTON"
      :id default-button-id-peg
      :handler handle-default-button-and-switch}

    @{:type "SWITCH"
      :id default-button-id-peg
      :handler handle-default-button-and-switch}

    @{:type "DPAD"
      :id default-dpad-id-peg
      :handler handle-default-dpad}

    @{:type "STEERING_WHEEL"
      :id default-slider-id-peg
      :handler handle-default-steering-wheel}
   ])


(defn match-route-property [route-prop ctrl-prop]
  (log/debug "matching: route-prop = %n, ctrl-prop = %n"
             route-prop ctrl-prop)
  (cond
    (or (keyword? route-prop)
        (string? route-prop)
        (number? route-prop))
    (when (= route-prop ctrl-prop)
      ctrl-prop)

    true
    (peg/match route-prop (string ctrl-prop))))


(def ROUTE-MATCH-FIELDS [:type :id])

(defn match-route [route msg]
  (def match-results @{})
  (var result true)

  (eachp [k v] route
    (when (find |(= $ k) ROUTE-MATCH-FIELDS)
      (def matched (match-route-property v (in msg (string k))))
      (unless matched
        # out of eachp
        (set result false)
        (break))
      (put match-results k matched)))

  (when result
    match-results))


(defn dispatch-dp-message [msg routes]
  (var matched nil)
  (var matched-route nil)
  (each r routes
    (set matched (match-route r msg))
    (when matched
      (set matched-route r)
      # out of each loop
      (break)))
  (if matched-route
    (do
      (def handler (in matched-route :handler))
      (def filters (in matched-route :filters []))
      (handler (reduce |($1 $0) msg filters) matched matched-route)
      true)
    # else, no match
    false))


(def known-peers @{})


(defn broadcast-stream [my-peer include-my-peer? buf]
  (log/debug "my-peer = %n" my-peer)
  (eachp [peer peer-conn] known-peers
    (log/debug "peer = %n" peer)
    (when (or include-my-peer?
              (not= peer my-peer))
      (log/debug "broadcasting to %n" peer)
      (ev/write peer-conn buf))))


(defn broadcast-datagram [my-peer include-my-peer? conn buf]
  (log/debug "my-peer = %n" my-peer)
  (eachp [peer peer-addr] known-peers
    (log/debug "peer = %n" peer)
    (when (or include-my-peer?
              (not= peer my-peer))
      (log/debug "broadcasting to %n" peer)
      (net/send-to conn peer-addr buf))))


(defdyn *send-fn*)
(defdyn *broadcast-fn*)


(defn handle-connection [conn dispatch on-connection]
  (def peer (net/peername conn))
  (log/debug "= NEW CONNECTION from %n =" peer)

  (def send-fn      |(ev/write conn $))
  (def broadcast-fn |(broadcast-stream peer $1 $0))

  (put known-peers peer conn)
  (when on-connection
    (with-dyns [*send-fn*      send-fn
                *broadcast-fn* broadcast-fn]
      (on-connection)))

  (var buf @"")
  (while (ev/read conn 4096 buf)
    (log/debug "---- after read ----")
    (def [decoded remaining-buf]
      (decode-json-values buf))

    (log/debug "decoded = %n" decoded)
    (log/debug "remaining-buf = %n" remaining-buf)

    (with-dyns [*send-fn*      send-fn
                *broadcast-fn* broadcast-fn]
      (each v decoded
        (dispatch v)))

    (if remaining-buf
      (set buf remaining-buf)
      # else
      (buffer/clear buf))
    (log/debug "---- before read ----"))

  (put known-peers peer nil)
  (log/debug "= CONNECTION from %n CLOSED =" peer))


(defn handle-datagram-messages [conn dispatch on-connection]
  (var buf @"")
  (forever
    (def peer-addr (net/recv-from conn 4096 buf))
    (def peer (net/address-unpack peer-addr))

    (def send-fn      |(net/send-to conn peer-addr $))
    (def broadcast-fn |(broadcast-datagram peer $1 conn $0))

    (unless (has-key? known-peers peer)
      (put known-peers peer peer-addr)
      (when on-connection
        (with-dyns [*send-fn*      send-fn
                    *broadcast-fn* broadcast-fn]
          (on-connection))))

    (log/debug "---- after read ----")
    (def [decoded remaining-buf]
      (decode-json-values buf))

    (log/debug "decoded = %n" decoded)
    (log/debug "remaining-buf = %n" remaining-buf)

    (with-dyns [*send-fn*      send-fn
                *broadcast-fn* broadcast-fn]
      (each v decoded
        (dispatch v)))

    (if remaining-buf
      (set buf remaining-buf)
      # else
      (buffer/clear buf))
    (log/debug "---- before read ----")))


(defn send [data]
  (def encoded (buffer/push (json/encode data) "\n"))
  (log/debug "sending encoded = %n" encoded)
  ((dyn *send-fn*) encoded))


(defn send-switch [id state]
  (send {"id"    id
         "type"  "SWITCH"
         "state" (truthy? state)}))


(defn send-slider [id value]
  (send {"id"    id
         "type"  "SLIDER"
         "value" value}))


(defn send-led [id state]
  (send {"id"    id
         "type"  "LED"
         "state" (string/ascii-upper (string state))}))


(defn send-gauge [id value]
  (send {"id"    id
         "type"  "GAUGE"
         "value" value}))


(defn send-log [msg]
  (send {"type"    "LOG"
         "message" msg}))


(defn broadcast [data &opt include-my-peer?]
  (default include-my-peer? true)
  (def encoded (buffer/push (json/encode data) "\n"))
  (log/debug "broadcasting encoded = %n" encoded)
  ((dyn *broadcast-fn*) encoded include-my-peer?))


(defn broadcast-switch [id state &opt include-my-peer?]
  (broadcast {"id"    id
              "type"  "SWITCH"
              "state" (truthy? state)}
             include-my-peer?))


(defn broadcast-slider [id value &opt include-my-peer?]
  (broadcast {"id"    id
              "type"  "SLIDER"
              "value" value}
             include-my-peer?))


(defn broadcast-led [id state &opt include-my-peer?]
  (broadcast {"id"    id
              "type"  "LED"
              "state" (string/ascii-upper (string state))}
             include-my-peer?))


(defn broadcast-gauge [id value &opt include-my-peer?]
  (broadcast {"id"    id
              "type"  "GAUGE"
              "value" value}
             include-my-peer?))


(defn broadcast-log [msg &opt include-my-peer?]
  (broadcast {"type"    "LOG"
              "message" msg}
             include-my-peer?))


(def server-address-peg
  (peg/compile
   ~{:ip-seg (choice
              (sequence "25" (range "05"))
              (sequence "2" (range "04") :d)
              (sequence "1" :d :d)
              (sequence :d :d)
              (sequence :d))
     :ip (sequence :ip-seg "." :ip-seg "." :ip-seg "." :ip-seg)
     :ip-capture (capture :ip)
     :port (sequence
            (any "0")
            (choice
             (sequence "6553" (range "05"))
             (sequence "655" (range "02") :d)
             (sequence "65" (range "04") :d :d)
             (sequence "6" (range "04") :d :d :d)
             (sequence (range "05") :d :d :d :d)
             (between 2 4 :d)
             (range "19")))
     :port-capture (replace (capture :port) ,parse)
     :main (sequence :ip-capture ":" :port-capture -1)}))


(defn parse-command-line []
  (argparse/argparse
   "Jumper: A server converting DroidPad inputs to vJoy/keyboard/mouse events."

   :default
   {:help (string "The config file to load. Default: " DEFAULT-CONFIG-FILE-PATH)
    :kind :accumulate}

   "server-address"
   {:short "a"
    :help "The address (<ip>:<port>) the server should be listening on. Default: 0.0.0.0:9876"
    :kind :option
    :map (fn [addr-str]
           (if-let [addr (peg/match server-address-peg addr-str)]
             addr
             (errorf "malformed server address: %n" addr-str)))}

   "server-type"
   {:short "t"
    :help "Can be udp or tcp. Default: udp"
    :kind :option
    :map keyword}

   "log-level"
   {:short "l"
    :help "The log level. Can be quiet, error, warning, info or debug. Default: info"
    :kind :option
    :map keyword}
   ))


(def EXPORTED-TO-CONFIG-ENV
  @{'$$                                        (dyn 'infix/$$)

    'jumper/version                            @{:value JUMPER-VERSION
                                                 :doc "Current Jumper version.\n"}
    'jumper/make-simple-moving-average-filter  (dyn 'make-simple-moving-average-filter)
    'jumper/default-routes                     (dyn 'default-routes)
    'jumper/send                               (dyn 'send)
    'jumper/send-switch                        (dyn 'send-switch)
    'jumper/send-slider                        (dyn 'send-slider)
    'jumper/send-led                           (dyn 'send-led)
    'jumper/send-gauge                         (dyn 'send-gauge)
    'jumper/send-log                           (dyn 'send-log)
    'jumper/broadcast                          (dyn 'broadcast)
    'jumper/broadcast-switch                   (dyn 'broadcast-switch)
    'jumper/broadcast-slider                   (dyn 'broadcast-slider)
    'jumper/broadcast-led                      (dyn 'broadcast-led)
    'jumper/broadcast-gauge                    (dyn 'broadcast-gauge)
    'jumper/broadcast-log                      (dyn 'broadcast-log)

    'vjoy/update                               (dyn 'vjoy/update)
    'vjoy/reset                                (dyn 'vjoy/reset)
    'vjoy/acquire                              (dyn 'vjoy/acquire)
    'vjoy/relinquish                           (dyn 'vjoy/relinquish)
    'vjoy/set-button                           (dyn 'vjoy/set-button)
    'vjoy/set-axis                             (dyn 'vjoy/set-axis)
    'vjoy/set-discrete-pov                     (dyn 'vjoy/set-discrete-pov)
    'vjoy/set-continuous-pov                   (dyn 'vjoy/set-continuous-pov)
    'vjoy/get-device                           (dyn 'vjoy/get-device)

    'kbd/send-keys                             (dyn 'kbd/send-keys)

    'ms/send-movement                          (dyn 'ms/send-movement)
    'ms/send-button                            (dyn 'ms/send-button)
    'ms/send-wheel                             (dyn 'ms/send-wheel)
    'ms/start-relative-movement                (dyn 'ms/start-relative-movement)
    'ms/stop-relative-movement                 (dyn 'ms/stop-relative-movement)

    'log/get-level                             (dyn 'log/get-level)
    'log/set-level                             (dyn 'log/set-level)
    'log/debug                                 (dyn 'log/debug)
    'log/info                                  (dyn 'log/info)
    'log/warning                               (dyn 'log/warning)
    'log/error                                 (dyn 'log/error)
   })


(defn load-config [paths default-path]
  # This was a top-level `(table/setproto EXPORTED-TO-CONFIG-ENV root-env)`,
  # but our extra bindings were not accessible by modules imported by the
  # config file. So here we directly merge them into the root env instead.
  (merge-into root-env EXPORTED-TO-CONFIG-ENV)
  (def env (make-env root-env))

  (if paths
    (each p paths
      (def conf-env (dofile p :source p :env (make-env env)))
      (merge-into env conf-env))
    # else
    (do
      (def default-path-found
        (try
          (with [_config-file (os/open default-path :r)]
            default-path)
          ((_err _fib) nil)))
      (when default-path-found
        (merge-into env
                    (dofile default-path-found
                            :source default-path-found
                            :env (make-env env))))))
  env)


(defn get-binding-value [env name]
  (when-let [binding (in env name)]
    (or (in binding :value)
        (get-in binding [:ref 0]))))


(defn merge-config [config cli-args]
  (def merged @{})
  (merge-into merged config)

  (def options
    [:server-address
     :server-type
     :log-level])
  # Command line options override values in the config file
  (each op options
    (when-let [val (in cli-args (string op))]
      (put merged op val)))

  merged)


(defn start-udp-server [ip port dispatch on-connection]
  (def server (net/listen ip port :datagram))
  (handle-datagram-messages server dispatch on-connection))


(defn main [& _args]
  (def cli-args (parse-command-line))
  (unless cli-args
    (break 1))

  #
  # Init log level before loading the config, so that the
  # config script can write logs.
  #
  (def log-level (in cli-args "log-level"))
  (unless (nil? log-level)
    (log/set-level log-level))
  (log/info "Log level set to %n" (log/get-level))

  (def conf-paths (in cli-args :default))
  (def conf-env
    (load-config conf-paths DEFAULT-CONFIG-FILE-PATH))
  (def config
    (if-let [conf (get-binding-value conf-env 'jumper-config)]
      conf
      # else
      {}))

  (def merged-config (merge-config config cli-args))
  (log/debug "merged-config = %n" merged-config)

  #
  # config: log-level
  #
  (when-let [log-level (in merged-config :log-level)]
    (log/set-level log-level))
  (log/info "Log level set to %n" (log/get-level))

  #
  # config: user-routes
  #
  (def dispatch-fn
    (if-let [user-routes (in merged-config :user-routes)]
      |(unless (dispatch-dp-message $ user-routes)
         (dispatch-dp-message $ default-routes))
      # else
      |(dispatch-dp-message $ default-routes)))

  #
  # config: on-connection
  #
  (def on-connection-fn (in merged-config :on-connection))

  #
  # config: server-address
  #
  (def server-address
    (if-let [address (in merged-config :server-address)]
      address
      ["0.0.0.0" 9876]))

  #
  # config: server-type
  #
  (def server-type
    (if-let [stype (in merged-config :server-type)]
      (if (find |(= $ stype) [:tcp :udp])
        stype
        # else
        (errorf "invalid server type: %n" stype))
      :udp))

  (def [server-ip server-port] server-address)
  (log/info "Jumper v%d.%d.%d (%n)" ;JUMPER-VERSION)
  (log/info "Starting %s server at %s:%d ..." server-type server-ip server-port)
  (case server-type
    :tcp
    (net/server server-ip
                server-port
                |(handle-connection $ dispatch-fn on-connection-fn))

    :udp
    (start-udp-server server-ip
                      server-port
                      dispatch-fn
                      on-connection-fn)

    (errorf "unknown server type: %n" server-type)))
