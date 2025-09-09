(import ./evdev)


######### Helpers #########

(defn get-controls [id]
  # TODO
  {:buttons 0
   :discrete-povs 0
   :continuous-povs 0
   :axes @{}})


(defn update [dev &opt buf]
  # TODO
  )


(defn reset [dev]
  # TODO
  )


(var vjoy-devs @{})

(defn acquire [id &opt reset?]
  (default reset? true)

  (def dev
    (if-let [dev (in vjoy-devs id)]
      dev
      # else
      (do
        (def uinput-dev (evdev/create-uinput-device :joystick))
        (def dev
          @{:id id
            :dev uinput-dev
            :controls (get-controls id)})
        (put vjoy-devs id dev)
        dev)))

  (when reset?
    (reset dev))

  dev)


(defn relinquish [dev]
  (def id (in dev :id))
  (put vjoy-devs id nil)
  (evdev/call-interface 'uinput_destroy (in dev :dev)))


(defn check-device [id]
  # Simply try to acquire the device (also reset it)
  (acquire id)
  true)


(defn set-button [dev btn-id value]
  # TODO
  )


(defn set-axis [dev axis-name value]
  # TODO
  )


(defn set-discrete-pov [dev pov-id value]
  # TODO
  )


(defn set-continuous-pov [dev pov-id value]
  # TODO
  )


(defn get-device [id]
  # (acquire id) always resets the device. Here we don't want to reset
  # it when it already exists.
  (if-let [dev (in vjoy-devs id)]
    dev
    (acquire id)))
