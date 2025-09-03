(var log-level :info)


(def LOG-LEVELS
  {:quiet 0
   :error 1
   :warning 2
   :info 3
   :debug 4})

(def DEFAULT-LEVEL :info)


(defn get-level [] log-level)

(defn set-level [level]
  (if (has-key? LOG-LEVELS level)
    (set log-level level)
    # else
    (errorf "invalid log level: %n" level)))


(defn log [level fmt & args]
  (when (<= (in LOG-LEVELS level)
            (in LOG-LEVELS (get-level)))
    (def time-str (os/strftime "%Y-%m-%d %H:%M:%S" nil true))
    (printf (string "%s [%s] " fmt) time-str level ;args)))


(defmacro debug [fmt & args]
  ~(,log :debug ,fmt ,;args))

(defmacro info [fmt & args]
  ~(,log :info ,fmt ,;args))

(defmacro warning [fmt & args]
  ~(,log :warning ,fmt ,;args))

(defmacro error [fmt & args]
  ~(,log :error ,fmt ,;args))
