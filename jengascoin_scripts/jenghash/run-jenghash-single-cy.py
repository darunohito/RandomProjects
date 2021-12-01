#!/usr/bin/python3.9

import jenghash_np_cy as jng
import sys
import time


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


#
# usage: jenghash.py epoch 0xheaderhash 0xnonce  (real-life mode)
#        jenghash.py dag-lines 0xheaderhash 0xnonce  (mixone mode)
#
if len(sys.argv) != 4:
    print(sys.stderr, "usage: ", sys.argv[0], "epoch|dag-lines",
          "0xheaderhash", "0xnonce")
    sys.exit(1)

# do exactly what mixone does
if int(sys.argv[1]) > 1000:
    seed = jng.deserialize_hash(jng.get_seedhash(0))
    print("seed raw type: ", type(seed), ", seed: ", seed)
    print("seed", "%064x" % jng.decode_int(jng.serialize_hash(seed)[::-1]))
    cache = jng.mkcache(HASH_BYTES, seed)
    print("cache len: ", len(cache))
    dag_bytes = int(sys.argv[1]) * MIX_BYTES
    print("dag_bytes = ", dag_bytes)
else:
    block = int(sys.argv[1]) * EPOCH_LENGTH
    seed = jng.deserialize_hash(jng.get_seedhash(block))
    print("seed raw type: ", type(seed), ", seed: ", seed)
    print("seed", "%064x" % jng.decode_int(jng.serialize_hash(seed)[::-1]))
    # cache = mkcache(get_cache_size(block), seed)
    cache = jng.build_hash_struct(jng.get_cache_size(block), seed, out_type='cache', coin='jng')
    print("cache len: ", len(cache))
    dag_bytes = jng.get_full_size(block)
    print("dag_bytes = ", dag_bytes)
hdr = jng.encode_int(int(sys.argv[2], base=16))[::-1]
hdr = '\x00' * (32 - len(hdr)) + hdr
print("header: ", hdr)
nonce = int(sys.argv[3], base=16)
print("nonce: ", nonce)
time_start = time.perf_counter()
hash = jng.hashimoto_light(dag_bytes, cache, hdr, nonce)
time_elapsed = time.perf_counter() - time_start
print("cmix", "%064x" % jng.decode_int(hash["mix digest"][::-1]))
print("res ", "%064x" % jng.decode_int(hash["result"][::-1]))
print(f"time to run hashimoto_light: {time_elapsed*1000:.2f} ms")
