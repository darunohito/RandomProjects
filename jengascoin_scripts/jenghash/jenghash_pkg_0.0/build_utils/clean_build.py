import os
import glob
import shutil

cwd = os.path.dirname(__file__)
paths = ['build', '__pycache__']
files = ['jh.**.pyd', '*.c']


# exception handler
def rem_dir_handler(func, path, exc_info):
    print(exc_info)


# Remove the platform-specific directories
for path in paths:
    path = os.path.join(cwd, path)
    shutil.rmtree(path, onerror=rem_dir_handler)


for file in files:
    file_globs = glob.glob(os.path.join(cwd, file), recursive=True)
    for file_glob in file_globs:
        try:
            print("file: ", file_glob)
            # file = os.path.join(cwd, file)
            os.remove(file_glob)
        except OSError as error:
            # print(error)
            print("File '% s' can not be removed or doesn't exist" % file_glob)


print('\n     Clean operation complete.')