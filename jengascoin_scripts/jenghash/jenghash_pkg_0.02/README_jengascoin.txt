This is only tested on Windows. Please follow the steps exactly, and let me know if there are any issues getting it running.

Install Python3:
	a) Download & Install python3 (*at least version 3.8*), with the "add to PATH environment" option checked.
	b) Navigate to the python installation folder, and create a copy of "python.exe" named "python3.exe"
		- This allows your PATH variable to deal with different versions of python on the same system.

Install Rust:
	a) Download/install from here: https://rustup.rs/
	b) make sure it's added to the PATH variable

Setup:
	a) Inside of the /jenghash_pkg/ directory, execute the "1_setup.bat" file. 
		- This will pre-install the necessary python extensions 
	b) Execute the "2_built.bat" file. 
		- Enter "b" to build the "jh.c" & "jh.pyx" python extension files

Testing:
	a) Execute the "3_blake3_test.bat" file.
		- It should not generate any errors. 
		- If the output says "OK", the blake3 module is working properly.
		- The "Hashrate" readout will benchmark your CPU for blake3 hashing. On a ~4.2 GHz Intel CPU, I manage around 650 KH/s.
	b) Execute the "4_jh_ext_test.bat" file.
		- It should not generate any errors. 
		- The difficulty is fairly low, and it should be solved in between 5-30 seconds. 
		- The final message should read "verification passed!"
	c) Execute the "5_jh_network_test.bat" file.
		- It should load in the cache and dag from the "frozen" epoch 10 (block 30,000)
		- It should begin hashing the dagger file using updated headers from Peer1.
		- It should occassionally (every ~30-90s) find & validate a nonce. Failed validations are usually due to the block updating between a "find" and a "verify", which is normal.
		- The validations are local---it's not actually sending the block to the node.
	

The rest is in-work.