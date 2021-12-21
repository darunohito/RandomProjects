# from setuptools import setup
# from distutils.core import setup
# from Cython.Compiler import Options
# Options.embed = "main"
# from Cython.Build import cythonize
# import numpy



# setup(
    # ext_modules=cythonize("jh.pyx"),
    # include_dirs=[numpy.get_include()]
# )

import sys
import os 
import glob
import subprocess
# import sh

path = os.path.join(os.path.dirname(sys.executable), "Lib\site-packages\cython.py")
# path = glob.glob(path)
print("cython path: ", path)

cmd = f"python3 {path} -3 -a --embed=main --verbose jh.pyx"
print("command: ", cmd)
# sh.python3(path, "--embed", "jh.pyx")
# subprocess.run(f"python3 {path} --embed jh.pyx", shell=True, check=True)


# Use shell to execute the command and store it in sp variable
sp = subprocess.Popen(cmd, shell=True)

# Store the return code in rc variable
rc=sp.wait()

# Print the content of sp variable
print(sp)