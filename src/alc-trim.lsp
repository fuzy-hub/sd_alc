(setq *alc-module-version* "3.3.6")
;;; ALCWALL - shorten or extend one end of a straight-sided wall strip.

(defun alc--ensure-trim-distance ()
  (if (or (not (boundp '*alc-trim-distance*))
          (not (numberp *alc-trim-distance*))
          (<= *alc-trim-distance* 0.0))
    (setq *alc-trim-distance* 20.0))
  *alc-trim-distance*)

;; Preserve the last Length choice when this module is loaded again.
(alc--ensure-trim-distance)

(defun alc--ensure-xtend-distance ()
  (if (or (not (boundp '*alc-xtend-distance*))
          (not (numberp *alc-xtend-distance*))
          (<= *alc-xtend-distance* 0.0))
    (setq *alc-xtend-distance* 20.0))
  *alc-xtend-distance*)

(alc--ensure-xtend-distance)

(defun alc--trim-end (points index / count a b prev next ua ub cap)
  (setq count (length points)
        a (nth index points) b (nth (rem (1+ index) count) points)
        prev (nth (rem (+ index count -1) count) points)
        next (nth (rem (+ index 2) count) points)
        ua (alc--unit-vector (alc--vector-subtract prev a))
        ub (alc--unit-vector (alc--vector-subtract next b))
        cap (alc--unit-vector (alc--vector-subtract b a)))
  (if (and ua ub cap
           (equal ua ub 1e-6)
           (< (abs (alc--vector-dot ua cap)) 1e-6))
    (list index ua (min (distance a prev) (distance b next))
      (alc--vector-scale (alc--vector-add a b) 0.5))))

(defun alc--trim-points (points pick cut-distance / count half end-a end-b chosen index result p)
  ;; ALCWALL/ALCCENTRAL store side A forward, followed by side B backward.
  (setq count (length points) half (/ count 2))
  (if (and (>= count 4) (= (rem count 2) 0)
           (setq end-a (alc--trim-end points (1- count)))
           (setq end-b (alc--trim-end points (1- half))))
    (progn
      (setq chosen (if (<= (distance pick (nth 3 end-a))
                          (distance pick (nth 3 end-b))) end-a end-b))
      ;; Negative distance moves the cap outward, without a shortening limit.
      (if (or (< cut-distance 0.0) (> (nth 2 chosen) (+ cut-distance 1e-6)))
        (progn
          (setq index 0)
          (foreach p points
            (if (or (= index (car chosen))
                    (= index (rem (1+ (car chosen)) count)))
              (setq p (alc--vector-add p
                (alc--vector-scale (cadr chosen) cut-distance))))
            (setq result (cons p result) index (1+ index)))
          (reverse result))))))

(defun alc--trim-hatch-supported-p (data count / item active valid)
  (setq valid (and (= (cdr (assoc 71 data)) 1)
                   (= (cdr (assoc 91 data)) 1)
                   (= (cdr (assoc 93 data)) count)))
  (foreach item data
    (cond ((= (car item) 92) (setq active T))
          ((= (car item) 97) (setq active nil))
          ((and active (= (car item) 72)
                (= (logand 2 (cdr (assoc 92 data))) 0)
                (/= (cdr item) 1)) (setq valid nil))))
  valid)

(defun alc--trim-hatch-data (data points normal / item active remaining ocs result poly)
  (setq remaining points)
  (foreach item data
    (cond
      ((= (car item) 92) (setq active T poly (= (logand 2 (cdr item)) 2)))
      ((= (car item) 97) (setq active nil))
      ((and active (= (car item) 10))
        (setq ocs (trans (car remaining) 0 normal)
              item (cons 10 (if poly (list (car ocs) (cadr ocs)) ocs)))
        (if poly (setq remaining (cdr remaining))))
      ((and active (not poly) (= (car item) 11))
        (setq ocs (trans (if (cdr remaining) (cadr remaining) (car points)) 0 normal)
              item (cons 11 ocs) remaining (cdr remaining))))
    (setq result (cons item result)))
  (if (not remaining) (reverse result)))

(defun alc--trim-evaluate (wall hatches points / hatch data updated pass)
  (setq pass T)
  (entupd wall)
  (foreach hatch hatches
    ;; Evaluate alone retains the old cached loop after an entmod of its source.
    (setq data (entget hatch)
          updated (alc--trim-hatch-data data points (cdr (assoc 210 data))))
    (if (and updated (entmod updated))
      (vla-Evaluate (vlax-ename->vla-object hatch))
      (setq pass nil)))
  pass)

(defun alc--resize-wall (wall pick cut-distance extend / data updated hatches blocked item
    new-data remaining ocs result hatch-data)
  (setq data (entget wall) blocked nil)
  (foreach item data
    (if (and (= (car item) 42) (/= (cdr item) 0.0)) (setq blocked T)))
  (setq hatches (alc--find-boundary-hatches wall))
  (foreach item hatches
    (setq hatch-data (cons (entget item) hatch-data))
    (if (or (alc--layer-locked-p (cdr (assoc 8 (entget item))))
            (not (alc--trim-hatch-supported-p (entget item) (cdr (assoc 90 data)))))
      (setq blocked T)))
  (cond
    ((or (not (numberp cut-distance)) (<= cut-distance 0.0))
      (prompt "\nDo dai phai lon hon 0.") nil)
    ((or (not (alc--straight-wall-p wall)) blocked
         (alc--layer-locked-p (cdr (assoc 8 data))))
      (prompt "\nKhong the sua: layer bi khoa, bien cong hoac hatch khong ho tro.") nil)
    ((not (setq updated (alc--trim-points
             (alc--clean-polygon-points (alc--lwp-points wall)) pick
             (if extend (- cut-distance) cut-distance))))
      (prompt (if extend "\nKhong the keo dai: dau tuong khong vuong."
        (strcat "\nKhong the cat: dau tuong khong vuong hoac doan dau dai khong qua "
          (rtos cut-distance 2 2) " mm."))) nil)
    ((not (alc--valid-polygon-p updated (cdr (assoc 210 data))))
      (prompt "\nTu choi hinh tuong tu giao hoac suy bien.") nil)
    (T
      ;; Keep entity identity, properties and hatch links; change vertices only.
      (setq remaining updated)
      (foreach item data
        (if (= (car item) 10)
          (progn
            (setq ocs (trans (car remaining) 0 wall)
                  item (cons 10 (list (car ocs) (cadr ocs))))
            (setq remaining (cdr remaining))))
        (setq new-data (cons item new-data)))
      (if (and (not remaining) (entmod (reverse new-data)))
        (progn
          (setq result (vl-catch-all-apply 'alc--trim-evaluate (list wall hatches updated)))
          (if (or (not result) (vl-catch-all-error-p result))
            (progn
              (entmod data)
              (foreach item hatch-data (entmod item))
              (entupd wall)
              (prompt "\nKhong cap nhat duoc hatch; da khoi phuc bien tuong.") nil)
            T))
        (progn (prompt "\nKhong the cap nhat bien tuong.") nil)))))

(defun alc--shorten-wall (wall pick cut-distance)
  (alc--resize-wall wall pick cut-distance nil))

(defun alc--extend-wall (wall pick extend-distance)
  (alc--resize-wall wall pick extend-distance T))

(defun alc--shorten-wall-20 (wall pick)
  (alc--shorten-wall wall pick 20.0))

(defun alc--trim-input (message / saved-osmode result picked)
  ;; entsel treats L as Last. Read keywords first, then resolve the picked point.
  (setq saved-osmode (getvar "OSMODE"))
  (setvar "OSMODE" (logior saved-osmode 16384))
  (setq result (vl-catch-all-apply 'getpoint (list message)))
  (setvar "OSMODE" saved-osmode)
  (if (vl-catch-all-error-p result)
    (vl-exit-with-error (vl-catch-all-error-message result)))
  (if (alc--point-p result)
    (progn
      (setq picked (nentselp "" result))
      ;; Never edit entities nested inside a block or xref definition.
      (list (if (and picked (= (length picked) 2)) (car picked)) result))
    result))

(defun alc--resize-loop (extend / selection wall multi done count cut-distance answer action)
  (alc--end-hatch-index)
  (if (vl-catch-all-error-p (vl-catch-all-apply 'alc--build-hatch-index nil))
    (alc--end-hatch-index))
  (setq count 0 action (if extend "keo dai" "rut")
        cut-distance (if extend (alc--ensure-xtend-distance) (alc--ensure-trim-distance)))
  (while (not done)
    (initget "Multi Length")
    (setq selection
      (alc--trim-input (strcat "\nChon tuong ALC/hatch gan dau can " action " "
        (rtos cut-distance 2 2) " mm hoac [Multi/Length]"
        (if multi " <Enter ket thuc>: " ": "))))
    (cond
      ((not selection) (setq done T))
      ((equal selection "Multi")
        (setq multi T)
        (prompt (strcat "\nMulti: chon lan luot cac dau tuong can " action ".")))
      ((equal selection "Length")
        (initget 6)
        (setq answer (getdist (strcat "\nDo dai " (if extend "keo <" "cat <")
          (rtos cut-distance 2 2) ">: ")))
        (if answer
          (progn
            (setq cut-distance answer)
            (if extend (setq *alc-xtend-distance* answer)
              (setq *alc-trim-distance* answer)))))
      (T
        (if (setq wall (alc--resolve-wall (car selection)))
          (if (alc--resize-wall wall (trans (cadr selection) 1 0) cut-distance extend)
            (progn
              (setq count (1+ count))
              (prompt (strcat "\nDa " action " dau tuong " (rtos cut-distance 2 2) " mm."))))
          (prompt "\nHay chon bien tuong ALC hoac hatch lien ket."))
        (if (not multi) (setq done T)))))
  (if multi (prompt (strcat "\nDa " action " " (itoa count) " dau tuong."))))

(defun alc--trim-loop () (alc--resize-loop nil))
(defun alc--xtend-loop () (alc--resize-loop T))

(princ)
