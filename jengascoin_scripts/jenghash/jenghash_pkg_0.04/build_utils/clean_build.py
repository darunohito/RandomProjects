import os
import glob
import shutil

cwd = os.path.abspath(os.curdir)
print("cwd: ", cwd)
paths = ['build', '__pycache__']
files = ['jh.**.pyd', 'jh.c', 'jh.html']


# exception handler
def rem_dir_handler(func, path, exc_info):
    print(exc_info)


# Remove the platform-specific directories
for path in paths:
    path = os.path.join(cwd, path)
    print("removing dir:", path)
    shutil.rmtree(path, onerror=rem_dir_handler)


# Remove the platform-specific files
for file in files:
    print("file: ", os.path.join(cwd, file))
    file_globs = glob.glob(os.path.join(cwd, file), recursive=True)
    for file_glob in file_globs:
        try:
            print("removing file: ", file_glob)
            # file = os.path.join(cwd, file)
            os.remove(file_glob)
        except OSError as error:
            # print(error)
            print("File '% s' can not be removed or doesn't exist" % file_glob)


print('\n     Clean operation complete.')