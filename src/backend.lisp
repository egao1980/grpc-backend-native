(in-package #:grpc-backend-native)

(defclass native-grpc-backend (grpc-protocol:grpc-backend) ())

(defclass native-grpc-channel (grpc-protocol:grpc-channel)
  ((handle :initarg :handle :initform nil :accessor native-channel-handle)))

(defclass native-grpc-stream (grpc-protocol:grpc-stream)
  ((native-call :initarg :native-call :initform nil :accessor native-stream-call)))

(defvar *grpc-initialized* nil)

(defun make-native-grpc-backend ()
  (make-instance 'native-grpc-backend))

(defun use-native-grpc-backend ()
  (setf grpc-protocol:*grpc-backend* (make-native-grpc-backend)))

(defun %windows-unimplemented ()
  (error 'grpc-protocol:grpc-error
         :status :unimplemented
         :message "grpc-backend-native: egao1980/grpc has no windows overlay yet"))

#+win32
(progn
  (defmethod grpc-protocol:backend-grpc-connect
      ((backend native-grpc-backend) target &key credentials metadata)
    (declare (ignore target credentials metadata))
    (%windows-unimplemented))

  (defmethod grpc-protocol:backend-grpc-call
      ((channel native-grpc-channel) method request &key timeout metadata)
    (declare (ignore method request timeout metadata))
    (%windows-unimplemented))

  (defmethod grpc-protocol:backend-grpc-stream
      ((channel native-grpc-channel) method &key metadata)
    (declare (ignore method metadata))
    (%windows-unimplemented)))

#-win32
(progn
  (defun %init-grpc ()
    (unless *grpc-initialized*
      (grpc:init-grpc)
      (setf *grpc-initialized* t)))

  (defun %status (code)
    (let ((name (string code)))
      (cond
        ((and (>= (length name) 13)
              (string= name "GRPC-STATUS-" :end1 13))
         (intern (subseq name 13) :keyword))
        ((eq code :grpc-call-ok) :ok)
        (t :unknown))))

  (defun %message-octets (request)
    (cond
      ((and (vectorp request) (not (stringp request)))
       (coerce request '(vector (unsigned-byte 8))))
      (t
       (let ((encode (and (find-package '#:protobuf-protocol)
                          (find-symbol "ENCODE-TO-OCTETS" '#:protobuf-protocol))))
         (if (and encode (fboundp encode))
             (funcall encode request)
             (let ((ser (and (find-package '#:cl-protobufs)
                             (find-symbol "SERIALIZE-TO-BYTES" '#:cl-protobufs))))
               (if (and ser (fboundp ser))
                   (funcall ser request)
                   (error 'grpc-protocol:grpc-error
                          :status :invalid-argument
                          :message "request must be octets or a proto message"))))))))

  (defun %join-chunks (chunks)
    (cond
      ((null chunks)
       (make-array 0 :element-type '(unsigned-byte 8)))
      ((and (vectorp chunks) (not (stringp chunks)))
       chunks)
      ((and (consp chunks) (every (lambda (c) (and (vectorp c) (not (stringp c)))) chunks))
       (apply #'concatenate '(vector (unsigned-byte 8)) chunks))
      (t chunks)))

  (defun %decode (octets class)
    (let ((decode (and (find-package '#:protobuf-protocol)
                       (find-symbol "DECODE-OCTETS" '#:protobuf-protocol))))
      (if (and decode (fboundp decode))
          (funcall decode octets class)
          octets)))

  (defun %translate-grpc-error (e)
    (error 'grpc-protocol:grpc-error
           :status (%status (grpc::call-error e))
           :message (format nil "~A" e)
           :details e))

  (defmethod grpc-protocol:backend-grpc-connect
      ((backend native-grpc-backend) target &key credentials metadata)
    (%init-grpc)
    (unless (or (null credentials) (eq credentials :insecure))
      (error 'grpc-protocol:grpc-error
             :status :unimplemented
             :message "wave-1 native backend supports :insecure credentials only"))
    (make-instance 'native-grpc-channel
                   :target target
                   :backend backend
                   :credentials (or credentials :insecure)
                   :metadata metadata
                   :handle (grpc::create-channel
                            target (grpc::grpc-insecure-credentials-create))))

  (defmethod grpc-protocol:backend-grpc-call
      ((channel native-grpc-channel) method request &key timeout metadata)
    (declare (ignore timeout))
    (when (grpc-protocol:grpc-channel-closed-p channel)
      (error 'grpc-protocol:grpc-error
             :status :failed-precondition
             :message "channel is closed"))
    (handler-case
        (let* ((bytes (%message-octets request))
               (raw (grpc:grpc-call (native-channel-handle channel)
                                    method bytes nil nil))
               (octets (%join-chunks raw))
               (class (getf metadata :response-class)))
          (if class
              (%decode octets class)
              octets))
      (grpc::grpc-call-error (e)
        (%translate-grpc-error e))))

  (defmethod grpc-protocol:backend-grpc-stream
      ((channel native-grpc-channel) method &key metadata)
    (declare (ignore metadata))
    (when (grpc-protocol:grpc-channel-closed-p channel)
      (error 'grpc-protocol:grpc-error
             :status :failed-precondition
             :message "channel is closed"))
    (handler-case
        (make-instance 'native-grpc-stream
                       :channel channel
                       :method method
                       :native-call (grpc::start-grpc-call
                                     (native-channel-handle channel) method))
      (grpc::grpc-call-error (e)
        (%translate-grpc-error e))))

  (defmethod grpc-protocol:grpc-send ((stream native-grpc-stream) message &key)
    (let ((call (native-stream-call stream)))
      (unless call
        (error 'grpc-protocol:grpc-error
               :status :failed-precondition
               :message "stream is closed"))
      (handler-case
          (progn
            (grpc::send-message call (%message-octets message))
            message)
        (grpc::grpc-call-error (e)
          (%translate-grpc-error e)))))

  (defmethod grpc-protocol:grpc-recv ((stream native-grpc-stream) &key timeout)
    (declare (ignore timeout))
    (let ((call (native-stream-call stream)))
      (unless call
        (error 'grpc-protocol:grpc-error
               :status :failed-precondition
               :message "stream is closed"))
      (handler-case
          (let ((raw (grpc::receive-message call)))
            (if raw (%join-chunks raw) :eof))
        (grpc::grpc-call-error (e)
          (%translate-grpc-error e)))))

  (defmethod grpc-protocol:grpc-close ((channel native-grpc-channel) &key)
    (let ((handle (native-channel-handle channel)))
      (when handle
        (ignore-errors (grpc::grpc-channel-destroy handle))
        (setf (native-channel-handle channel) nil)))
    (call-next-method))

  (defmethod grpc-protocol:grpc-close ((stream native-grpc-stream) &key)
    (let ((call (native-stream-call stream)))
      (when call
        (ignore-errors (grpc::client-close call))
        (ignore-errors (grpc::free-call-data call))
        (setf (native-stream-call stream) nil)))
    (call-next-method)))

(eval-when (:load-toplevel :execute)
  (use-native-grpc-backend))
