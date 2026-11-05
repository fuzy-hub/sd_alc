(defun alc-test--mask-check (name pass / lines)
  (setq lines (alc-test--read-lines (alc-test--result-path "stat-mask-test.log")))
  (alc-test--write-lines "stat-mask-test.log"
    (append lines (list (strcat (if pass "PASS " "FAIL ") name)))))

(defun alc-test-run-stat-mask (/ table mask data origin group dict order objects saved-frame saved-pick line low high)
  (setq saved-frame (getvar "WIPEOUTFRAME") saved-pick (getvar "PICKSTYLE"))
  (setq line (entmakex '((0 . "LINE") (10 0.0 -500.0 0.0) (11 15000.0 -500.0 0.0))))
  (setq table (alc--add-length-detail-table '(("MASK" . 3000.0)) '(1000.0 0.0 0.0) 100.0)
        mask (entlast) data (entget mask))
  (alc-test--mask-check "native-wipeout-background" (= (cdr (assoc 0 data)) "WIPEOUT"))
  (vla-GetBoundingBox (vlax-ename->vla-object mask) 'low 'high)
  (setq low (vlax-safearray->list low) high (vlax-safearray->list high))
  (alc-test--mask-check "mask-covers-final-table-width-and-height"
    (and (equal low (list 1000.0 (- (vla-get-Height table)) 0.0) 1e-6)
      (equal high (list (+ 1000.0 (vla-get-Width table)) 0.0 0.0) 1e-6)))
  (alc-test--mask-check "mask-and-table-share-owner-and-layer"
    (and (equal (assoc 330 data) (assoc 330 (entget (vlax-vla-object->ename table))))
      (equal (assoc 8 data) (assoc 8 (entget (vlax-vla-object->ename table))))))
  (setq group (vla-Item (vla-get-Groups (alc--get-active-document))
                (strcat "ALC_VVTK_" (vla-get-Handle table))))
  (alc-test--mask-check "table-and-mask-grouped-for-selection"
    (and (= (vla-get-Count group) 2) (= (cdr (assoc 71 (entget (vlax-vla-object->ename group)))) 1)))
  (setq dict (vla-GetExtensionDictionary
               (vla-ObjectIDToObject (alc--get-active-document) (vla-get-OwnerID table)))
        order (vla-Item dict "ACAD_SORTENTS"))
  (vla-GetFullDrawOrder order 'objects :vlax-false)
  (setq objects (mapcar 'vlax-vla-object->ename (vlax-safearray->list objects)))
  (alc-test--mask-check "existing-line-below-mask"
    (> (length (member line objects)) (length (member mask objects))))
  (alc-test--mask-check "table-above-mask-in-draw-order"
    (equal (list mask (vlax-vla-object->ename table))
      (reverse (list (car (reverse objects)) (cadr (reverse objects))))))
  (alc-test--mask-check "contents-and-source-total-preserved"
    (and (= (vla-GetText table 2 1) "MASK") (= (atof (vla-GetText table 3 3)) 3.0)))
  (alc-test--mask-check "global-frame-and-group-settings-preserved"
    (and (= saved-frame (getvar "WIPEOUTFRAME")) (= saved-pick (getvar "PICKSTYLE")))))
