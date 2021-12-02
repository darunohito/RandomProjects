# to call: python setup.py build_ext --inplace

from setuptools import setup
# from distutils.core import setup
from Cython.Build import cythonize
import numpy


setup(
    ext_modules=cythonize("jh.pyx"),
    include_dirs=[numpy.get_include()]
)