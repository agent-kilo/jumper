(compwhen
 (= :windows (os/which))

 (import ./win32/kbd :prefix "" :export true))
