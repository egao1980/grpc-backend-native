(in-package #:grpc-backend-native/tests)

(deftest backend-class
  (ok (typep (grpc-backend-native:make-native-grpc-backend) 'grpc-backend-native:native-grpc-backend)))
