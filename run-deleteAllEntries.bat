@echo off
set /p confirm="Are you sure you want to delete all entries? (Y/N): "
if /i "%confirm%"=="Y" (
    node ./deleteAllEntries.js
) else (
    echo Deletion aborted.
)
pause