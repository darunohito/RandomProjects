#!/usr/bin/python3.7

import ethash_py3_np_cy as eth
import sys
import time
import cython as cy


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


# for i, data in enumerate(dataloader):
#
# usage: ethash.py epoch 0xheaderhash 0xnonce  (real-life mode)
#        ethash.py dag-lines 0xheaderhash 0xnonce  (mixone mode)
#
if len(sys.argv) != 4:
    print(sys.stderr, "usage: ", sys.argv[0], "epoch|dag-lines",
          "0xheaderhash", "0xnonce")
    sys.exit(1)

# do exactly what mixone does
if int(sys.argv[1]) > 1000:
    seed = eth.deserialize_hash(eth.get_seedhash(0))
    print("seed raw type: ", type(seed), ", seed: ", seed)
    print("seed", "%064x" % eth.decode_int(eth.serialize_hash(seed)[::-1]))
    cache = eth.mkcache(HASH_BYTES, seed)
    print("cache len: ", len(cache))
    dag_bytes = int(sys.argv[1]) * MIX_BYTES
    print("dag_bytes = ", dag_bytes)
else:
    block = int(sys.argv[1]) * EPOCH_LENGTH
    seed = eth.deserialize_hash(eth.get_seedhash(block))
    print("seed raw type: ", type(seed), ", seed: ", seed)
    print("seed", "%064x" % eth.decode_int(eth.serialize_hash(seed)[::-1]))
    cache = eth.build_hash_struct(eth.get_cache_size(block), seed, out_type='cache', coin='eth')
    print("cache len: ", len(cache))
    dag_bytes = eth.get_full_size(block)
    print("dag_bytes = ", dag_bytes)
hdr = eth.encode_int(int(sys.argv[2], base=16))[::-1]
hdr = '\x00' * (32 - len(hdr)) + hdr
print("header: ", hdr)
nonce = int(sys.argv[3], base=16)
print("nonce: ", nonce)
time_start = time.perf_counter()
hash = eth.hashimoto_light(dag_bytes, cache, hdr, nonce)
time_elapsed = time.perf_counter() - time_start
print("cmix", "%064x" % eth.decode_int(hash["mix digest"][::-1]))
print("res ", "%064x" % eth.decode_int(hash["result"][::-1]))
print(f"time to run hashimoto_light: {time_elapsed * 1000:.2f} ms")
