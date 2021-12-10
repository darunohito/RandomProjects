This is only tested on Windows. Please follow the steps exactly, and let me know if there are any issues getting it running.

Install Python3:
	a) Download & Install python3 (*at least version 3.8*), with the "add to PATH environment" option checked.

Install Rust:
	a) Download/install from here: https://rustup.rs/
	b) make sure it's added to the PATH variable

Setup:
	a) Inside of the /jenghash_pkg/ directory, execute the "1_setup.bat" file. 
		- This will pre-install the necessary python extensions 
	b) Execute the "2_built.bat" file. 
		- Enter "b" to build the "jh.c" & "jh.pyx" python extension files

Testing:
	a) Execute the "2_blake3_test.bat" file.
		- It should not generate any errors. 
		- If the output says "OK", the blake3 module is working properly.
		- The "Hashrate" readout will benchmark your CPU for blake3 hashing. On a ~4.2 GHz Intel CPU, I manage around 650 KH/s.
	b) Execute the "3_jh_unit_test.bat" file.
		- It will take ~15 minutes to run.
		- It should pass all tests.
	

The rest is in-work.