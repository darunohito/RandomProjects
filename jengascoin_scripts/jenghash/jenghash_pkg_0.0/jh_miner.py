import jh
from jh_definitions import *
import sys
import base64
import cython
import numpy as np


# example call:
# python3 jh_miner.py 10 0x667c94657d5b6922693e2e6ac77b80861b80ff949c795ef4b18551e8c389a2f1 0xffffffd50ce24800000000000000000000000000000000000000000000000000 4
if len(sys.argv) != 5:
    print(sys.stderr, "usage: ", sys.argv[0], "epoch[int]", "0xheaderhash", "0xdiff", "threads[int]")
    sys.exit(1)

epoch = int(sys.argv[1])
block = epoch * EPOCH_LENGTH
hdr = jh.encode_int(int(sys.argv[2], base=16))[::-1]
hdr = '\x00' * (32 - len(hdr)) + hdr
diff = int(sys.argv[3], base=16)

seed = jh.deserialize_hash(jh.get_seedhash(block))
print("seed", "%064x" % jh.decode_int(jh.serialize_hash(seed)[::-1]))

# build and/or load the hash structures into memory
cache = jh.build_hash_struct(jh.get_cache_size(block), seed, out_type='cache', coin='jng')
dataset = jh.build_hash_struct(jh.get_full_size(block), cache, out_type='dag', coin='jng')

print("mining...")
nonce = jh.mine(jh.get_full_size(block), dataset, hdr, diff, jh.random_nonce())
print("nonce found! ", nonce)
result = jh.hashimoto_light(jh.get_full_size(block), cache, hdr, nonce).get("mix digest")
if result <= jh.get_target(diff):
    print("verification passed!")
else:
    print("verification failed!")
