#!/usr/bin/python3.9

from jenghash import *
import base64
import sys

if len(sys.argv) != 4:
    print(sys.stderr, "usage: ", sys.argv[0], "epoch|dag-lines",
          "0xheaderhash", "0xdiff")
    sys.exit(1)

block = int(sys.argv[1]) * EPOCH_LENGTH
hdr = encode_int(int(sys.argv[2], base=16))[::-1]
hdr = '\x00' * (32 - len(hdr)) + hdr
diff = int(sys.argv[3], base=16)
print("mining target: ", base64.b64encode(get_target(diff)))

print("header: ", hdr)

seed = deserialize_hash(get_seedhash(block))
print("seed", "%064x" % decode_int(serialize_hash(seed)[::-1]), "\n   now generating cache...")
cache = mkcache(get_cache_size(block), seed)
print("cache len: ", len(cache), "\n   now generating complete dag...")
dataset = calc_dataset(get_full_size(block), cache)
print("full dag len:", len(dataset))



mine(len(dataset), dataset, hdr, get_target(diff), random_nonce())