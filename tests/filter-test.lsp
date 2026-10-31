;;; Selection-only layer filtering, including non-curve entities and last pick.
(defun alc-test--filter-check (name pass / lines)
  (setq lines (alc-test--read-lines (alc-test--result-path "filter-test.log")))
  (alc-test--write-lines "filter-test.log"
    (append lines (list (strcat (if pass "PASS " "FAIL ") name)))))

(defun alc-test-run-filter (/ *alc-stat-last-layers* old-pickfirst old-layer old-width a b text circle
    filter-input samples selected subset before-data before-last target-calls name entity)
  (setq old-pickfirst (getvar "PICKFIRST") old-layer (getvar "CLAYER") old-width (getvar "PLINEWID"))
  (setvar "PICKFIRST" 1)
  (foreach name '("Codex_Filter_A" "Codex_Filter_B")
    (if (not (tblsearch "LAYER" name))
      (entmake (list '(0 . "LAYER") (cons 2 name) '(70 . 0) '(62 . 7) '(6 . "Continuous")))))
  ;; entmake assigns drawing ownership so Pickfirst/native selection can see them.
  (entmake '((0 . "LINE") (8 . "Codex_Filter_A") (10 0.0 0.0 0.0) (11 1000.0 0.0 0.0)))
  (setq a (entlast))
  (entmake '((0 . "LINE") (8 . "Codex_Filter_B") (10 0.0 10.0 0.0) (11 2000.0 10.0 0.0)))
  (setq b (entlast))
  (entmake '((0 . "TEXT") (8 . "Codex_Filter_A") (10 0.0 30.0 0.0) (40 . 10.0) (1 . "Filter text")))
  (setq text (entlast))
  (entmake '((0 . "CIRCLE") (8 . "Codex_Filter_A") (10 0.0 50.0 0.0) (40 . 10.0)))
  (setq circle (entlast) filter-input (ssadd) samples (ssadd) target-calls 0)
  (foreach entity (list a b text circle) (ssadd entity filter-input))
  (ssadd a samples)
  (setq before-data (mapcar 'entget (list a b text circle)) before-last (entlast))
  (defun alc--stat-select-layer-objects () samples)
  (defun alc--filter-select-objects () (setq target-calls (1+ target-calls)) filter-input)
  (c:VVFILTER)
  (setq selected (ssget "_I"))
  (alc-test--filter-check "public-command-leaves-only-matching-layer-in-pickfirst"
    (and selected (= (sslength selected) 3) (ssmemb a selected) (not (ssmemb b selected))))
  (alc-test--filter-check "TEXT-and-CIRCLE-are-included-not-just-LINE-and-pline"
    (and (ssmemb text selected) (ssmemb circle selected)))
  (alc-test--filter-check "non-ALC-layer-can-be-used-as-filter"
    (equal *alc-stat-last-layers* '("Codex_Filter_A")))
  (alc-test--write-lines "filter-state-debug.log"
    (list (strcat "same-entities=" (vl-princ-to-string (equal before-data (mapcar 'entget (list a b text circle)))))
          (strcat "same-layer=" (vl-princ-to-string (= old-layer (getvar "CLAYER"))))
          (strcat "same-width=" (vl-princ-to-string (= old-width (getvar "PLINEWID"))))
          (strcat "same-last=" (vl-princ-to-string (equal before-last (entlast))))))
  (alc-test--filter-check "source-entities-and-current-layer-width-are-unchanged"
    (and (equal before-data (mapcar 'entget (list a b text circle)))
      (= old-layer (getvar "CLAYER")) (= old-width (getvar "PLINEWID")) (equal before-last (entlast))))
  (setq samples nil)
  (c:VVFILTER)
  (setq selected (ssget "_I"))
  (alc-test--filter-check "empty-sample-confirmation-reuses-last-pick"
    (and selected (= (sslength selected) 3) (not (ssmemb b selected))))
  (setq samples 'all)
  (c:VVFILTER)
  (alc-test--filter-check "All-keeps-every-object-from-the-user-source-selection"
    (= (sslength (ssget "_I")) 4))
  (setq samples nil)
  (alc-test--filter-check "VVFILTER-last-pick-is-shared-with-VVTK-layer-picker"
    (eq (alc--stat-choose-layers) 'all))
  (setq samples (ssadd)) (ssadd b samples)
  (c:VVFILTER)
  (alc-test--filter-check "new-sample-replaces-last-pick-with-new-layer"
    (and (equal *alc-stat-last-layers* '("Codex_Filter_B"))
      (= (sslength (ssget "_I")) 1) (ssmemb b (ssget "_I"))))
  (setq samples nil *alc-stat-last-layers* '("MissingFilterLayer") target-calls 0)
  (c:VVFILTER)
  (alc-test--filter-check "missing-last-layers-skip-object-prompt-instead-of-using-All"
    (= target-calls 0))
  (setq *alc-stat-last-layers* nil target-calls 0)
  (c:VVFILTER)
  (alc-test--filter-check "no-last-pick-and-no-samples-cancel-before-object-selection"
    (= target-calls 0))
  (setq samples (ssadd)) (ssadd a samples)
  (setq subset (ssadd)) (ssadd b subset)
  (setq filter-input subset)
  (c:VVFILTER)
  (alc-test--filter-check "completed-selection-with-no-match-clears-pickfirst"
    (not (ssget "_I")))
  (setq samples nil filter-input nil *alc-stat-last-layers* '("Codex_Filter_A"))
  (sssetfirst nil subset)
  (c:VVFILTER)
  (alc-test--filter-check "empty-target-selection-preserves-previous-pickfirst"
    (and (= (sslength (ssget "_I")) 1) (ssmemb b (ssget "_I"))))
  (sssetfirst nil nil)
  (setvar "PICKFIRST" old-pickfirst)
  (load (strcat (getenv "ALCWALL_TEST_ROOT") "/src/alc-schedule.lsp"))
  (load (strcat (getenv "ALCWALL_TEST_ROOT") "/src/alc-commands.lsp"))
  (foreach entity (list a b text circle) (entdel entity))
  (princ))
(princ)
