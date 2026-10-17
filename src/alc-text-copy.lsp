(setq *alc-module-version* "3.3.5")
(defun alc--three-digit-number (value / result)
  (setq result (itoa value))
  (cond
    ((< value 10) (strcat "00" result))
    ((< value 100) (strcat "0" result))
    (T result)
  )
)

(defun alc--numbered-text-parts (value / length-value suffix digits)
  (setq length-value (strlen value))
  (if (>= length-value 4)
    (setq suffix (substr value (- length-value 3) 4)
          digits (substr suffix 2 3))
  )
  (if (and suffix
           (= (substr suffix 1 1) "-")
           (wcmatch digits "[0-9][0-9][0-9]"))
    (list (substr value 1 (- length-value 4)) (1+ (atoi digits)))
    (list value 1)
  )
)

(defun alc--tkms-copy-one
  (source base-wcs target-wcs new-text
    / copied copy-result copied-ename move-result text-result)
  (setq copy-result (vl-catch-all-apply 'vla-Copy (list source)))
  (if (not (vl-catch-all-error-p copy-result))
    (progn
      (setq copied copy-result
            copied-ename (vlax-vla-object->ename copied))
      (alc--track-temp copied-ename)
      (setq move-result
        (vl-catch-all-apply
          'vla-Move
          (list copied
                (vlax-3d-point base-wcs)
                (vlax-3d-point target-wcs))))
      (if (not (vl-catch-all-error-p move-result))
        (setq text-result
          (vl-catch-all-apply
            'vla-put-TextString (list copied new-text)))
      )
      (if (and (not (vl-catch-all-error-p move-result))
               (not (vl-catch-all-error-p text-result)))
        copied-ename
      )
    )
  )
)

(defun alc--tkms-index-valid-p (items offset / item valid)
  (setq valid T)
  (foreach item items
    (if (> (+ (caddr item) offset) 999)
      (setq valid nil)
    )
  )
  valid
)

(defun alc--tkms-loop
  (/ selection base-point base-wcs items position entity object parts
     target-point target-wcs offset item number-value copied created done)
  (prompt "\nChon TEXT/MTEXT can copy va danh so: ")
  (setq selection
    (ssget "_:L" '((0 . "TEXT,MTEXT"))))
  (if selection
    (progn
      (setq position 0
            items nil)
      (while (< position (sslength selection))
        (setq entity (ssname selection position)
              object (vlax-ename->vla-object entity)
              parts (alc--numbered-text-parts (vla-get-TextString object))
              items
                (cons (list object (car parts) (cadr parts)) items)
              position (1+ position))
      )
      (setq items (reverse items)
            base-point (getpoint "\nChon diem goc: "))
      (if base-point
        (progn
          (setq base-wcs (trans base-point 1 0)
                offset 0)
          (while (not done)
            (if (alc--tkms-index-valid-p items offset)
              (progn
                (setq target-point
                  (getpoint base-point
                    (strcat
                      "\nChon diem dat ban sao so "
                      (alc--three-digit-number
                        (+ (caddr (car items)) offset))
                      " <Enter de ket thuc>: ")))
                (if target-point
                  (progn
                    (setq target-wcs (trans target-point 1 0)
                          created nil
                          copied T)
                    (foreach item items
                      (setq number-value (+ (caddr item) offset)
                            entity
                              (alc--tkms-copy-one
                                (car item) base-wcs target-wcs
                                (strcat
                                  (cadr item) "-"
                                  (alc--three-digit-number number-value))))
                      (if entity
                        (setq created (cons entity created))
                        (setq copied nil)
                      )
                    )
                    (if copied
                      (progn
                        (foreach entity created
                          (alc--untrack-temp entity)
                        )
                        (setq offset (1+ offset))
                      )
                      (progn
                        (prompt "\nKhong the copy hoac cap nhat noi dung text.")
                        (alc--cleanup-temp)
                        (setq done T)
                      )
                    )
                  )
                  (setq done T)
                )
              )
              (progn
                (prompt "\nDa dat den hau to toi da -999.")
                (setq done T)
              )
            )
          )
          (if (> offset 0)
            (prompt
              (strcat "\nTKMS da tao " (itoa offset) " lan copy."))
          )
        )
      )
    )
    (prompt "\nKhong co TEXT/MTEXT hop le duoc chon.")
  )
)
