@echo off
set /p confirm="Are you sure you want to delete today's entries? (Y/N): "
if /i "%confirm%"=="Y" (
    node ./deleteTodayEntries.js
) else (
    echo Deletion aborted.
)
pause