;;; Verifies that the public ALCWALL command surface loads in CAD.

(vl-load-com)

(defun alc-test--root ()
  (vl-string-translate "\\" "/" (getenv "ALCWALL_TEST_ROOT"))
)

(defun alc-test--write-lines (path lines / stream line)
  (if (setq stream (open path "w"))
    (progn
      (foreach line lines (write-line line stream))
      (close stream)
      T
    )
  )
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
            (= (alc-test--dxf-code-count 70 after-data) 1)
            (= (alc-test--dxf-code-count 90 after-data) 1)
            (= (alc-test--dxf-code-count 91 after-data) 1)
            (= (alc-test--dxf-code-count 92 after-data) 1)))
  (list pass before-size after-size)
)

(defun alc-test-run-smoke
  (/ root load-result commands atoms missing name lines original-thickness
     session-pass record-result)
  (setq root (alc-test--root)
        load-result
          (vl-catch-all-apply
            'load (list (strcat root "/ALCWALL.lsp")))
        commands
          '("C:ALCSET" "C:ALCWALL" "C:ALCCENTRAL" "C:ALCDOOR"
            "C:ALCLT" "C:ALCGT" "C:ALCGTS" "C:ALCTK"
            "C:ALCTKC" "C:TKDIM" "C:TKCOUNT" "C:TKALIGN")
        atoms (atoms-family 1)
        missing nil)
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
                record-result (alc-test--settings-record-stability))
          (if (and session-pass (car record-result))
            (setq lines
              (list
                "PASS"
                "COMMAND_COUNT=12"
                "SESSION_SETTINGS=PASS"
                (strcat
                  "XRECORD_SIZE="
                  (itoa (cadr record-result))
                  "->"
                  (itoa (caddr record-result)))
                (strcat "VERSION=" *alc-version*)))
            (setq lines
              (list
                "FAIL"
                (if session-pass
                  "SESSION_SETTINGS=PASS"
                  "SESSION_SETTINGS=RESET")
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
