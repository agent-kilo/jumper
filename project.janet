(declare-project
 :name "Jumper"
 :description "A server converting DroidPad inputs to vJoy/keyboard/mouse events."
 :dependencies [{:url "https://github.com/janet-lang/spork.git"
                 :tag "f5295bfc0d41f947dc1bfd4d7c6a0400279dad5d"}
                {:url "https://github.com/agent-kilo/project-tools.git"
                 :tag "32837cdd86cdb6b07ddb000ea54bfa50dd0dfcd2"}])


(try
  (do
   (import project-tools/vcs)
   (import project-tools/util))
  ((_err fib)
   (printf "Warning: Failed to import project-tools. Do `jpm -l deps` first?")))


(def DEBUG-CFLAGS
  (if (= "debug" (dyn :build-type))
    ["/Zi" (string "/Fd" (find-build-dir))]
    []))

(def DEBUG-LDFLAGS
  (if (= "debug" (dyn :build-type))
    ["/DEBUG"]
    []))


(defn generate-resource-header [env out-file-name]
  (with [out-file (file/open out-file-name :wn)]
    (eachp [k v] env
      (when (and (table? v)
                 (v :resource)
                 (v :value))
        (file/write out-file (string/format "#define %s %v\n" k (v :value)))))))


(defn generated [name]
  (string (find-build-dir) name))


(defmacro gen-rule [target deps & body]
  ~(let [_target ,target
         _deps   ,deps]
     (rule _target [;_deps]
       (util/ensure-dir (find-build-dir))
       ,;body
       (printf "Generated %s" _target))))


(compwhen (dyn 'util/ensure-dir)

 (gen-rule (generated "resource.h") ["src/resource.janet"]
   (generate-resource-header (dofile "src/resource.janet") _target))


 (gen-rule (generated "resource.res") ["res/jumper.rc"
                                       "res/jumper.ico"
                                       (generated "resource.h")]
   (util/spawn-and-wait "rc.exe" "/I" (find-build-dir) "/fo" _target (_deps 0)))


 (gen-rule (generated "resource.obj") [(generated "resource.res")]
   (util/spawn-and-wait "cvtres.exe" "/machine:x64" (string "/out:" _target) (_deps 0)))


 (task "vcs-version" []
   (def vcs-version-file (generated "vcs-version.txt"))
   (def vcs-version (vcs/get-vcs-version))
   (printf "Detected source version: %n" vcs-version)

   (def cur-version
     (vcs/format-vcs-version-string vcs-version 10))
   (def old-version
     (try
       (string/trim (slurp vcs-version-file))
       ((_err _fib)
        nil)))

   (printf "Old vcs-version: %n" old-version)
   (printf "Current vcs-version: %n" cur-version)

   (when (and cur-version
              (not= cur-version old-version))
     (util/ensure-dir (find-build-dir))
     (spit vcs-version-file cur-version)
     (try
       # So that the next build will try to use the new version info
       (os/rm (generated "resource.h"))
       ((_err _fib) :ignore))))


 (declare-executable
  :name "jumper"
  :entry "src/main.janet"
  :deps [;(->> (os/dir "src")
               (filter |(string/has-suffix? ".janet" $))
               (map |(string "src/" $)))
         (generated "resource.obj")]
  :cflags  [;(dyn :cflags) ;DEBUG-CFLAGS]
  :ldflags [(generated "resource.obj") ;DEBUG-LDFLAGS])

)
