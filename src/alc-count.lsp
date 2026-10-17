(setq *alc-module-version* "3.3.5")
(defun alc--trim-trailing-hyphens (value)
  (while (and (> (strlen value) 0)
              (equal (substr value (strlen value) 1) "-"))
    (setq value (substr value 1 (1- (strlen value))))
  )
  value
)

(defun alc--ask-count-prefix (/ value normalized)
  (setq value
    (getstring T
      (strcat "\nMa dem/tien to <" *alc-count-prefix* ">: "))
        normalized
          (alc--trim-trailing-hyphens
            (vl-string-trim " \t\r\n" value)))
  (if (/= normalized "")
    (progn
      (setq *alc-count-prefix* normalized)
      (alc--save-settings)
    )
  )
  *alc-count-prefix*
)

(defun alc--two-digit-number (value / result)
  (setq result (itoa value))
  (if (< value 10)
    (setq result (strcat "0" result))
  )
  result
)

(defun alc--count-label (prefix index)
  (strcat prefix "-" (alc--two-digit-number index))
)

(defun alc--count-label-size
  (label text-height / bounds lower upper width-value height-value)
  (setq bounds
    (textbox
      (list
        '(0 . "TEXT")
        (cons 1 label)
        (cons 7 (getvar "TEXTSTYLE"))
        (cons 40 text-height)
        '(41 . 1.0))))
  (if (and bounds (car bounds) (cadr bounds))
    (progn
      (setq lower (car bounds)
            upper (cadr bounds)
            width-value (abs (- (car upper) (car lower)))
            height-value (abs (- (cadr upper) (cadr lower))))
    )
  )
  (if (not (and (numberp width-value) (> width-value 1e-9)))
    (setq width-value
      (* text-height (max 2.0 (* 0.7 (strlen label)))))
  )
  (if (not (and (numberp height-value) (> height-value 1e-9)))
    (setq height-value text-height)
  )
  (list width-value height-value)
)

(defun alc--create-centered-text
  (point label text-height
    / normal x-axis-wcs x-axis-ocs rotation wcs-point ocs-point entity)
  (setq normal (trans '(0.0 0.0 1.0) 1 0 T)
        x-axis-wcs (trans '(1.0 0.0 0.0) 1 0 T)
        x-axis-ocs (trans x-axis-wcs 0 normal T)
        rotation (angle '(0.0 0.0 0.0) x-axis-ocs)
        wcs-point (trans point 1 0)
        ocs-point (trans wcs-point 0 normal)
        entity
          (entmakex
            (list
              '(0 . "TEXT")
              '(100 . "AcDbEntity")
              (cons 8 (getvar "CLAYER"))
              '(100 . "AcDbText")
              (cons 10 ocs-point)
              (cons 40 text-height)
              (cons 1 label)
              (cons 50 rotation)
              '(41 . 1.0)
              '(51 . 0.0)
              (cons 7 (getvar "TEXTSTYLE"))
              '(71 . 0)
              '(72 . 1)
              (cons 11 ocs-point)
              (cons 210 normal)
              '(73 . 2))))
  (if entity (entupd entity))
  entity
)

(defun alc--count-frame-points
  (point width-value height-value text-height
    / x y z half-width half-height)
  (setq x (car point)
        y (cadr point)
        z (if (numberp (caddr point)) (caddr point) 0.0)
        half-width (+ (/ width-value 2.0) (* text-height 0.4))
        half-height (+ (/ height-value 2.0) (* text-height 0.3)))
  (list
    (list (- x half-width) (- y half-height) z)
    (list (+ x half-width) (- y half-height) z)
    (list (+ x half-width) (+ y half-height) z)
    (list (- x half-width) (+ y half-height) z))
)

(defun alc--create-count-frame
  (point label text-height / size points normal wcs-points)
  (setq size (alc--count-label-size label text-height)
        points
          (alc--count-frame-points
            point (car size) (cadr size) text-height)
        normal (trans '(0.0 0.0 1.0) 1 0 T)
        wcs-points (mapcar '(lambda (p) (trans p 1 0)) points))
  (alc--create-lwpolyline-wcs-on-layer
    wcs-points T normal (getvar "CLAYER"))
)

(defun alc--place-count-label
  (point label text-height / text-entity frame-entity)
  (setq text-entity
    (alc--track-temp
      (alc--create-centered-text point label text-height)))
  (if text-entity
    (setq frame-entity
      (alc--track-temp
        (alc--create-count-frame point label text-height)))
  )
  (if (and text-entity frame-entity)
    (progn
      (alc--untrack-temp text-entity)
      (alc--untrack-temp frame-entity)
      T
    )
    (progn
      (alc--cleanup-temp)
      nil
    )
  )
)

(defun alc--count-loop (/ prefix text-height index label point done)
  (setq prefix (alc--ask-count-prefix)
        text-height (alc--ask-stat-text-height)
        index 1)
  (while (not done)
    (setq label (alc--count-label prefix index)
          point
            (getpoint
              (strcat "\nChon diem dat " label " <Enter de ket thuc>: ")))
    (if point
      (if (alc--place-count-label point label text-height)
        (setq index (1+ index))
        (progn
          (prompt "\nKhong the tao text va khung dem.")
          (setq done T)
        )
      )
      (setq done T)
    )
  )
  (if (> index 1)
    (prompt
      (strcat
        "\nDa tao "
        (itoa (1- index))
        " ma, tu "
        (alc--count-label prefix 1)
        " den "
        (alc--count-label prefix (1- index))
        "."))
  )
)

;;; --------------------------------------------------------------------------
;;; Sequential TEXT/MTEXT copy

