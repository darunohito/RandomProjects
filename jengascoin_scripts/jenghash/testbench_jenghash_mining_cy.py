#!/usr/bin/python3.9

import jenghash_np_cy as jng
from total_size import *
import sys


# ----- Definitions -- DO NOT CHANGE (or record backup before changing >.> ) --


WORD_BYTES = 4  # bytes in word
DATASET_BYTES_INIT = 2 ** 30  # bytes in dataset at genesis
DATASET_BYTES_GROWTH = 2 ** 23  # dataset growth per epoch
CACHE_BYTES_INIT = 2 ** 24  # bytes in cache at genesis
CACHE_BYTES_GROWTH = 2 ** 17  # cache growth per epoch
EPOCH_LENGTH = 30000  # blocks per epoch
MIX_BYTES = 128  # width of mix
HASH_BYTES = 64  # hash length in bytes
DATASET_PARENTS = 256  # number of parents of each dataset element
CACHE_ROUNDS = 3  # number of rounds in cache production
ACCESSES = 64  # number of accesses in hashimoto loop


if len(sys.argv) != 4:
    print(sys.stderr, "usage: ", sys.argv[0], "epoch|dag-lines",
          "0xheaderhash", "0xdiff")
    sys.exit(1)

epoch = int(sys.argv[1])
block = epoch * EPOCH_LENGTH
hdr = jng.encode_int(int(sys.argv[2], base=16))[::-1]
hdr = '\x00' * (32 - len(hdr)) + hdr
diff = int(sys.argv[3], base=16)
# print("mining target: ", decode_int(get_target(diff)))


seed = jng.deserialize_hash(jng.get_seedhash(block))
print("seed", "%064x" % jng.decode_int(jng.serialize_hash(seed)[::-1]), "\n   now acquiring cache...")
# cache = mkcache(get_cache_size(block), seed)
cache = jng.build_hash_struct(jng.get_cache_size(block), seed, out_type='cache', coin='jng')
print("cache completed. \n   now acquiring dag...")
dataset = jng.build_hash_struct(jng.get_full_size(block), cache, out_type='dag', coin='jng')
print("dataset completed. \n   now mining...")


nonce = jng.mine(jng.get_full_size(block), dataset, hdr, diff, jng.random_nonce())
print("nonce found!")
result = jng.hashimoto_light(jng.get_full_size(block), cache, hdr, nonce).get("mix digest")
if result <= jng.get_target(diff):
    print("verification passed!")
else:
    print("verification failed!")
