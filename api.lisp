(defpackage #:aws-sdk/api
  (:use #:cl)
  (:import-from #:aws-sdk/session
                #:*session*
                #:session-credentials
                #:session-region)
  (:import-from #:aws-sdk/credentials
                #:credentials-keys
                #:credentials-headers
                #:default-aws-credentials)
  (:import-from #:aws-sign4)
  (:import-from #:dexador)
  (:import-from #:quri)
  (:export #:*session*
           #:aws-request))
(in-package #:aws-sdk/api)

(defun aws-host (service region)
  (format nil "~(~A~).~(~A~).amazonaws.com" service region))

(defun aws-request (&key (path "/") service method params headers payload
                      (session *session*))
  (let ((credentials (or (session-credentials session)
                         (default-aws-credentials)))
        (region (session-region session)))
    (unless credentials
      (error "No credentials are found"))
    (unless region
      (error "AWS region is not configured"))
    (let ((host (aws-host service region))
          (aws-sign4:*aws-credentials* (lambda () (credentials-keys credentials))))
      (setf headers
            (append (credentials-headers credentials)
                    headers))
      (multiple-value-bind (authorization x-amz-date)
          (aws-sign4:aws-sign4 :region region
                               :service service
                               :method method
                               :host host
                               :path path
                               :params params
                               :headers headers
                               :payload (or payload ""))
        (dex:request (format nil "https://~A~A?~A" host path
                             (quri:url-encode-params params))
                     :method method
                     :headers `(("Authorization" . ,authorization)
                                ("X-Amz-Date" . ,x-amz-date)
                                ("X-Amz-Content-Sha256" . ,(aws-sdk/utils::sha-256 (or payload "")))
                                ("Content-Type" . "application/x-amz-json-1.0")
                                ,@headers)
                     :content payload
                     :keep-alive nil)))))
