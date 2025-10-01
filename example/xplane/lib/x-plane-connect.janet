
(def MAX-DATAGRAM-SIZE 65535)

# Row ID, followed by 8 float numbers
(def DATA-ROW-DEF (ffi/struct :uint32 ;(array/new-filled 8 :float)))
# x, y, text length
(def TEXT-HEADER-DEF (ffi/struct :pack-all :int32 :int32 :uint8))
# op, count
(def WYPT-HEADER-DEF (ffi/struct :pack-all :uint8 :uint8))
# aircraft, latitude, longitude, altitude, pitch, roll, heading, gear
(def POSI-HEADER-DEF-1 (ffi/struct :pack-all :uint8 ;(array/new-filled 7 :float)))
(def POSI-HEADER-DEF-2 (ffi/struct :pack-all :uint8 ;(array/new-filled 3 :double) ;(array/new-filled 4 :float)))
# latitudinal stick, longitudinal stick, rudder pedals, throttle, gear, flaps, aircraft, speedbrakes
(def CTRL-HEADER-DEF (ffi/struct :pack-all ;(array/new-filled 4 :float) :int8 :float :uint8 :float))


(defn x-plane-connect-close [self]
  "Closes the connection."
  (:close (in self :stream)))


(defn int32-to-uint32 [n]
  (if (neg? n)
    (+ n (math/pow 2 32))
    n))


(defn x-plane-connect-send-command [self & cmd-and-args]
  (def buf (in self :buffer))
  (buffer/clear buf)

  (when (empty? cmd-and-args)
    (error "empty command"))

  (def cmd (first cmd-and-args))
  (buffer/push-string buf (string/ascii-upper cmd))
  (buffer/push-byte buf 0)
  (def header-size (length buf))

  (match cmd-and-args
    [:conn new-port]
    (ffi/write :uint16 new-port buf (length buf))

    [:simu pause?]
    (ffi/write :uint8 (if pause? 1 0) buf (length buf))

    [:data data]
    (each row data
      (ffi/write DATA-ROW-DEF row buf (length buf)))

    [:getp aircraft]
    (ffi/write :uint8 aircraft buf (length buf))

    [:posi aircraft values]
    (ffi/write POSI-HEADER-DEF-2 [aircraft ;values] buf (length buf))

    [:getc aircraft]
    (ffi/write :uint8 aircraft buf (length buf))

    [:ctrl values]
    (ffi/write CTRL-HEADER-DEF values buf (length buf))

    [:dref data]
    (each [dref values] data
      (def dref-len (length dref))
      (def value-count (length values))
      (when (> dref-len 255)
        (errorf "dref name is too long: %s" dref))
      (when (> value-count 255)
        (errorf "too many values for dref: %s" dref))
      (ffi/write :uint8 dref-len buf (length buf))
      (buffer/push-string buf dref)
      (ffi/write :uint8 value-count buf (length buf))
      (each v values
        (ffi/write :float v buf (length buf))))

    [:getd dref-list]
    (let [dref-count (length dref-list)]
      (when (> dref-count 255)
        (error "too many drefs"))
      (ffi/write :uint8 dref-count buf (length buf))
      (each dref dref-list
        (def dref-len (length dref))
        (when (> dref-len 255)
          (errorf "dref name is too long: %s" dref))
        (ffi/write :uint8 dref-len buf (length buf))
        (buffer/push-string buf dref)))

    [:text x y msg]
    (let [msg-len (length msg)]
      (when (> msg-len 255)
        (errorf "text of length %n cannot fit into a network message" msg-len))
      (ffi/write TEXT-HEADER-DEF [x y msg-len] buf (length buf))
      # The trailing null byte is not pushed
      (buffer/push-string buf msg))

    [:view view-id]
    (ffi/write :int32 view-id buf (length buf))

    [:wypt op coords]
    (let [count (length coords)]
      (if (> count 255)
        (error "cannot send more than 255 coordinates at a time"))
      (unless (= 0 (% count 3))
        (errorf "malformed coordinate array: %n" coords))
      (ffi/write WYPT-HEADER-DEF [op count] buf (length buf))
      (each c coords
        (ffi/write :float c buf (length buf))))

    _
    (errorf "unknown or malformed command: %n" cmd-and-args))

  (:write (in self :stream) buf (in self :timeout)))


(defn x-plane-connect-recv-response [self header]
  (def header-size (+ 1 (length header))) # Plus one null byte
  (def buf (in self :buffer))
  (buffer/clear buf)

  (:read (in self :stream)
         MAX-DATAGRAM-SIZE
         buf
         (in self :timeout))

  (def buf-len (length buf))

  (unless (= (slice buf 0 header-size)
             (string (string/ascii-upper header) "\0"))
    (errorf "invalid response header: %n" buf))

  (case header
    :conf
    # Return the connection ID
    (in buf header-size)

    :data
    (if (<= buf-len header-size)
      # There's nothing but a header
      nil
      (let [row-width 9
            row-size (* (ffi/size :float) row-width)
            data @[]]
        (loop [offset :range [header-size buf-len row-size]]
          (array/push data (ffi/read DATA-ROW-DEF buf offset)))
        data))

    :posi
    (ffi/read POSI-HEADER-DEF-2 buf header-size)

    :ctrl
    (ffi/read CTRL-HEADER-DEF buf header-size)

    :resp
    (let [res-count (ffi/read :uint8 buf header-size)
          res-list @[]]
      (var offset (+ header-size (ffi/size :uint8)))
      (for i 0 res-count
        (def value-count (ffi/read :uint8 buf offset))
        (def arr-fmt @[:float value-count])
        (+= offset (ffi/size :uint8))
        (array/push res-list (ffi/read arr-fmt buf offset))
        (+= offset (ffi/size arr-fmt)))
      res-list)

    (errorf "unknown response header: %n" header)))


(defn x-plane-connect-set-conn [self new-port]
  "Changes to another port."
  (def stream (in self :stream))
  (def [local-host _local-port] (net/localname stream))
  (def server-address (net/peername stream))

  (def new-stream
    (net/connect ;server-address
                 :datagram
                 local-host new-port))

  (:send-command self :conn new-port)
  (:close stream)

  (put self :stream new-stream)
  (:recv-response self :conf))


(defn x-plane-connect-pause-sim [self pause?]
  (:send-command self :simu pause?))


(defn x-plane-connect-read-data [self]
  (:recv-response self :data))


(defn x-plane-connect-send-data [self data]
  (:send-command self :data data))


(defn x-plane-connect-get-posi [self &opt aircraft]
  (default aircraft 0)

  (:send-command self :getp aircraft)
  (:recv-response self :posi))


(defn x-plane-connect-send-posi [self values &opt aircraft]
  (default aircraft 0)

  (def [lat long alt pitch roll heading gear] values)
  (def normalized-values
    [(or lat -998)
     (or long -998)
     (or alt -998)
     (or pitch -998)
     (or roll -998)
     (or heading -998)
     (or gear -998)])
  (:send-command self :posi aircraft normalized-values))


(defn x-plane-connect-get-ctrl [self &opt aircraft]
  (default aircraft 0)

  (:send-command self :getc aircraft)
  (:recv-response self :ctrl))


(defn x-plane-connect-send-ctrl [self values &opt aircraft]
  (default aircraft 0)

  (def [lat-stick long-stick rudder throttle gear flaps speedbrakes] values)
  (def normalized-values
    [(or lat-stick -998)
     (or long-stick -998)
     (or rudder -998)
     (or throttle -998)
     (cond
       (nil? gear) -1
       (= -998 gear) -1
       true gear)
     (or flaps -998)
     aircraft
     (or speedbrakes -998)])
  (:send-command self :ctrl normalized-values))


(defn x-plane-connect-send-dref [self dref-data]
  (def normalized-data @[])
  (eachp [dref value] dref-data
    (if (indexed? value)
      (array/push normalized-data [dref value])
      (array/push normalized-data [dref [value]])))
  (:send-command self :dref normalized-data))


(defn x-plane-connect-get-dref [self & dref-list]
  (:send-command self :getd dref-list)
  (def res (:recv-response self :resp))
  (def res-table @{})
  (map (fn [dref values]
         (if (= 1 (length values))
           (put res-table dref (first values))
           (put res-table dref values)))
       dref-list
       res)
  res-table)


(defn x-plane-connect-send-text [self msg &opt x y]
  (default x -1)
  (default y -1)
  (:send-command self :text x y msg))


(defn x-plane-connect-send-view [self view]
  (def view-id
    (case view
      :forwards 73
      :down 74
      :left 75
      :right 76
      :back 77
      :tower 78
      :runway 79
      :chase 80
      :follow 81
      :follow-with-panel 82
      :spot 83
      :fullscreen-with-hud 84
      :fullscreen-no-hud 85
      (errorf "unknown view: %n" view)))
  (:send-command self :view view-id))


(defn x-plane-connect-send-wypt [self op &opt points]
  (default points [])

  (def op-id
    (case op
      :add 1
      :remove 2
      :clear 3
      (errorf "unknown operation: %n" op)))
  (:send-command self :wypt op-id (flatten points)))


(def x-plane-connect-proto
  @{:close x-plane-connect-close
    :send-command x-plane-connect-send-command
    :recv-response x-plane-connect-recv-response

    :set-conn x-plane-connect-set-conn
    :pause-sim x-plane-connect-pause-sim
    :read-data x-plane-connect-read-data
    :send-data x-plane-connect-send-data
    :get-posi x-plane-connect-get-posi
    :send-posi x-plane-connect-send-posi
    :get-ctrl x-plane-connect-get-ctrl
    :send-ctrl x-plane-connect-send-ctrl
    :send-dref x-plane-connect-send-dref
    :get-dref x-plane-connect-get-dref
    :send-text x-plane-connect-send-text
    :send-view x-plane-connect-send-view
    :send-wypt x-plane-connect-send-wypt})


(defn x-plane-connect [&opt server-host server-port host port timeout]
  (default server-host "127.0.0.1")
  (default server-port 49009)
  (default timeout 0.1)  # in seconds

  (def stream (net/connect server-host server-port :datagram host port))

  (table/setproto
   @{:stream stream
     :timeout timeout
     :buffer @""}
   x-plane-connect-proto))
