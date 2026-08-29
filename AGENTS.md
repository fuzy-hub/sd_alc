# Project working instructions

## CAD testing and process safety

- The user no longer uses ZWCAD. Do not run, test with, or look for ZWCAD.
- Run all CAD tests with AutoCAD 2027 only.
- Never reuse, automate, close, or terminate an AutoCAD process that was already running before the test.
- Start every automated AutoCAD test in a separate process created by Codex. Assign the run a unique session label and record the exact process ID and start time returned at launch.
- Never stop AutoCAD by process name and never use broad commands such as `Stop-Process -Name acad`, `Stop-Process -Name accoreconsole`, or `taskkill /IM`. These can terminate the user's active CAD session.
- If cleanup is required, terminate only the exact PID created for the labeled Codex test session, after verifying that the PID and start time still match the recorded process. If ownership cannot be verified, leave the process running and report it to the user.
- Prefer `accoreconsole.exe` for non-interactive tests. If full `acad.exe` is required, launch a separate instance and apply the same label/PID/start-time safeguards.
