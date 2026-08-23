(in-package #:grpc-backend-native)

(defclass native-grpc-backend (grpc-protocol:grpc-backend) ())

(defun make-native-grpc-backend ()
  (make-instance 'native-grpc-backend))

(defun use-native-grpc-backend ()
  (setf grpc-protocol:*grpc-backend* (make-native-grpc-backend)))
