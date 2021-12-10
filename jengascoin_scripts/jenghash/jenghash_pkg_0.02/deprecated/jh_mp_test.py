import numpy as np
from random import randint
import multiprocessing as mp
from multiprocessing import shared_memory

shm = mp.shared_memory.SharedMemory(create=True, size=16)
shm_name = shm.name

buffer = np.ndarray([2, 2], dtype=np.uint32, buffer=shm.buf)

for i in range(len(buffer)):
    for j in range(len(buffer[i])):
        buffer[i][j] = randint(0, 2**32-1)

print(buffer)
print(shm.name)

shm.close()

new_shm = mp.shared_memory.SharedMemory(name=shm_name, create=False)
new_buffer = np.ndarray([2, 2], dtype=np.uint32, buffer=new_shm.buf)
old_buffer = np.ndarray([2, 2], dtype=np.uint32, buffer=shm.buf)

print("new: ", new_buffer)
print("old: ", old_buffer)
