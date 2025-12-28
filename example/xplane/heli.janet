#
# This is an example config for Jumper (https://github.com/agent-kilo/jumper),
# that can be used with X-Plane 11, to help me fly virtual helicopters :D
#


(import ./lib/x-plane-connect)


#
# =================== Forward Declarations ===================
#
(var user-routes nil)


#
# =================== Cyclic Stuff ===================
#

(var cyclic-curve-exponent 1.7)

(def ACCEL-LONG-AXIS "y")
(def ACCEL-LAT-AXIS  "x")
(def ACCEL-LONG-REST-ANGLE ($$ math/pi / 2))
(def ACCEL-LAT-REST-ANGLE  ($$ math/pi / 2))
(def ACCEL-LIMIT-ANGLE     ($$ math/pi / 6))
(def ACCEL-VJOY-DEV-ID     1)


(defn apply-limit [val limit]
  (cond
    (< val (- limit)) (- limit)
    (> val limit)     limit
    true val))


(defn msg-to-normalized-angles [msg]
  (def {"x" x
        "y" y
        "z" z}
    msg)

  (def G (math/sqrt ($$ x ** 2 + y ** 2 + z ** 2)))
  (def long-angle ($$ ,(math/acos ($$ msg[ACCEL-LONG-AXIS] / G))))
  (def lat-angle  ($$ ,(math/acos ($$ msg[ACCEL-LAT-AXIS]  / G))))
  (log/debug "G = %n, long-angle = %n, lat-angle = %n" G long-angle lat-angle)

  (def long ($$ long-angle - ACCEL-LONG-REST-ANGLE))
  (def lat  ($$ lat-angle  - ACCEL-LAT-REST-ANGLE))
  (log/debug "long = %n, lat = %n" long lat)

  [long lat])


(defn normalized-angle-to-deviation [angle]
  ($$ ,(apply-limit angle ACCEL-LIMIT-ANGLE) / ACCEL-LIMIT-ANGLE))


(defn deviation-to-vjoy-axis [deviation axis dev]
  (def [axis-min axis-max] (get-in dev [:controls :axes axis]))
  (def axis-half-range   ($$ (axis-max - axis-min) / 2))
  (def axis-middle-point ($$ (axis-max + axis-min) / 2))
  (math/round ($$ axis-middle-point - deviation * axis-half-range)))


(defn apply-curve [val]
  (def sign (if (neg? val) -1 1))
  (* sign (math/pow (math/abs val) cyclic-curve-exponent)))


(defn handle-accelerometer [msg matched route]
  (def dev (vjoy/get-device ACCEL-VJOY-DEV-ID))
  (->> msg
       (msg-to-normalized-angles)
       (map |(normalized-angle-to-deviation $0))
       (map apply-curve)
       (map |(deviation-to-vjoy-axis $1 $0 dev) [:x :y])
       (map |(vjoy/set-axis dev $0 $1) [:x :y]))
  (vjoy/update dev))


#
# =================== Dashboard Stuff ===================
#

(def FEET-PER-METER          3.280839895)
(def FEET-PER-NM             6076.1154855643)
(def METERS-PER-SEC-TO-KNOTS 1.9438444924)

(def DASHBOARD-UPDATE-INTERVAL 0.1)  # in seconds
(def RECV-TIMEOUT              0.5)

(def DATAREF-IAS "sim/flightmodel/position/indicated_airspeed")
(def DATAREF-GS  "sim/flightmodel/position/groundspeed")
(def DATAREF-VS  "sim/flightmodel/position/vh_ind_fpm")
(def DATAREF-AGL "sim/flightmodel/position/y_agl")
(def DATAREF-MSL "sim/cockpit2/gauges/indicators/altitude_ft_pilot")
(def DATAREF-NAV1-DME-DIST "sim/cockpit/radios/nav1_dme_dist_m")
(def DATAREF-NAV2-DME-DIST "sim/cockpit/radios/nav2_dme_dist_m")
(def DATAREF-NAV1-HAS-DME  "sim/cockpit2/radios/indicators/nav1_has_dme")
(def DATAREF-NAV2-HAS-DME  "sim/cockpit2/radios/indicators/nav2_has_dme")
(def DATAREF-NAV1-AUDIO    "sim/cockpit2/radios/actuators/audio_selection_nav1")
(def DATAREF-NAV2-AUDIO    "sim/cockpit2/radios/actuators/audio_selection_nav2")

(var dashboard-altimeter-mode :radar) # or :barometric


(defn xpc-worker []
  (with [xpc (x-plane-connect/x-plane-connect nil nil nil nil RECV-TIMEOUT)]
    (var stop false)

    (while (not stop)
      (try
        (do
          # dashboard-altimeter-mode may change when :get-ref is waiting for the reply.
          # Save a copy so we won't get surprised.
          (def alt-mode dashboard-altimeter-mode)
          (log/debug "xpc-worker: alt mode = %n" alt-mode)
          (def dref (:get-dref xpc
                               DATAREF-IAS
                               DATAREF-GS
                               DATAREF-VS
                               (case alt-mode
                                 :radar      DATAREF-AGL
                                 :barometric DATAREF-MSL
                                 (errorf "unknown altimeter mode: %n" alt-mode))
                               DATAREF-NAV1-DME-DIST
                               DATAREF-NAV1-HAS-DME
                               DATAREF-NAV2-DME-DIST
                               DATAREF-NAV2-HAS-DME))
          (def {DATAREF-IAS ias # in knots
                DATAREF-GS  gs  # in meters/sec
                DATAREF-VS  vs  # in feet/min
                DATAREF-NAV1-DME-DIST nav1-dme-dist # in nautical miles
                DATAREF-NAV1-HAS-DME  nav1-has-dme
                DATAREF-NAV2-DME-DIST nav2-dme-dist # in nautical miles
                DATAREF-NAV2-HAS-DME  nav2-has-dme}
            dref)
          (def alt
            (case alt-mode
              :radar      (* FEET-PER-METER (in dref DATAREF-AGL)) # y_agl is in meters
              :barometric (in dref DATAREF-MSL)))
          (def gs-knots (* gs METERS-PER-SEC-TO-KNOTS))
          (def slope
            (if (< gs-knots 0.0001)
              (cond
                (< vs -0.01) -100
                (> vs 0.01)  100
                true         0)
              (* 100 (/ (* vs 60) FEET-PER-NM gs-knots))))

          (log/debug "xpc-worker: airspeed = %n, groundspeed = %n, vs = %n, alt = %n, slope = %n" ias gs-knots vs alt slope)
          (log/debug "xpc-worker: nav1-has-dme = %n, nav1-dme-dist = %n" nav1-has-dme nav1-dme-dist)
          (log/debug "xpc-worker: nav2-has-dme = %n, nav2-dme-dist = %n" nav2-has-dme nav2-dme-dist)

          (jumper/send-gauge  "ias"   ias)
          (jumper/send-gauge  "slope" slope)
          (jumper/send-slider "vs"    vs)
          (jumper/send-gauge  "alt"   alt)
          (jumper/send-gauge  "nav1-dme-dist" nav1-dme-dist)
          (jumper/send-led    "nav1-has-dme"  (if (= 0 nav1-has-dme) :off :on))
          (jumper/send-gauge  "nav2-dme-dist" nav2-dme-dist)
          (jumper/send-led    "nav2-has-dme"  (if (= 0 nav2-has-dme) :off :on))
          (ev/sleep DASHBOARD-UPDATE-INTERVAL))

        ((err fib)
         (case err
           "timeout"
           (log/debug "xpc-worker TIMEOUT")

           "canceled"
           (do
             (log/debug "xpc-worker CANCELED")
             (set stop true))

           (propagate err fib)))))))


(def dashboard-workers @{})


(defn cancel-worker [worker]
  (def stat (fiber/status worker))
  (if (find |(= $ stat) [:dead :error])
    (log/warning "xpc-worker died unexpectedly: %n" (fiber/last-value worker))
    # else
    (ev/cancel worker "canceled")))


(defn button-pressed? [msg]
  (def btn-state (in msg "state"))
  (truthy? (find |(= $ btn-state) ["PRESS" "CLICK"])))


(defn handle-btn-connect-dashboard [msg &]
  (unless (button-pressed? msg)
    # Early return
    (break))

  (def peer (jumper/get-peer))
  (when-let [w (in dashboard-workers peer)]
    # Already connected, reset the connection by killing the worker
    (cancel-worker w))
  (put dashboard-workers peer (ev/spawn (xpc-worker)))
  (jumper/send-led "led-alt-mode" (if (= :radar dashboard-altimeter-mode) :on :off)))


(defn on-disconnection []
  (def peer (jumper/get-peer))
  (when-let [w (in dashboard-workers peer)]
    (put dashboard-workers peer nil)
    (cancel-worker w)))


(defn handle-btn-alt-mode [msg &]
  (unless (button-pressed? msg)
    # Early return
    (break))

  (set dashboard-altimeter-mode
       (case dashboard-altimeter-mode
         :radar      :barometric
         :barometric :radar
         (errorf "unknown altimeter mode: %n" dashboard-altimeter-mode)))
  (jumper/send-led "led-alt-mode" (if (= :radar dashboard-altimeter-mode) :on :off)))


(defn handle-btn-nav-audio-off [msg &]
  (unless (button-pressed? msg)
    # Early return
    (break))

  (with [xpc (x-plane-connect/x-plane-connect)]
    (:send-dref xpc {DATAREF-NAV1-AUDIO 0
                     DATAREF-NAV2-AUDIO 0})))


(defn handle-btn-nav-audio [msg &]
  (unless (button-pressed? msg)
    # Early return
    (break))

  (def dataref
    (case (in msg "id")
      "btn-nav1-audio" DATAREF-NAV1-AUDIO
      "btn-nav2-audio" DATAREF-NAV2-AUDIO
      (errorf "unknown button id: %n" (in msg "id"))))
  (with [xpc (x-plane-connect/x-plane-connect)]
    (:send-dref xpc {dataref 1})))


#
# =================== Other Components ===================
#


(defn handle-slider-exponent [msg &]
  (when-let [value (in msg "value")]
    (log/info "Setting cyclic curve exponent: %n" value)
    (set cyclic-curve-exponent value)))


(def DEFAULT-AVG-FILTER-VALUE-COUNT 2)


(defn handle-slider-avg-filter [msg &]
  (when-let [value (in msg "value")]
    (def rounded (math/round value))
    (when (<= 1 rounded)
      (when-let [acc-route (find |(= "ACCELEROMETER" (in $ :type)) user-routes)]
        (log/info "Setting avg. filter value count: %n" rounded)
        (put acc-route :filters [(jumper/make-simple-moving-average-filter rounded ["x" "y" "z"])])))))


#
# =================== Jumper Settings ===================
#

(set user-routes
  @[
    @{
      :type    "ACCELEROMETER"
      :handler handle-accelerometer
      :filters [(jumper/make-simple-moving-average-filter DEFAULT-AVG-FILTER-VALUE-COUNT ["x" "y" "z"])]
     }
    @{
      :type    "BUTTON"
      :id      "btn-connect-dashboard"
      :handler handle-btn-connect-dashboard
     }
    @{
      :type    "BUTTON"
      :id      "btn-alt-mode"
      :handler handle-btn-alt-mode
     }
    @{
      :type    "BUTTON"
      :id      "btn-nav1-audio"
      :handler handle-btn-nav-audio
     }
    @{
      :type    "BUTTON"
      :id      "btn-nav-audio-off"
      :handler handle-btn-nav-audio-off
     }
    @{
      :type    "BUTTON"
      :id      "btn-nav2-audio"
      :handler handle-btn-nav-audio
     }
    @{
      :type    "SLIDER"
      :id      "slider-exp"
      :handler handle-slider-exponent
     }
    @{
      :type    "SLIDER"
      :id      "slider-avg-filter"
      :handler handle-slider-avg-filter
     }
   ])


(def jumper-config
  {:user-routes      user-routes
   :on-disconnection on-disconnection})
