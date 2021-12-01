#!/usr/bin/python3.9

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


if len(sys.argv) != 4:
    print(sys.stderr, "usage: ", sys.argv[0], "epoch|dag-lines",
          "0xheaderhash", "0xdiff")
    sys.exit(1)

epoch = int(sys.argv[1])
block = epoch * EPOCH_LENGTH
hdr = eth.encode_int(int(sys.argv[2], base=16))[::-1]
hdr = '\x00' * (32 - len(hdr)) + hdr
diff = int(sys.argv[3], base=16)
# print("mining target: ", decode_int(get_target(diff)))


seed = eth.deserialize_hash(eth.get_seedhash(block))
print("seed", "%064x" % eth.decode_int(eth.serialize_hash(seed)[::-1]), "\n   now acquiring cache...")
cache = eth.build_hash_struct(eth.get_cache_size(block), seed, out_type='cache', coin='eth')
print("cache completed. ", len(cache), "\n   now acquiring dag...")
dataset = eth.build_hash_struct(eth.get_full_size(block), cache, out_type='dag', coin='eth')
print("dataset completed. full dag len:", len(dataset))


nonce = eth.mine(len(dataset), dataset, hdr, diff, eth.random_nonce())
print("nonce found!")
