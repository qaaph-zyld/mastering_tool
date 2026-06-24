@echo off
setlocal enabledelayedexpansion

set PYTHON=d:\Projects\.venv\Scripts\python.exe
set SCRIPT=d:\Projects\Music-AI-Toolshop\mastering_tool\phase8_validate.py
set ARTIFACTS=d:\Projects\Music-AI-Toolshop\mastering_tool\phase8_artifacts

%PYTHON% "%SCRIPT%" "%ARTIFACTS%\clip1.mp3" "%ARTIFACTS%\track1_Pod_Senkom_Breze"
%PYTHON% "%SCRIPT%" "%ARTIFACTS%\clip2.mp3" "%ARTIFACTS%\track2_Love_Language"
%PYTHON% "%SCRIPT%" "%ARTIFACTS%\clip3.mp3" "%ARTIFACTS%\track3_Overthinkk"
