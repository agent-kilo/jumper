(declare-project
 :name "Jumper"
 :description "A server converting DroidPad inputs to vJoy/keyboard/mouse events."
 :dependencies [{:url "https://github.com/janet-lang/spork.git"
                 :tag "f5295bfc0d41f947dc1bfd4d7c6a0400279dad5d"}])


(def DEBUG-CFLAGS
  (if (= "debug" (dyn :build-type))
    ["/Zi" (string "/Fd" (find-build-dir))]
    []))

(def DEBUG-LDFLAGS
  (if (= "debug" (dyn :build-type))
    ["/DEBUG"]
    []))


(declare-executable
 :name "jumper"
 :entry "src/main.janet"
 :deps [;(->> (os/dir "src")
              (filter |(string/has-suffix? ".janet" $))
              (map |(string "src/" $)))]
 :cflags  [;(dyn :cflags) ;DEBUG-CFLAGS]
 :ldflags [;DEBUG-LDFLAGS])
