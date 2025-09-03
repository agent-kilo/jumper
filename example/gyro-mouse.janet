#
# This is an example config for Jumper. It converts DroidPad gyroscope data
# to mouse movement.
#
# To try it out, you need to make a DroidPad config with gyroscope attached.
# Then add a button, and set its item identifier to "enable-gyro". Press/release
# the button to enable/disable gyro input.
#
# The default BUTTON message handler still works, so you can set a button's
# item identifier to "ms:btn:left", "ms:btn:right", etc. to emulate mouse
# clicks too.
#


#
# How fast should the mouse move? Larger number means faster movement.
#
(def MOUSE-SPEED-SCALE 1000)


#
# This is our GYROSCOPE message handler
#
(defn handle-gyroscope [msg matched route]
  (log/debug "msg = %n" msg)
  # Extract data from the DroidPad message
  (def {"x" x
        "y" y
        "z" z}
    msg)
  # Need to invert all the axes to match screen coordinates.
  (def ms-x-spd (- (* z MOUSE-SPEED-SCALE)))
  (def ms-y-spd (- (* x MOUSE-SPEED-SCALE)))
  (ms/start-relative-movement ms-x-spd ms-y-spd))


#
# This is a "no op" handler, that we use when gyro input is disabled. 
#
(defn handle-gyroscope-nop [_msg _matched _route])


#
# Custom rule for matching GYROSCOPE messages
#
(def gyro-route
  @{:type    "GYROSCOPE"
    :handler handle-gyroscope-nop
    # Add a simple moving average filter to smooth out the jitter.
    :filters [(jumper/make-simple-moving-average-filter 5 ["x" "y" "z"])]})


#
# This is the "enable-gyro" button handler. It updates the actual GYROSCOPE
# message handler, according to the button state.
#
(defn handle-enable-button [msg matched route]
  (case (in msg "state")
    "PRESS"
    (put gyro-route :handler handle-gyroscope)
    
    "RELEASE"
    (do
      (put gyro-route :handler handle-gyroscope-nop)
      (ms/stop-relative-movement))

    "CLICK"
    (if (= handle-gyroscope-nop (in gyro-route :handler))
      (put gyro-route :handler handle-gyroscope)
      # else
      (do
        (put gyro-route :handler handle-gyroscope-nop)
        (ms/stop-relative-movement)))))


#
# Custom rule for matching "enable-gyro" button messages
#
(def en-btn-route
  @{:type    "BUTTON"
    :id      "enable-gyro"
    :handler handle-enable-button})


(def jumper-config
  {:user-routes @[gyro-route en-btn-route]})
