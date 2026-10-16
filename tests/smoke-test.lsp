;;; Verifies that the public ALCWALL command surface loads in CAD.

(vl-load-com)

(defun alc-test--root ()
  (vl-string-translate "\\" "/" (getenv "ALCWALL_TEST_ROOT"))
)


(defun alc-test--dxf-code-count (code data / item count)
  (setq count 0)
  (foreach item data
    (if (= (car item) code)
      (setq count (1+ count))
    )
  )
  count
)

(defun alc-test--settings-record-stability
  (/ before-data after-data before-size after-size pass)
  (alc--save-settings)
  (setq before-data (entget (alc--settings-ename))
        before-size (length before-data))
  (repeat 10
    (alc--save-settings)
  )
  (setq after-data (entget (alc--settings-ename))
        after-size (length after-data)
        pass
          (and
            (= before-size after-size)
            (= (alc-test--dxf-code-count 1 after-data) 1)
            (= (alc-test--dxf-code-count 2 after-data) 1)
            (= (alc-test--dxf-code-count 40 after-data) 1)
            (= (alc-test--dxf-code-count 41 after-data) 1)
            (= (alc-test--dxf-code-count 42 after-data) 1)
            (= (alc-test--dxf-code-count 43 after-data) 1)
            (= (alc-test--dxf-code-count 44 after-data) 1)
            (= (alc-test--dxf-code-count 70 after-data) 1)
            (= (alc-test--dxf-code-count 90 after-data) 1)
            (= (alc-test--dxf-code-count 91 after-data) 1)
            (= (alc-test--dxf-code-count 92 after-data) 1)))
  (list pass before-size after-size)
)

(defun alc-test--background-startup-default
  (/ original-background none-reset-pass true-white-pass)
  (setq original-background *alc-background-color*
        *alc-background-color* 0)
  (alc--save-settings)
  (alc--load-settings)
  (setq none-reset-pass (= *alc-background-color* 256)
        *alc-background-color* 256)
  (alc--save-settings)
  (alc--load-settings)
  (setq true-white-pass (= *alc-background-color* 256)
        *alc-background-color* original-background)
  (alc--save-settings)
  (and none-reset-pass true-white-pass)
)

(defun alc-test-run-smoke
  (/ root load-result commands atoms missing name lines original-thickness
     session-pass background-pass record-result tkms-pass legacy-command-pass)
  ;; Simulate upgrading within a session where the obsolete command is loaded.
  (defun c:ALCCUT20 () (princ "obsolete command"))
  (setq root (alc-test--root)
        load-result
          (vl-catch-all-apply
            'load (list (strcat root "/ALCWALL.lsp")))
        commands
          '("C:ALCSET" "C:ALCWALL" "C:ALCCENTRAL" "C:ALCDOOR"
            "C:ALCLT" "C:ALCGT" "C:ALCGTS" "C:ALCTK"
            "C:ALCTKC" "C:TKDIM" "C:TKCOUNT" "C:TKMS" "C:TKALIGN"
            "C:ALCDIM" "C:ALCS" "C:ALSC" "C:ALCTRIM" "C:ALCXTEND" "C:VV" "C:VVC"
            "C:VVSET" "C:VVS" "C:VVWALL" "C:VVCENTRAL" "C:VVDOOR"
            "C:VVTRIM" "C:VVXTEND" "C:VVLT" "C:VVGT" "C:VVGTS"
            "C:VVTK" "C:VVTKC" "C:VVDIM")
        atoms (atoms-family 1)
        missing nil
        legacy-command-pass (not c:ALCCUT20))
  (if (vl-catch-all-error-p load-result)
    (setq lines
      (list
        "FAIL"
        (strcat "LOAD_ERROR=" (vl-catch-all-error-message load-result))))
    (progn
      (foreach name commands
        (if (not (member name atoms))
          (setq missing (cons name missing))
        )
      )
      (if missing
        (setq lines
          (list
            "FAIL"
            (strcat "MISSING_COMMANDS="
              (apply 'strcat
                (mapcar '(lambda (item) (strcat item " "))
                  (reverse missing))))))
        (progn
          ;; Regression: settings changed by ALCSET must remain active when
          ;; the drawing command starts, even if persistence is delayed.
          (alc--ensure-settings)
          (setq original-thickness *alc-thickness*
                *alc-thickness* 175.0)
          (alc--ensure-settings)
          (setq session-pass (equal *alc-thickness* 175.0 1e-9)
                *alc-thickness* original-thickness
                background-pass (alc-test--background-startup-default)
                record-result (alc-test--settings-record-stability)
                tkms-pass
                  (and
                    (equal (alc--numbered-text-parts "MA") '("MA" 1))
                    (equal (alc--numbered-text-parts "MA-009") '("MA" 10))
                    (equal (alc--numbered-text-parts "MA-999") '("MA" 1000))
                    (equal (alc--numbered-text-parts "MA-09") '("MA-09" 1))
                    (equal (alc--three-digit-number 1) "001")
                    (equal (alc--three-digit-number 99) "099")
                    (equal (alc--three-digit-number 999) "999")))
          (if (and session-pass background-pass (car record-result) tkms-pass legacy-command-pass)
            (setq lines
              (list
                "PASS"
                (strcat "COMMAND_COUNT=" (itoa (length commands)))
                "LEGACY_ALCCUT20_REMOVED=PASS"
                "SESSION_SETTINGS=PASS"
                "BACKGROUND_MODES=PASS"
                "TKMS_NUMBERING=PASS"
                (strcat
                  "XRECORD_SIZE="
                  (itoa (cadr record-result))
                  "->"
                  (itoa (caddr record-result)))
                (strcat "VERSION=" *alc-version*)))
            (setq lines
              (list
                "FAIL"
                (if legacy-command-pass "LEGACY_ALCCUT20_REMOVED=PASS" "LEGACY_ALCCUT20_REMOVED=FAIL")
                (if session-pass
                  "SESSION_SETTINGS=PASS"
                  "SESSION_SETTINGS=RESET")
                (if background-pass
                  "BACKGROUND_MODES=PASS"
                  "BACKGROUND_MODES=FAIL")
                (if tkms-pass
                  "TKMS_NUMBERING=PASS"
                  "TKMS_NUMBERING=FAIL")
                (strcat
                  "XRECORD_SIZE="
                  (itoa (cadr record-result))
                  "->"
                  (itoa (caddr record-result)))))
          )
        )
      )
    )
  )
  (alc-test--write-lines
    (strcat root "/tests/results/smoke-test.log") lines)
  (prompt (strcat "\nALCWALL_SMOKE_TEST_" (car lines)))
  (equal (car lines) "PASS")
)

(princ)
