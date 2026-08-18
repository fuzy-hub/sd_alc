;;; ALCWALL v2.1.0 - alignment module

;;; --------------------------------------------------------------------------
;;; Text alignment

(defun alc--variant-point-list (value / raw result)
  (if (= (type value) 'VARIANT)
    (setq raw (vlax-variant-value value))
    (setq raw value)
  )
  (cond
    ((= (type raw) 'SAFEARRAY)
      (setq result
        (vl-catch-all-apply 'vlax-safearray->list (list raw)))
      (if (not (vl-catch-all-error-p result)) result)
    )
    ((listp raw) raw)
  )
)

(defun alc--object-point-property (object property / result)
  (setq result
    (vl-catch-all-apply 'vlax-get-property (list object property)))
  (if (not (vl-catch-all-error-p result))
    (alc--variant-point-list result)
  )
)

(defun alc--text-anchor-wcs (entity / data entity-type object horizontal vertical)
  (if (and entity (setq data (entget entity)))
    (progn
      (setq entity-type (cdr (assoc 0 data))
            object
              (vl-catch-all-apply 'vlax-ename->vla-object (list entity)))
      (if (vl-catch-all-error-p object)
        nil
        (cond
          ((equal entity-type "MTEXT")
            (alc--object-point-property object 'InsertionPoint)
          )
          ((equal entity-type "TEXT")
            (setq horizontal (cdr (assoc 72 data))
                  vertical (cdr (assoc 73 data)))
            (if (and (or (not horizontal) (= horizontal 0))
                     (or (not vertical) (= vertical 0)))
              (alc--object-point-property object 'InsertionPoint)
              (alc--object-point-property object 'TextAlignmentPoint)
            )
          )
        )
      )
    )
  )
)

(defun alc--move-text-to-ucs-x
  (entity target-x / anchor anchor-ucs delta-ucs delta-wcs object result)
  (if (setq anchor (alc--text-anchor-wcs entity))
    (progn
      (setq anchor-ucs (trans anchor 0 1)
            delta-ucs (list (- target-x (car anchor-ucs)) 0.0 0.0)
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
  (/ selection reference reference-entity reference-data reference-anchor
    target-x index entity aligned-count failed-count)
  (prompt "\nChon cac TEXT/MTEXT can canh thang dung: ")
  (if (setq selection (ssget '((0 . "TEXT,MTEXT"))))
    (if (setq reference (entsel "\nChon TEXT/MTEXT tham chieu: "))
      (progn
        (setq reference-entity (car reference)
              reference-data (entget reference-entity))
        (if (and reference-data
                 (member (cdr (assoc 0 reference-data)) '("TEXT" "MTEXT"))
                 (setq reference-anchor
                   (alc--text-anchor-wcs reference-entity)))
          (progn
            (setq target-x (car (trans reference-anchor 0 1))
                  index 0
                  aligned-count 0
                  failed-count 0)
            (repeat (sslength selection)
              (setq entity (ssname selection index)
                    index (1+ index))
              (if (equal entity reference-entity)
                nil
                (if (alc--move-text-to-ucs-x entity target-x)
                  (setq aligned-count (1+ aligned-count))
                  (setq failed-count (1+ failed-count))
                )
              )
            )
            (prompt
              (strcat
                "\nTKALIGN: da canh "
                (itoa aligned-count)
                " text theo truc X cua text tham chieu"
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
