;;; ALCWALL v3.3.0 - wall module
(defun alc--draw-lintel
  (door-start door-end side-point
    / dx dy segment-length ux uy cross-product side px py z
      inner-start inner-end outer-start outer-end points normal wcs-points
      boundary hatch hatch-ename)
  (setq dx (- (car door-end) (car door-start))
        dy (- (cadr door-end) (cadr door-start))
        segment-length (sqrt (+ (* dx dx) (* dy dy))))
  (if (> segment-length 1e-8)
    (progn
      (setq ux (/ dx segment-length)
            uy (/ dy segment-length)
            cross-product
              (- (* dx (- (cadr side-point) (cadr door-start)))
                 (* dy (- (car side-point) (car door-start))))
            side (if (>= cross-product 0.0) 1.0 -1.0)
            px (* side (- uy))
            py (* side ux)
            z (caddr door-start)
            inner-start
              (list
                (+ (- (car door-start) (* ux 200.0)) (* px 50.0))
                (+ (- (cadr door-start) (* uy 200.0)) (* py 50.0))
                z)
            inner-end
              (list
                (+ (+ (car door-end) (* ux 200.0)) (* px 50.0))
                (+ (+ (cadr door-end) (* uy 200.0)) (* py 50.0))
                z)
            outer-start
              (list
                (+ (- (car door-start) (* ux 200.0)) (* px 200.0))
                (+ (- (cadr door-start) (* uy 200.0)) (* py 200.0))
                z)
            outer-end
              (list
                (+ (+ (car door-end) (* ux 200.0)) (* px 200.0))
                (+ (+ (cadr door-end) (* uy 200.0)) (* py 200.0))
                z)
            points (list inner-start inner-end outer-end outer-start)
            normal (trans '(0.0 0.0 1.0) 1 0 T)
            wcs-points (mapcar '(lambda (p) (trans p 1 0)) points)
            boundary
              (alc--track-temp
                (alc--create-lwpolyline-wcs-on-layer
                  wcs-points T normal (getvar "CLAYER"))))
      (if boundary
        (progn
          (setq hatch
                  (alc--make-hatch-with-settings
                    boundary "ANSI31" 4 10.0 nil)
                hatch-ename (alc--vla-object-ename hatch))
          (if hatch-ename (alc--track-temp hatch-ename))
          (if hatch
            (progn
              (alc--untrack-temp boundary)
              (alc--untrack-temp hatch-ename)
              (prompt
                (strcat
                  "\nDa ve lanh to. Chieu dai="
                  (rtos (+ segment-length 400.0) 2 0)
                  " mm, rong=150 mm, khoang cach=50 mm, hatch ANSI31 scale=10."))
              T)
            (progn
              (alc--cleanup-temp)
              (prompt "\nKhong the tao hatch lanh to.")
              nil)))
        (progn
          (prompt "\nKhong the tao hinh bao lanh to.")
          nil))
    )
    (progn
      (prompt "\nHai diem cua phai khac nhau.")
      nil)
  )
)

(defun alc--lintel-loop (/ door-start door-end side-point)
  (if (setq door-start (getpoint "\nChon diem dau cua: "))
    (progn
      (initget 1)
      (setq door-end (getpoint door-start "\nChon diem cuoi cua: "))
      (if (> (distance door-start door-end) 1e-8)
        (progn
          (initget 1)
          (setq side-point
            (getpoint door-start "\nChon ben ve lanh to: "))
          (alc--draw-lintel door-start door-end side-point))
        (prompt "\nHai diem cua phai khac nhau."))
    )
  )
)

(defun alc--draw-wall-tie
  (tie-start tie-end side-point tie-width tie-color
    / dx dy segment-length ux uy cross-product side-offset side px py z
      tie-gap
      inner-start inner-end outer-start outer-end points normal wcs-points
      boundary hatch hatch-ename)
  (setq dx (- (car tie-end) (car tie-start))
        dy (- (cadr tie-end) (cadr tie-start))
        segment-length (sqrt (+ (* dx dx) (* dy dy))))
  (if (> segment-length 1e-8)
    (progn
      (setq ux (/ dx segment-length)
            uy (/ dy segment-length)
            cross-product
              (- (* dx (- (cadr side-point) (cadr tie-start)))
                 (* dy (- (car side-point) (car tie-start))))
            side-offset (/ cross-product segment-length)
            side
              (cond
                ((> side-offset 1e-6) 1.0)
                ((< side-offset -1e-6) -1.0)
              )
            px (if side (* side (- uy)) 0.0)
            py (if side (* side ux) 0.0)
            z (caddr tie-start)
            tie-gap 50.0
            inner-start
              (list
                (+ (car tie-start) (* px tie-gap))
                (+ (cadr tie-start) (* py tie-gap))
                z)
            inner-end
              (list
                (+ (car tie-end) (* px tie-gap))
                (+ (cadr tie-end) (* py tie-gap))
                z)
            outer-start
              (list
                (+ (car tie-start) (* px (+ tie-gap tie-width)))
                (+ (cadr tie-start) (* py (+ tie-gap tie-width)))
                z)
            outer-end
              (list
                (+ (car tie-end) (* px (+ tie-gap tie-width)))
                (+ (cadr tie-end) (* py (+ tie-gap tie-width)))
                z)
            points (list inner-start inner-end outer-end outer-start)
            normal (trans '(0.0 0.0 1.0) 1 0 T)
            wcs-points (mapcar '(lambda (p) (trans p 1 0)) points)
            boundary
              (if side
                (alc--track-temp
                  (alc--create-lwpolyline-wcs-on-layer
                    wcs-points T normal (getvar "CLAYER")))))
      (cond
        ((not side)
          (prompt
            "\nDiem chon ben dang nam tren duong tham chieu. Hay chon lech sang ben can ve.")
          nil)
        (boundary
          (setq hatch
                  (alc--make-hatch-with-settings
                    boundary "ANSI31" tie-color 10.0 nil)
                hatch-ename (alc--vla-object-ename hatch))
          (if hatch-ename (alc--track-temp hatch-ename))
          (if hatch
            (progn
              (alc--untrack-temp boundary)
              (alc--untrack-temp hatch-ename)
              (prompt
                (strcat
                  "\nDa ve giang tuong. Chieu dai="
                  (rtos segment-length 2 0)
                  " mm, rong="
                  (rtos tie-width 2 0)
                  " mm, khoang cach="
                  (rtos tie-gap 2 0)
                  " mm, hatch ANSI31 scale=10, mau ACI "
                  (itoa tie-color)
                  "."))
              T)
            (progn
              (alc--cleanup-temp)
              (prompt "\nKhong the tao hatch giang tuong.")
              nil)))
        (T
          (prompt "\nKhong the tao hinh bao giang tuong.")
          nil))
    )
    (progn
      (prompt "\nHai diem giang tuong phai khac nhau.")
      nil)
  )
)

(defun alc--wall-tie-loop
  (/ tie-width tie-color tie-start tie-end side-point)
  (prompt
    (strcat
      "\nALCGT - Chieu rong="
      (rtos *alc-wall-tie-width* 2 0)
      " mm, mau ACI "
      (itoa *alc-wall-tie-color*)
      "."))
  (setq tie-width *alc-wall-tie-width*
        tie-color *alc-wall-tie-color*)
  (if (setq tie-start (getpoint "\nChon diem dau giang tuong: "))
    (progn
      (initget 1)
      (setq tie-end
        (getpoint tie-start "\nChon diem cuoi giang tuong: "))
      (if (> (distance tie-start tie-end) 1e-8)
        (progn
          (initget 1)
          (setq side-point
            (getpoint tie-start "\nChon ben the hien giang tuong: "))
          (alc--draw-wall-tie
            tie-start tie-end side-point tie-width tie-color))
        (prompt "\nHai diem giang tuong phai khac nhau."))
    )
  )
)

(defun alc--wall-tie-settings-loop (/ tie-width selected-color)
  (prompt
    (strcat
      "\nALCGTS - Hien tai: chieu rong="
      (rtos *alc-wall-tie-width* 2 0)
      " mm, mau ACI "
      (itoa *alc-wall-tie-color*)
      "."))
  (initget 6)
  (setq tie-width
    (getdist
      (strcat
        "\nChon chieu rong giang tuong <"
        (rtos *alc-wall-tie-width* 2 0)
        ">: ")))
  (if tie-width
    (setq *alc-wall-tie-width* tie-width)
  )
  (setq selected-color
    (acad_colordlg *alc-wall-tie-color* nil))
  (if selected-color
    (setq *alc-wall-tie-color* selected-color)
  )
  (prompt
    (strcat
      "\nDa dat ALCGT: chieu rong="
      (rtos *alc-wall-tie-width* 2 0)
      " mm, mau ACI "
      (itoa *alc-wall-tie-color*)
      "."))
)


;;; --------------------------------------------------------------------------
;;; Hatch and wall creation

(defun alc--get-active-document ()
  (vla-get-ActiveDocument (vlax-get-acad-object))
)

(defun alc--owner-space (boundary / owner)
  (if (setq owner (cdr (assoc 330 (entget boundary))))
    (vlax-ename->vla-object owner)
  )
)

(defun alc--add-hatch-object (boundary pattern)
  (vla-AddHatch
    (alc--owner-space boundary) 0 pattern :vlax-true 0)
)

(defun alc--append-hatch-loop (hatch boundary / outer-loop)
  (setq outer-loop (vlax-make-safearray vlax-vbObject '(0 . 0)))
  (vlax-safearray-put-element
    outer-loop 0 (vlax-ename->vla-object boundary))
  (vla-AppendOuterLoop hatch outer-loop)
)

(defun alc--set-hatch-background (hatch background-color / color-object)
  (cond
    ((= background-color 0)
      hatch)
    ((= background-color 256)
      (setq color-object (vla-get-BackgroundColor hatch))
      (vla-SetRGB color-object 255 255 255)
      (vla-put-BackgroundColor hatch color-object)
      (vl-catch-all-apply 'vlax-release-object (list color-object))
      hatch)
    ((alc--valid-color-p background-color)
      (setq color-object (vla-get-BackgroundColor hatch))
      (vla-put-ColorIndex color-object background-color)
      (vla-put-BackgroundColor hatch color-object)
      (vl-catch-all-apply 'vlax-release-object (list color-object))
      hatch)
  )
)

(defun alc--finish-hatch (hatch scale color background-color hatch-angle)
  (vla-put-PatternScale hatch scale)
  (vla-put-PatternAngle hatch hatch-angle)
  (vla-put-Color hatch color)
  (alc--set-hatch-background hatch background-color)
  (vla-Evaluate hatch)
  hatch
)

(defun alc--bring-boundary-to-front (boundary / result)
  ;; The hatch is created after its boundary, so many CAD hosts display it on
  ;; top of the polyline. Keep the wall outline visible by explicitly moving
  ;; the boundary to the front after the hatch has been evaluated.
  (setq result
    (vl-catch-all-apply
      'vl-cmdf (list "_.DRAWORDER" boundary "" "_Front")))
  (if (vl-catch-all-error-p result)
    (prompt
      (strcat
        "\nWall created, but its boundary could not be moved above the hatch: "
        (vl-catch-all-error-message result)))
  )
  (not (vl-catch-all-error-p result))
)

(defun alc--make-hatch-with-angle
  (boundary pattern color scale background-color hatch-angle / hatch result)
  (setq hatch
    (vl-catch-all-apply
      'alc--add-hatch-object
      (list boundary pattern))
  )
  (if (vl-catch-all-error-p hatch)
    (progn
      (prompt
        (strcat
          "\nBoundary created, but hatch creation failed: "
          (vl-catch-all-error-message hatch)))
      nil
    )
    (progn
      (setq result
        (vl-catch-all-apply 'alc--append-hatch-loop (list hatch boundary)))
      (if (vl-catch-all-error-p result)
        (progn
          (vl-catch-all-apply 'vla-Delete (list hatch))
          (prompt
            (strcat
              "\nBoundary created, but the hatch loop failed: "
              (vl-catch-all-error-message result)))
          nil
        )
        (progn
          (setq result
            (vl-catch-all-apply
              'alc--finish-hatch
              (list hatch scale color background-color hatch-angle)))
          (if (vl-catch-all-error-p result)
            (progn
              (vl-catch-all-apply 'vla-Delete (list hatch))
              (prompt
                (strcat
                  "\nBoundary created, but hatch settings failed: "
                  (vl-catch-all-error-message result)))
              nil
            )
            (progn
              (alc--bring-boundary-to-front boundary)
              hatch
            )
          )
        )
      )
    )
  )
)

;; Preserve the fixed zero-angle API used by lintels, wall ties and old callers.
(defun alc--make-hatch-with-settings (boundary pattern color scale background-color)
  (alc--make-hatch-with-angle boundary pattern color scale background-color 0.0)
)

(defun alc--make-hatch (boundary)
  (alc--make-hatch-with-angle
    boundary *alc-pattern* *alc-color* *alc-scale*
    *alc-background-color* *alc-angle*)
)

(defun alc--read-hatch-background-unsafe
  (object / color-object color-method color-index red green blue result)
  (setq color-object (vla-get-BackgroundColor object)
        color-method (vla-get-ColorMethod color-object)
        color-index (vla-get-ColorIndex color-object)
        red (vla-get-Red color-object)
        green (vla-get-Green color-object)
        blue (vla-get-Blue color-object)
        result
          (cond
            ;; acColorMethodByRGB = 194. Keep true white distinct from ACI 7.
            ((and (= color-method 194)
                  (= red 255) (= green 255) (= blue 255))
              256)
            ((alc--valid-color-p color-index) color-index)
            (T 0)))
  (vl-catch-all-apply 'vlax-release-object (list color-object))
  result
)

(defun alc--read-hatch-background (object / result)
  (setq result
    (vl-catch-all-apply 'alc--read-hatch-background-unsafe (list object)))
  (if (and (not (vl-catch-all-error-p result))
           (alc--valid-background-color-p result))
    result
    0
  )
)

(defun alc--read-hatch-settings-unsafe (hatch / object)
  (setq object (vlax-ename->vla-object hatch))
  (list
    (vla-get-PatternName object)
    (vla-get-Color object)
    (vla-get-PatternScale object)
    (alc--read-hatch-background object)
    (vla-get-PatternAngle object))
)

(defun alc--read-hatch-settings (hatch / result)
  (if hatch
    (progn
      (setq result
        (vl-catch-all-apply
          'alc--read-hatch-settings-unsafe (list hatch)))
      (if (not (vl-catch-all-error-p result))
        result
      )
    )
  )
)

(defun alc--draw-wall (first-point / points edge side-point offset boundary hatch)
  (if (setq points (alc--ask-points first-point))
    (if (setq edge
          (alc--track-temp (alc--create-open-polyline points)))
      (progn
        (setq side-point
          (getpoint "\nPick offset side <Enter = previous side>: "))
        (if (not side-point)
          (setq side-point (alc--default-side-point edge))
        )
        (if side-point
          (if (setq offset
                (alc--track-temp (alc--offset edge side-point)))
            (if (setq boundary (alc--make-closed-polyline edge offset))
              (progn
                (setq *alc-last-side* (alc--side-of-offset edge offset))
                (alc--cleanup-temp)
                (setq hatch (alc--make-hatch boundary))
                (alc--save-settings)
                (if hatch
                  (prompt "\nALC wall and hatch created.")
                  (prompt "\nALC wall boundary created without hatch."))
                T
              )
              (progn
                (alc--cleanup-temp)
                (prompt "\nCould not create the closed wall boundary.")
                nil
              )
            )
            (progn
              (alc--cleanup-temp)
              nil
            )
          )
          (progn
            (alc--cleanup-temp)
            (prompt "\nNo valid offset side was found.")
            nil
          )
        )
      )
      (progn
        (prompt "\nCould not create the temporary wall polyline.")
        nil
      )
    )
  )
)

(defun alc--draw-central-wall
  (first-point
    / points centerline half-thickness side-a side-b
      offset-a offset-b boundary hatch)
  (if (setq points (alc--ask-points first-point))
    (if (setq centerline
          (alc--track-temp (alc--create-open-polyline points)))
      (progn
        (setq half-thickness (/ *alc-thickness* 2.0)
              side-a (alc--side-point centerline 1 half-thickness)
              side-b (alc--side-point centerline -1 half-thickness))
        (if (and side-a side-b)
          (if (setq offset-a
                (alc--track-temp
                  (alc--offset-distance
                    centerline side-a half-thickness)))
            (if (setq offset-b
                  (alc--track-temp
                    (alc--offset-distance
                      centerline side-b half-thickness)))
              (if (setq boundary
                    (alc--make-closed-polyline offset-a offset-b))
                (progn
                  (alc--cleanup-temp)
                  (setq hatch (alc--make-hatch boundary))
                  (alc--save-settings)
                  (if hatch
                    (prompt "\nCentral ALC wall and hatch created.")
                    (prompt
                      "\nCentral ALC wall boundary created without hatch."))
                  T
                )
                (progn
                  (alc--cleanup-temp)
                  (prompt
                    "\nCould not create the closed central wall boundary.")
                  nil
                )
              )
              (progn
                (alc--cleanup-temp)
                nil
              )
            )
            (progn
              (alc--cleanup-temp)
              nil
            )
          )
          (progn
            (alc--cleanup-temp)
            (prompt "\nCould not determine both sides of the centerline.")
            nil
          )
        )
      )
      (progn
        (alc--cleanup-temp)
        (prompt "\nCould not create the temporary centerline polyline.")
        nil
      )
    )
  )
)

(defun alc--draw-door-opening
  (wall point-1 point-2
    / polygon layer normal base-axis raw-direction direction-dot axis
      projected-distance p1-wcs p2-wcs p3-wcs split-polygons polygon-a polygon-b
      boundary-a boundary-b hatch-a hatch-b hatch-a-ename hatch-b-ename
      old-hatches old-hatch hatch-settings hatch-pattern hatch-color hatch-scale
      hatch-background-color hatch-angle)
  (setq polygon
    (alc--clean-polygon-points (alc--lwp-points wall)))
  (cond
    ((< (length polygon) 4)
      (prompt
        "\nThe selected wall boundary has too few vertices.")
      nil
    )
    ((setq layer (cdr (assoc 8 (entget wall))))
      (if (alc--layer-locked-p layer)
        (progn
          (prompt "\nThe wall layer is locked. Unlock it before adding an opening.")
          nil
        )
        (progn
          (setq normal
            (if (assoc 210 (entget wall))
              (cdr (assoc 210 (entget wall)))
              '(0.0 0.0 1.0))
          )
          (setq p1-wcs (trans point-1 1 0)
                raw-direction
                  (alc--vector-subtract (trans point-2 1 0) p1-wcs))
          (setq base-axis
            (alc--best-edge-axis polygon raw-direction))
          (if (and base-axis (> (alc--vector-length raw-direction) 1e-8))
            (progn
              (setq direction-dot (alc--vector-dot raw-direction base-axis))
              (if (< direction-dot 0.0)
                (setq axis (alc--vector-scale base-axis -1.0)
                      direction-dot (- direction-dot))
                (setq axis base-axis)
              )
              (if (> direction-dot 1e-8)
                (progn
                  (setq projected-distance direction-dot
                        p2-wcs
                          (alc--vector-add
                            p1-wcs
                            (alc--vector-scale axis projected-distance))
                        p3-wcs
                          (alc--vector-add
                            p2-wcs
                            (alc--vector-scale axis *alc-door-width*))
                        split-polygons
                          (alc--split-opening-polygons
                            polygon axis p2-wcs p3-wcs))
                  (if split-polygons
                    (progn
                      (alc--track-temp
                        (alc--create-preview-line
                          (trans p1-wcs 0 1) (trans p2-wcs 0 1)))
                      (alc--track-temp
                        (alc--create-preview-line
                          (trans p2-wcs 0 1) (trans p3-wcs 0 1)))
                      (setq polygon-a (car split-polygons)
                            polygon-b (cadr split-polygons))
                      (if (and (>= (length polygon-a) 3)
                               (>= (length polygon-b) 3))
                        (progn
                          (setq boundary-a
                            (alc--track-temp
                              (alc--create-lwpolyline-wcs-on-layer
                                polygon-a T normal layer))
                            boundary-b
                              (alc--track-temp
                                (alc--create-lwpolyline-wcs-on-layer
                                  polygon-b T normal layer)))
                          (if (and boundary-a boundary-b)
                            (progn
                              (setq old-hatches
                                (alc--find-boundary-hatches wall))
                              (setq hatch-settings
                                (alc--read-hatch-settings (car old-hatches)))
                              (if (not hatch-settings)
                                (setq hatch-settings
                                  (list
                                    *alc-pattern* *alc-color* *alc-scale*
                                    *alc-background-color* *alc-angle*))
                              )
                              (setq hatch-pattern (car hatch-settings)
                                    hatch-color (cadr hatch-settings)
                                    hatch-scale (caddr hatch-settings)
                                    hatch-background-color
                                      (cadddr hatch-settings)
                                    hatch-angle (nth 4 hatch-settings)
                                    hatch-a
                                      (alc--make-hatch-with-angle
                                        boundary-a hatch-pattern
                                        hatch-color hatch-scale
                                        hatch-background-color hatch-angle)
                                    hatch-b
                                      (alc--make-hatch-with-angle
                                        boundary-b hatch-pattern
                                        hatch-color hatch-scale
                                        hatch-background-color hatch-angle)
                                hatch-a-ename (alc--vla-object-ename hatch-a)
                                hatch-b-ename (alc--vla-object-ename hatch-b))
                              (if hatch-a-ename
                                (alc--track-temp hatch-a-ename)
                              )
                              (if hatch-b-ename
                                (alc--track-temp hatch-b-ename)
                              )
                              (if (and hatch-a hatch-b
                                       hatch-a-ename hatch-b-ename)
                                (progn
                                  (alc--put-object-layer hatch-a layer)
                                  (alc--put-object-layer hatch-b layer)
                                  (if (entdel wall)
                                    (progn
                                      (alc--untrack-temp boundary-a)
                                      (alc--untrack-temp boundary-b)
                                      (alc--untrack-temp hatch-a-ename)
                                      (alc--untrack-temp hatch-b-ename)
                                      (foreach old-hatch old-hatches
                                        (if (entget old-hatch)
                                          (entdel old-hatch)
                                        )
                                      )
                                      (alc--cleanup-temp)
                                      (prompt
                                        (strcat
                                          "\nALC opening created. Width="
                                          (rtos *alc-door-width* 2 0)
                                          "."))
                                      T
                                    )
                                    (progn
                                      (alc--cleanup-temp)
                                      (prompt
                                        "\nCould not replace the original wall.")
                                      nil
                                    )
                                  )
                                )
                                (progn
                                  (if (and hatch-a (not hatch-a-ename))
                                    (vl-catch-all-apply
                                      'vla-Delete (list hatch-a))
                                  )
                                  (if (and hatch-b (not hatch-b-ename))
                                    (vl-catch-all-apply
                                      'vla-Delete (list hatch-b))
                                  )
                                  (alc--cleanup-temp)
                                  (prompt
                                    "\nCould not create both replacement hatches. The original wall was kept.")
                                  nil
                                )
                              )
                            )
                            (progn
                              (alc--cleanup-temp)
                              (prompt
                                "\nCould not create both replacement wall segments.")
                              nil
                            )
                          )
                        )
                        (progn
                          (alc--cleanup-temp)
                          (prompt "\nThe opening produced invalid wall geometry.")
                          nil
                        )
                      )
                    )
                    (progn
                      (prompt
                        "\nCould not find two valid local wall intersections at P2 and P3.")
                      nil
                    )
                  )
                )
                (progn
                  (prompt "\nP2 must be offset from P1 along the wall direction.")
                  nil
                )
              )
            )
            (progn
              (prompt "\nCould not determine the wall direction.")
              nil
            )
          )
        )
      )
    )
    (T
      (prompt "\nThe selected wall has no valid layer.")
      nil
    )
  )
)

(defun alc--wall-loop (/ answer done)
  (while (not done)
    (prompt (alc--status))
    (initget "Thickness Settings")
    (setq answer (getpoint "\nFirst point or [Thickness/Settings]: "))
    (cond
      ((not answer) (setq done T))
      ((alc--point-p answer)
        (alc--draw-wall answer)
        (setq done T)
      )
      ((equal answer "Thickness") (alc--set-thickness))
      ((equal answer "Settings") (alc--settings))
      (T
        (prompt "\nInvalid input.")
        (setq done T)
      )
    )
  )
)

(defun alc--door-loop (/ selection wall point-1 point-2)
  (alc--ask-door-width)
  (if (setq selection
        (entsel "\nSelect an ALC wall or its hatch: "))
    (progn
      (setq wall (alc--resolve-wall (car selection)))
      (if wall
        (if (setq point-1 (getpoint "\nReference point P1: "))
          (progn
            (initget 1)
            (setq point-2
              (getpoint point-1
                "\nOpening start P2 (offset and direction from P1): "))
            (if point-2
              (alc--draw-door-opening wall point-1 point-2)
            )
          )
        )
        (prompt
          "\nNo supported closed ALC wall boundary was found.")
      )
    )
  )
)

(defun alc--central-loop (/ answer done)
  (while (not done)
    (prompt (alc--status))
    (initget "Thickness Settings")
    (setq answer
      (getpoint "\nFirst center point or [Thickness/Settings]: "))
    (cond
      ((not answer) (setq done T))
      ((alc--point-p answer)
        (alc--draw-central-wall answer)
        (setq done T)
      )
      ((equal answer "Thickness") (alc--set-thickness))
      ((equal answer "Settings") (alc--settings))
      (T
        (prompt "\nInvalid input.")
        (setq done T)
      )
    )
  )
)
