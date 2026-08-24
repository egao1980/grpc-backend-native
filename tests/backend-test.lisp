(in-package #:grpc-backend-native/tests)

(deftest backend-class
  (ok (typep (grpc-backend-native:make-native-grpc-backend)
             'grpc-backend-native:native-grpc-backend)))

(deftest auto-selects-backend
  (ok (typep grpc-protocol:*grpc-backend*
             'grpc-backend-native:native-grpc-backend)))

#+win32
(deftest windows-connect-unimplemented
  (ok (signals (grpc-protocol:grpc-connect "localhost:1" :credentials :insecure)
               'grpc-protocol:grpc-error)))

#-win32
(deftest connect-insecure-and-close
  (let ((ch (grpc-protocol:grpc-connect "localhost:1" :credentials :insecure)))
    (ok (typep ch 'grpc-backend-native:native-grpc-channel))
    (ok (equal "localhost:1" (grpc-protocol:grpc-channel-target ch)))
    (ok (eq :insecure (grpc-protocol:grpc-channel-credentials ch)))
    (grpc-protocol:grpc-close ch)
    (ok (grpc-protocol:grpc-channel-closed-p ch))
    (ok (signals (grpc-protocol:grpc-call ch "/pkg.Svc/Ping" #())
                 'grpc-protocol:grpc-error))))

#-win32
(deftest ssl-credentials-unimplemented
  (ok (signals (grpc-protocol:grpc-connect "localhost:1"
                                           :credentials '(:ssl :pem-root-certs "x"))
               'grpc-protocol:grpc-error)))
