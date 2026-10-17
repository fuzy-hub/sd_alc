(setq *alc-module-version* "3.3.6")
;;; ALCWALL v3.3.6 - geometry module

;;; --------------------------------------------------------------------------
;;; Geometry helpers

(defun alc--point-p (value)
  (and (listp value)
       (numberp (car value))
       (numberp (cadr value)))
)

(defun alc--lwpolyline-p (ename)
  (and ename
       (entget ename)
       (equal (cdr (assoc 0 (entget ename))) "LWPOLYLINE"))
)

(defun alc--track-temp (ename)
  (if ename
    (setq *alc-temp-entities* (cons ename *alc-temp-entities*))
  )
  ename
)

(defun alc--untrack-temp (ename)
  (if ename
    (setq *alc-temp-entities*
      (vl-remove ename *alc-temp-entities*))
  )
  ename
)

(defun alc--cleanup-temp (/ ename)
  (foreach ename *alc-temp-entities*
    (if (and ename (entget ename))
      (entdel ename)
    )
  )
  (setq *alc-temp-entities* nil)
  (princ)
)

(defun alc--create-preview-line (point-a point-b / ename)
  (setq ename
    (entmakex
      (list
        '(0 . "LINE")
        '(100 . "AcDbEntity")
        (cons 8 (getvar "CLAYER"))
        '(100 . "AcDbLine")
        (cons 10 (trans point-a 1 0))
        (cons 11 (trans point-b 1 0))
      )
    )
  )
  (if ename
    (entupd ename)
  )
  ename
)

(defun alc--ask-points (first-point / points base next-point)
  (setq points (list first-point)
        base first-point)
  (while (setq next-point
           (getpoint base "\nNext point <Enter to finish>: "))
    (if (> (distance base next-point) 1e-8)
      (progn
        (alc--track-temp (alc--create-preview-line base next-point))
        (setq points (cons next-point points)
              base next-point)
      )
      (prompt "\nDuplicate point ignored.")
    )
  )
  (setq points (reverse points))
  (if (> (length points) 1)
    points
    (progn
      (prompt "\nAt least two distinct points are required.")
      nil
    )
  )
)

(defun alc--create-lwpolyline-wcs-on-layer
  (points closed normal layer / ocs-points elevation data point ename)
  (if (and (> (length points) 1) normal)
    (progn
      (setq ocs-points
        (mapcar '(lambda (p) (trans p 0 normal)) points)
      )
      (setq elevation (caddr (car ocs-points))
            data
              (list
                '(0 . "LWPOLYLINE")
                '(100 . "AcDbEntity")
                (cons 8 layer)
                '(100 . "AcDbPolyline")
                (cons 90 (length ocs-points))
                (cons 70 (if closed 1 0))
                (cons 38 elevation)
              ))
      (setq data (append data
        (mapcar '(lambda (point) (cons 10 (list (car point) (cadr point)))) ocs-points)
        (list (cons 210 normal))))
      (setq data data
            ename (entmakex data))
      (if (alc--lwpolyline-p ename)
        ename
      )
    )
  )
)

(defun alc--create-lwpolyline-wcs (points closed normal)
  (alc--create-lwpolyline-wcs-on-layer
    points closed normal (getvar "CLAYER"))
)

(defun alc--create-open-polyline (points / normal wcs-points)
  (setq normal (trans '(0.0 0.0 1.0) 1 0 T)
        wcs-points (mapcar '(lambda (p) (trans p 1 0)) points))
  (alc--create-lwpolyline-wcs wcs-points nil normal)
)

(defun alc--lwp-points (ename / start-param end-param index points)
  (setq start-param (fix (vlax-curve-getStartParam ename))
        end-param (fix (vlax-curve-getEndParam ename))
        index start-param
        points nil)
  (while (<= index end-param)
    (setq points
      (cons (vlax-curve-getPointAtParam ename index) points)
    )
    (setq index (1+ index))
  )
  (reverse points)
)

(defun alc--first-segment (ename / points p1 p2)
  (setq points (alc--lwp-points ename))
  (while (and (cdr points) (not p1))
    (if (> (distance (car points) (cadr points)) 1e-8)
      (setq p1 (car points)
            p2 (cadr points))
      (setq points (cdr points))
    )
  )
  (if p1 (list p1 p2))
)

(defun alc--side-point
  (edge side offset-distance
    / segment p1 p2 dx dy segment-length pick-distance)
  (if (setq segment (alc--first-segment edge))
    (progn
      (setq p1 (trans (car segment) 0 1)
            p2 (trans (cadr segment) 0 1)
            dx (- (car p2) (car p1))
            dy (- (cadr p2) (cadr p1))
            segment-length (sqrt (+ (* dx dx) (* dy dy)))
            pick-distance (* offset-distance 1.1))
      (if (> segment-length 1e-8)
        (list
          (+ (/ (+ (car p1) (car p2)) 2.0)
             (* side (/ (- dy) segment-length) pick-distance))
          (+ (/ (+ (cadr p1) (cadr p2)) 2.0)
             (* side (/ dx segment-length) pick-distance))
          (/ (+ (caddr p1) (caddr p2)) 2.0)
        )
      )
    )
  )
)

(defun alc--default-side-point (edge)
  (alc--side-point edge *alc-last-side* *alc-thickness*)
)

(defun alc--nearest-point (base points / point nearest nearest-distance test-distance)
  (foreach point points
    (setq test-distance (distance base point))
    (if (or (not nearest-distance) (< test-distance nearest-distance))
      (setq nearest point
            nearest-distance test-distance)
    )
  )
  nearest
)

(defun alc--side-of-offset
  (edge offset / segment p1 p2 offset-points point dx dy cross-product)
  (if (setq segment (alc--first-segment edge))
    (progn
      (setq p1 (trans (car segment) 0 1)
            p2 (trans (cadr segment) 0 1)
            offset-points
              (mapcar '(lambda (p) (trans p 0 1))
                      (alc--lwp-points offset))
            point (alc--nearest-point p1 offset-points)
            dx (- (car p2) (car p1))
            dy (- (cadr p2) (cadr p1))
            cross-product
              (- (* dx (- (cadr point) (cadr p1)))
                 (* dy (- (car point) (car p1)))))
      (if (>= cross-product 0.0) 1 -1)
    )
    *alc-last-side*
  )
)

(defun alc--offset-distance
  (edge side-point offset-distance / before after result old-osmode)
  (setq before (entlast)
        old-osmode (getvar "OSMODE"))
  (setvar "OSMODE" 0)
  (setq result
    (vl-catch-all-apply
      'vl-cmdf
      (list "_.OFFSET" offset-distance edge side-point ""))
  )
  (setvar "OSMODE" old-osmode)
  (if (vl-catch-all-error-p result)
    (progn
      (prompt
        (strcat "\nOffset failed: " (vl-catch-all-error-message result)))
      nil
    )
    (progn
      (setq after (entlast))
      (if (and after
               (not (equal before after))
               (alc--lwpolyline-p after))
        after
        (progn
          (prompt "\nOffset did not create a valid LWPOLYLINE.")
          nil
        )
      )
    )
  )
)

(defun alc--offset (edge side-point)
  (alc--offset-distance edge side-point *alc-thickness*)
)

(defun alc--make-closed-polyline
  (edge offset / points-a points-b same-direction reverse-direction points normal)
  (setq points-a (alc--lwp-points edge)
        points-b (alc--lwp-points offset))
  (if (and (> (length points-a) 1) (> (length points-b) 1))
    (progn
      (setq same-direction
        (+ (distance (car points-a) (car points-b))
           (distance (last points-a) (last points-b))))
      (setq reverse-direction
        (+ (distance (car points-a) (last points-b))
           (distance (last points-a) (car points-b))))
      (if (<= same-direction reverse-direction)
        (setq points (append points-a (reverse points-b)))
        (setq points (append points-a points-b))
      )
      (setq normal
        (if (assoc 210 (entget edge))
          (cdr (assoc 210 (entget edge)))
          '(0.0 0.0 1.0)
        )
      )
      (alc--create-lwpolyline-wcs points T normal)
    )
  )
)

;;; --------------------------------------------------------------------------
;;; Local wall-opening helpers

(defun alc--closed-lwpolyline-p (ename / flags)
  (and (alc--lwpolyline-p ename)
       (setq flags (cdr (assoc 70 (entget ename))))
       (= 1 (logand flags 1)))
)

(defun alc--clean-polygon-points (points / point result)
  (foreach point points
    (if (or (not result) (not (equal point (car result) 1e-7)))
      (setq result (cons point result))
    )
  )
  (setq result (reverse result))
  (if (and (> (length result) 1)
           (equal (car result) (last result) 1e-7))
    (setq result (reverse (cdr (reverse result))))
  )
  result
)

(defun alc--vector-subtract (point-a point-b)
  (mapcar '- point-a point-b)
)

(defun alc--vector-add (point-a point-b)
  (mapcar '+ point-a point-b)
)

(defun alc--vector-scale (vector factor)
  (mapcar '(lambda (value) (* value factor)) vector)
)

(defun alc--vector-dot (vector-a vector-b)
  (apply '+ (mapcar '* vector-a vector-b))
)

(defun alc--vector-length (vector)
  (sqrt (alc--vector-dot vector vector))
)

(defun alc--unit-vector (vector / vector-length)
  (setq vector-length (alc--vector-length vector))
  (if (> vector-length 1e-8)
    (alc--vector-scale vector (/ 1.0 vector-length))
  )
)

(defun alc--longest-edge-axis
  (points / count index point-a point-b vector edge-length best-length best-vector)
  (setq count (length points)
        index 0
        best-length 0.0)
  (while (< index count)
    (setq point-a (nth index points)
          point-b (nth (rem (1+ index) count) points)
          vector (alc--vector-subtract point-b point-a)
          edge-length (alc--vector-length vector))
    (if (> edge-length best-length)
      (setq best-length edge-length
            best-vector vector)
    )
    (setq index (1+ index))
  )
  (alc--unit-vector best-vector)
)

(defun alc--best-edge-axis
  (points direction
    / direction-unit count index point-a point-b edge-unit score best-score best-axis)
  (if (setq direction-unit (alc--unit-vector direction))
    (progn
      (setq count (length points)
            index 0
            best-score -1.0)
      (while (< index count)
        (setq point-a (nth index points)
              point-b (nth (rem (1+ index) count) points)
              edge-unit
                (alc--unit-vector
                  (alc--vector-subtract point-b point-a)))
        (if edge-unit
          (progn
            (setq score
              (abs (alc--vector-dot edge-unit direction-unit)))
            (if (> score best-score)
              (setq best-score score
                    best-axis edge-unit)
            )
          )
        )
        (setq index (1+ index))
      )
      best-axis
    )
  )
)

(defun alc--station (point axis)
  (alc--vector-dot point axis)
)

(defun alc--event-position (event)
  (+ (nth 1 event) (nth 2 event))
)

(defun alc--event-point (event)
  (nth 3 event)
)

(defun alc--event-distance (event)
  (nth 4 event)
)

(defun alc--event-point-exists-p (events point / event found)
  (foreach event events
    (if (equal (alc--event-point event) point 1e-7)
      (setq found T)
    )
  )
  found
)

(defun alc--cut-events
  (points axis target label
    / station count index point-a point-b value-a value-b denominator
      factor intersection event-index event-factor event-point result)
  (setq station (alc--station target axis)
        count (length points)
        index 0)
  (while (< index count)
    (setq point-a (nth index points)
          point-b (nth (rem (1+ index) count) points)
          value-a (- (alc--station point-a axis) station)
          value-b (- (alc--station point-b axis) station)
          denominator (- value-b value-a))
    (if (and (> (abs denominator) 1e-12)
             (or (and (<= value-a 1e-7) (>= value-b -1e-7))
                 (and (>= value-a -1e-7) (<= value-b 1e-7))))
      (progn
        (setq factor (/ (- value-a) denominator))
        (if (and (>= factor -1e-7) (<= factor (+ 1.0 1e-7)))
          (progn
            (cond
              ((<= factor 1e-7)
                (setq event-index index
                      event-factor 0.0
                      event-point point-a)
              )
              ((>= factor (- 1.0 1e-7))
                (setq event-index (rem (1+ index) count)
                      event-factor 0.0
                      event-point point-b)
              )
              (T
                (setq event-index index
                      event-factor factor
                      event-point
                        (alc--vector-add
                          point-a
                          (alc--vector-scale
                            (alc--vector-subtract point-b point-a)
                            factor)))
              )
            )
            (if (not (alc--event-point-exists-p result event-point))
              (setq result
                (cons
                  (list
                    label event-index event-factor event-point
                    (distance target event-point))
                  result))
            )
          )
        )
      )
    )
    (setq index (1+ index))
  )
  (reverse result)
)

(defun alc--nearest-events (events count / remaining selected best event)
  (setq remaining events)
  (repeat count
    (setq best nil)
    (foreach event remaining
      (if (or (not best)
              (< (alc--event-distance event)
                 (alc--event-distance best)))
        (setq best event)
      )
    )
    (if best
      (progn
        (setq selected (cons best selected)
              remaining (vl-remove best remaining))
      )
    )
  )
  (reverse selected)
)

(defun alc--target-between-events-p (target event-a event-b / point-a point-b span error)
  (setq point-a (alc--event-point event-a)
        point-b (alc--event-point event-b)
        span (distance point-a point-b)
        error
          (abs
            (- (+ (distance target point-a)
                  (distance target point-b))
               span)))
  (<= error (max 1e-6 (* span 1e-6)))
)

(defun alc--event-forward-span (event-a event-b count / span)
  (setq span (- (alc--event-position event-b)
                (alc--event-position event-a)))
  (if (<= span 1e-9)
    (setq span (+ span count))
  )
  span
)

(defun alc--event-between-forward-p
  (event-start event-end test-event count / span offset)
  (setq span (alc--event-forward-span event-start event-end count)
        offset (- (alc--event-position test-event)
                  (alc--event-position event-start)))
  (if (<= offset 1e-9)
    (setq offset (+ offset count))
  )
  (and (> offset 1e-7) (< offset (- span 1e-7)))
)

(defun alc--event-chain
  (points event-start event-end
    / count start-position end-position vertex-index result)
  (setq count (length points)
        start-position (alc--event-position event-start)
        end-position (alc--event-position event-end))
  (if (<= end-position (+ start-position 1e-9))
    (setq end-position (+ end-position count))
  )
  (setq result (list (alc--event-point event-start))
        vertex-index (1+ (fix start-position)))
  (while (< vertex-index (- end-position 1e-7))
    (setq result
      (cons (nth (rem vertex-index count) points) result)
    )
    (setq vertex-index (1+ vertex-index))
  )
  (setq result (cons (alc--event-point event-end) result))
  (alc--clean-polygon-points (reverse result))
)

(defun alc--outside-chain
  (points pair other-pair / event-a event-b other-a other-b count)
  (setq event-a (car pair)
        event-b (cadr pair)
        other-a (car other-pair)
        other-b (cadr other-pair)
        count (length points))
  (cond
    ((and (not
            (alc--event-between-forward-p
              event-a event-b other-a count))
          (not
            (alc--event-between-forward-p
              event-a event-b other-b count)))
      (alc--event-chain points event-a event-b)
    )
    ((and (not
            (alc--event-between-forward-p
              event-b event-a other-a count))
          (not
            (alc--event-between-forward-p
              event-b event-a other-b count)))
      (alc--event-chain points event-b event-a)
    )
  )
)

(defun alc--split-opening-polygons
  (points axis point-2 point-3
    / events-2 events-3 pair-2 pair-3 polygon-a polygon-b)
  (setq events-2 (alc--cut-events points axis point-2 'P2)
        events-3 (alc--cut-events points axis point-3 'P3)
        pair-2 (alc--nearest-events events-2 2)
        pair-3 (alc--nearest-events events-3 2))
  (if (and (= (length pair-2) 2)
           (= (length pair-3) 2)
           (alc--target-between-events-p
             point-2 (car pair-2) (cadr pair-2))
           (alc--target-between-events-p
             point-3 (car pair-3) (cadr pair-3)))
    (progn
      (setq polygon-a (alc--outside-chain points pair-2 pair-3)
            polygon-b (alc--outside-chain points pair-3 pair-2))
      (if (and (>= (length polygon-a) 3)
               (>= (length polygon-b) 3))
        (list polygon-a polygon-b)
      )
    )
  )
)

(defun alc--layer-locked-p (layer / data flags)
  (and (setq data (tblsearch "LAYER" layer))
       (setq flags (cdr (assoc 70 data)))
       (= 4 (logand flags 4)))
)

(defun alc--hatch-references-boundary-p (hatch boundary / item found)
  (foreach item (entget hatch)
    (if (and (= (car item) 330) (equal (cdr item) boundary))
      (setq found T)
    )
  )
  found
)

(defun alc--scan-boundary-hatches (boundary / selection index hatch result)
  (setq *alc-hatch-scan-count* (1+ *alc-hatch-scan-count*))
  (if (setq selection (ssget "_X" '((0 . "HATCH"))))
    (progn
      (setq index 0)
      (while (< index (sslength selection))
        (setq hatch (ssname selection index))
        (if (alc--hatch-references-boundary-p hatch boundary)
          (setq result (cons hatch result))
        )
        (setq index (1+ index))
      )
    )
  )
  (reverse result)
)

(defun alc--hatch-source-boundaries (hatch / item candidate result)
  (if (and hatch
           (entget hatch)
           (equal (cdr (assoc 0 (entget hatch))) "HATCH"))
    (foreach item (entget hatch)
      (if (= (car item) 330)
        (progn
          (setq candidate (cdr item))
          (if (and (alc--closed-lwpolyline-p candidate)
                   (>=
                     (length
                       (alc--clean-polygon-points
                         (alc--lwp-points candidate)))
                     4))
            (setq result (cons candidate result))
          )
        )
      )
    )
  )
  (reverse result)
)

(defun alc--resolve-wall (selected / entity-type boundaries)
  (if (and selected (entget selected))
    (progn
      (setq entity-type (cdr (assoc 0 (entget selected))))
      (cond
        ((and (equal entity-type "LWPOLYLINE")
              (alc--closed-lwpolyline-p selected)
              (>=
                (length
                  (alc--clean-polygon-points
                    (alc--lwp-points selected)))
                4))
          selected
        )
        ((equal entity-type "HATCH")
          (setq boundaries (alc--hatch-source-boundaries selected))
          (if (= (length boundaries) 1) (car boundaries))
        )
      )
    )
  )
)

(defun alc--vla-object-ename (object / result)
  (if object
    (progn
      (setq result
        (vl-catch-all-apply 'vlax-vla-object->ename (list object)))
      (if (not (vl-catch-all-error-p result))
        result
      )
    )
  )
)

(defun alc--put-object-layer (object layer)
  (if object
    (vl-catch-all-apply 'vla-put-Layer (list object layer))
  )
)

(defun alc--find-boundary-hatches (boundary)
  (if (and (boundp '*alc-hatch-index*) *alc-hatch-index*)
    (alc--indexed-hatches boundary)
    (alc--scan-boundary-hatches boundary)))
