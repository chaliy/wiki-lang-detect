(in-package #:wiki-lang-detect)
(named-readtables:in-readtable rutilsx-readtable)


(defvar *lang-detector*
  (let ((model-file (merge-pathnames "models/wiki156min.zip"
                                     (asdf:component-pathname
                                      (asdf:find-system :wiki-lang-detect)))))
    (if (probe-file model-file)
        (huffman-model (load-model model-file))
        (warn "No model at ~A" model-file)))
  "Default language detector.")

#+prod
(defparameter *woo* (bt:make-thread ^(woo:run 'woo-api :port 5000)))
