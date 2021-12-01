from setuptools import setup
from Cython.Build import cythonize
import numpy


setup(
    ext_modules=cythonize("ethash_py3_np_cy.pyx", include_path=[numpy.get_include(), "C:\Python37\Lib\site-packages\numpy\core\include"])
)