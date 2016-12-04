(in-package #:wiki-lang-detect)
(named-readtables:in-readtable rutilsx-readtable)


;;; heap

(declaim (inline hparent hleft hright heap-size list-bitvec))

(defstruct heap
  (vec (make-array 0 :adjustable t :fill-pointer t))
  op
  (key 'identity))

(defmethod print-object ((obj heap) out)
  (if (zerop (length @obj.vec))
      (format out "#<empty heap>")
      (let ((h (min (+ 1 (floor (log (heap-size obj) 2)))
                    3)))
        (dotimes (i h)
          (let ((spaces (loop :repeat (- (expt 2 (- h i)) 1) :collect #\Space)))
            (dotimes (j (expt 2 i))
              (let ((k (+ (expt 2 i) j -1)))
                (when (= k (heap-size obj)) (return))
                (format out "~{~C~}~2D~{~C~}" spaces (? @obj.vec k) spaces)))
            (format out "~%")))))
  obj)


(defun hparent (i)
  (floor (- i 1) 2))

(defun hleft (i)
  (- (hright i) 1))

(defun hright (i)
  (* (+ i 1) 2))

(defun heap-size (heap)
  (length @heap.vec))

(defun heap-up (heap i)
  (loop :while (and (plusp i)
                    (call @heap.op
                          (call @heap.key (? @heap.vec i))
                          (call @heap.key (? @heap.vec (hparent i))))) :do
    (rotatef (? @heap.vec i) (? @heap.vec (hparent i)))
    (:= i (hparent i)))
  heap)

(defun heap-down (heap beg &optional (end (1- (heap-size heap))))
  (when (<= (hleft beg) end)
    (let ((child (if (or (>= (hright beg) end)
                         (call @heap.op
                               (call @heap.key (? @heap.vec (hleft beg)))
                               (call @heap.key (? @heap.vec (hright beg)))))
                     (hleft beg)
                     (hright beg))))
      (when (call @heap.op
                  (call @heap.key (? @heap.vec child))
                  (call @heap.key (? @heap.vec beg)))
        (rotatef (? @heap.vec beg) (? @heap.vec child))
        (heap-down heap child end))))
  heap)

(defun heap-push (item heap)
  (heap-up heap (vector-push-extend item @heap.vec)))

(defun heap-pop (heap)
  (rotatef (? @heap.vec 0)
           (? @heap.vec (1- (heap-size heap))))
  (prog1 (vector-pop @heap.vec)
    (heap-down heap 0)))


;;; huffman

(defvar *huffman-dict* #h())

(defun list-bitvec (list &optional (len (length list)))
  (make-array len :element-type 'bit :initial-contents (reverse list)))

(defun bin-traverse (tree dict) 
  (if (atom tree)
      (:= (? dict tree) #*0)
      (let ((queue (list (list tree () 0))))
        (loop :while queue :do
          (with ((((lt rt) pre lvl) (pop queue))
                 (lpre (cons 0 pre))
                 (rpre (cons 1 pre))
                 (lvl (1+ lvl)))
            (if (listp lt)
                (push (list lt lpre lvl)
                      queue)
                (:= (? dict lt) (list-bitvec lpre lvl)))
            (if (listp rt)
                (push (list rt rpre lvl)
                      queue)
                (:= (? dict rt) (list-bitvec rpre lvl)))))))
  dict)

(defun huffman-dict (&optional (model *lang-detector*))
  (let ((counts #h(equal))
        (rez #h(equal)))
    (dotable (word _ @model.words)
      (loop :for char :across word :do
        (let ((cur (getset# (unicode-script char) counts #h())))
          (:+ (get# char cur 0)))))
    (dotable (3g _ @model.3gs)
      (loop :for char :across 3g :do
        (let ((cur (getset# (unicode-script char) counts #h())))
          (:+ (get# char cur 0)))))
    (dotable (script cur counts)
      (let ((heap (make-heap :op '< :key 'rt)))
        (dotable (char count cur)
          (heap-push (pair char count)
                     heap))
        (loop :repeat (1- (heap-size heap)) :do
          (with (((right cr) (heap-pop heap))
                 ((left cl) (heap-pop heap)))
            (heap-push (pair (list left right) (+ cl cr))
                       heap)))
        (:= (? rez script)
            (bin-traverse (lt (heap-pop heap)) #h()))))
    rez))

(defun word-bitvec (huffman word)
  ""
  (list-bitvec (apply 'concatenate 'vector
                      (loop :for char :across word
                            :collect (? huffman char)))))

(defun huffman-encode (word &optional (model *lang-detector*))
  ""
  (with ((script (word-script word))
         (huffman (? @model.huffman script)))
    (when huffman
      (reduce ^(concatenate 'bit-vector % %%)
              (loop :for ch :across word
                    :collect (? huffman ch))))))
      
