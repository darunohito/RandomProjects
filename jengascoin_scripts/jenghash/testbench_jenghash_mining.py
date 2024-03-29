#!/usr/bin/python3.9

from jenghash_np import *
from total_size import *
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
# cache = mkcache(get_cache_size(block), seed)
cache = build_hash_struct(get_cache_size(block), seed, out_type='cache', coin='jng')
print("cache completed. \n   now acquiring dag...")
dataset = build_hash_struct(get_full_size(block), cache, out_type='dag', coin='jng')
print("dataset completed. \n   now mining...")


nonce = mine(len(dataset), dataset, hdr, diff, random_nonce())
print("nonce found!")
result = hashimoto_light(get_full_size(block), cache, hdr, nonce).get("mix digest")
if result <= get_target(diff):
    print("verification passed!")
else:
    print("verification failed!")