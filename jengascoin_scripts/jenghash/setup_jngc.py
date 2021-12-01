# args: build_ext --inplace

# from setuptools import setup
from distutils.core import setup
from Cython.Build import cythonize
import numpy


setup(
    ext_modules=cythonize("jenghash_np_cy.pyx"),
    include_dirs=[numpy.get_include()]
)