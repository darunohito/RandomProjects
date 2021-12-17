:: run_jh_unit_tests.bat
set /P cores="enter number of processor cores:"
python3 jh_unit_tests.py https://dev1.jengas.io %cores%
pause