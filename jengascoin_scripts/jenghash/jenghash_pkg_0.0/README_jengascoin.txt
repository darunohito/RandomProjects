This is only tested on Windows. Please follow the steps exactly, and let me know if there are any issues getting it running.

Step 1, Install Python:
	a) Download & Install python3 (at least version 3.7), with the "add to PATH environment" option checked.
	b) Navigate to the python installation folder, and create a copy of "python.exe" named "python3.exe"
		- This allows your path variable to deal with different versions of python on the same system.

Step 2, Setup:
	a) Inside of the /jenghash_pkg/ directory, execute the "_run_setup.bat" file. 
		- This will pre-install the necessary python extensions and build the "jh.c" & "jh.pyx" python extension files

Step 3, Testing:
	a) Execute the "_run_blake3_test.bat" file.
		- It should not generate any errors. 
		- If the output says "OK", the blake3 module is working properly.
		- The "Hashrate" readout will benchmark your CPU for blake3 hashing. On a ~4.2 GHz Intel CPU, I manage around 650 KH/s.
	b) Execute the "_mine.bat" file.
		- It should not generate any errors. 
		- The difficulty is fairly low, and it should be solved in between 5-30 seconds. 
		- The final message should read "verification passed!"

The rest is in-work.