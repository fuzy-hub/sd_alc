(setq *alc-module-version* "3.3.6")
;;; ALCWALL v3.3.6 - alignment module

;;; --------------------------------------------------------------------------
;;; Text alignment

(defun alc--object-bounds-unsafe (object / minimum maximum)
  (vla-GetBoundingBox object 'minimum 'maximum)
  (list
    (vlax-safearray->list minimum)
    (vlax-safearray->list maximum))
)

(defun alc--object-bounds (entity / object result)
  (setq object
    (vl-catch-all-apply 'vlax-ename->vla-object (list entity)))
  (if (not (vl-catch-all-error-p object))
    (progn
      (setq result
        (vl-catch-all-apply 'alc--object-bounds-unsafe (list object)))
      (if (not (vl-catch-all-error-p result)) result)
    )
  )
)

(defun alc--bounds-corners (minimum maximum / min-x min-y min-z max-x max-y max-z)
  (setq min-x (car minimum)
        min-y (cadr minimum)
        min-z (caddr minimum)
        max-x (car maximum)
        max-y (cadr maximum)
        max-z (caddr maximum))
  (list
    (list min-x min-y min-z)
    (list min-x max-y min-z)
    (list max-x min-y min-z)
    (list max-x max-y min-z)
    (list min-x min-y max-z)
    (list min-x max-y max-z)
    (list max-x min-y max-z)
    (list max-x max-y max-z))
)


(defun alc--measure-text-ucs (object / x y z origin matrix bounds)
  (setq x (trans '(1.0 0.0 0.0) 1 0 T)
        y (trans '(0.0 1.0 0.0) 1 0 T)
        z (trans '(0.0 0.0 1.0) 1 0 T)
        origin (trans '(0.0 0.0 0.0) 0 1)
        matrix (vlax-tmatrix (list
          (append x (list (car origin))) (append y (list (cadr origin)))
          (append z (list (caddr origin))) '(0.0 0.0 0.0 1.0))))
  (vla-TransformBy object matrix)
  (setq bounds (alc--object-bounds-unsafe object))
  (caar bounds))

(defun alc--text-left-x-ucs (entity / object copy result layer copy-ename)
  ;; Locked reference objects are measured without modifying their layer state.
  (setq object (vl-catch-all-apply 'vlax-ename->vla-object (list entity)))
  (if (not (vl-catch-all-error-p object))
    (progn
      (setq copy (vl-catch-all-apply 'vla-Copy (list object)))
      (if (not (vl-catch-all-error-p copy))
        (progn
          (setq copy-ename (alc--track-temp (vlax-vla-object->ename copy)))
          (setq layer (tblnext "LAYER" T))
          (while (and layer (alc--layer-locked-p (cdr (assoc 2 layer)))) (setq layer (tblnext "LAYER")))
          (setq result (vl-catch-all-apply 'alc--measure-unlocked-text (list copy layer)))
          (vl-catch-all-apply 'vla-Delete (list copy))
          (if (not (entget copy-ename)) (alc--untrack-temp copy-ename))
          (vlax-release-object copy)
          (if (not (vl-catch-all-error-p result)) result))))))

(defun alc--measure-unlocked-text (object layer)
  (if layer (progn (vla-put-Layer object (cdr (assoc 2 layer))) (alc--measure-text-ucs object))))

(defun alc--move-text-left-to-ucs-x
  (entity target-x / current-x delta-ucs delta-wcs object result)
  (if (setq current-x (alc--text-left-x-ucs entity))
    (progn
      (setq delta-ucs (list (- target-x current-x) 0.0 0.0)
            delta-wcs (trans delta-ucs 1 0 T))
      (if (< (abs (car delta-ucs)) 1e-9)
        T
        (progn
          (setq object
            (vl-catch-all-apply
              'vlax-ename->vla-object (list entity)))
          (if (vl-catch-all-error-p object)
            nil
            (progn
              (setq result
                (vl-catch-all-apply
                  'vla-Move
                  (list
                    object
                    (vlax-3d-point '(0.0 0.0 0.0))
                    (vlax-3d-point delta-wcs))))
              (not (vl-catch-all-error-p result))
            )
          )
        )
      )
    )
  )
)

(defun alc--text-align-loop
  (/ selection reference reference-entity reference-data target-x
    index entity aligned-count failed-count)
  (prompt "\nChon cac TEXT/MTEXT can canh le trai: ")
  (if (setq selection (ssget '((0 . "TEXT,MTEXT"))))
    (if (setq reference (entsel "\nChon TEXT/MTEXT tham chieu le trai: "))
      (progn
        (setq reference-entity (car reference)
              reference-data (entget reference-entity))
        (if (and reference-data
                 (member (cdr (assoc 0 reference-data)) '("TEXT" "MTEXT"))
                 (setq target-x
                   (alc--text-left-x-ucs reference-entity)))
          (progn
            (setq index 0
                  aligned-count 0
                  failed-count 0)
            (repeat (sslength selection)
              (setq entity (ssname selection index)
                    index (1+ index))
              (if (equal entity reference-entity)
                nil
                (if (alc--move-text-left-to-ucs-x entity target-x)
                  (setq aligned-count (1+ aligned-count))
                  (setq failed-count (1+ failed-count))
                )
              )
            )
            (prompt
              (strcat
                "\nTKALIGN: da canh le trai "
                (itoa aligned-count)
                " text theo text tham chieu"
                (if (> failed-count 0)
                  (strcat ", loi " (itoa failed-count) " text.")
                  ".")))
            (> aligned-count 0)
          )
          (progn
            (prompt "\nDoi tuong tham chieu phai la TEXT hoac MTEXT.")
            nil
          )
        )
      )
    )
  )
)

(princ)
