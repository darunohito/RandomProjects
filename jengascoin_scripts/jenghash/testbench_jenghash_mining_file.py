#!/usr/bin/python3.9
import time

from jenghash_np import *
import multiprocessing as mp
from multiprocessing import shared_memory
import sys

if len(sys.argv) != 4:
    print(sys.stderr, "usage: ", sys.argv[0], "epoch|dag-lines",
          "0xheaderhash", "0xdiff")
    sys.exit(1)

epoch = int(sys.argv[1])
block = epoch * EPOCH_LENGTH
hdr = encode_int(int(sys.argv[2], base=16))[::-1]
hdr = '\x00' * (32 - len(hdr)) + hdr
diff = int(sys.argv[3], base=16)
# print("mining target: ", decode_int(get_target(diff)))


seed = deserialize_hash(get_seedhash(block))
print("seed", "%064x" % decode_int(serialize_hash(seed)[::-1]), "\n   now acquiring cache...")
cache = build_hash_struct(get_cache_size(block), seed, out_type='cache', coin='jng')
print("cache completed. \n   now acquiring dag...")

dataset = build_hash_struct(get_full_size(block), cache, out_type='dag', coin='jng')
dataset_shm = shared_memory.SharedMemory(create=True, size=dataset.nbytes)

# Now create a NumPy array backed by shared memory
b = np.ndarray(dataset.shape, dtype=dataset.dtype, buffer=dataset_shm.buf)

print("dataset completed. \n   now mining...")

metadata = {
    # miner inputs
    'update_period': 1.0,  # seconds, float
    'diff': diff,
    'header': hdr,
    # miner outputs
    'num_hashes': 0,
    'best_hash': get_target(2)
}
metadata, hash_ceil = miner_file_update(metadata, mode='run', parent='node')

mp.set_start_method('spawn')
q = mp.Queue()
p = mp.Process(target=mine_to_file, args=(get_full_size(block), dataset))
p.start()
print(q.get())
p.join()

while 1:
    t_start = time.perf_counter()
    while time.perf_counter() > t_start + 30:  # make 30s blocktime
        nonce = mine_to_file(get_full_size(block), dataset)
        print("nonce found!", )
        result = hashimoto_light(get_full_size(block), cache, hdr, nonce).get("mix digest")
        if result <= get_target(diff):
            print("verification passed!")
        else:
            print("verification failed!")
        break
    metadata['diff'] += 1  # change for funsies
    metadata['header'] = blake3_256(metadata['header'])
    print("best hash: ",  decode_int(metadata['best_hash']) )
    metadata['best_hash'] = get_target(2)  # reset?

