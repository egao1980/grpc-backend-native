(defsystem "grpc-backend-native"
  :version "0.1.0"
  :description "qitab/grpc (egao1980 fork) backend for grpc-protocol"
  :author "egao1980"
  :license "MIT"
  :depends-on ("grpc-protocol"
               #-win32 "grpc")
  :properties (:cl-repo (:ci (:with ("dissect"))))
  :serial t
  :pathname "src"
  :components ((:file "package")
               (:file "backend"))
  :in-order-to ((test-op (test-op "grpc-backend-native/tests"))))

(defsystem "grpc-backend-native/tests"
  :depends-on ("grpc-backend-native" "rove")
  :pathname "tests"
  :serial t
  :components ((:file "package")
               (:file "backend-test"))
  :perform (test-op (o c)
             (unless (symbol-call :rove :run c)
               (error "tests failed for ~A" (component-name c)))))
