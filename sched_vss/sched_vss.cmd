@echo off
set WORK_DIR=%~dp0
cd %WORK_DIR%
set RUBY_EXE=%WORK_DIR%ruby\bin\ruby.exe
set SCRIPT=%WORK_DIR%sched_vss.rb

"%RUBY_EXE%" "%SCRIPT%"
