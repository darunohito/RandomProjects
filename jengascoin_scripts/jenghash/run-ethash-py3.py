#!/usr/bin/python3.7
import time

from ethash_py3_np import *
import sys
import torch


def main():
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
        seed = deserialize_hash(get_seedhash(0))
        print("seed raw type: ", type(seed), ", seed: ", seed)
        print("seed", "%064x" % decode_int(serialize_hash(seed)[::-1]))
        cache = mkcache(HASH_BYTES, seed)
        print("cache len: ", len(cache))
        dag_bytes = int(sys.argv[1]) * MIX_BYTES
        print("dag_bytes = ", dag_bytes)
    else:
        block = int(sys.argv[1]) * EPOCH_LENGTH
        seed = deserialize_hash(get_seedhash(block))
        print("seed raw type: ", type(seed), ", seed: ", seed)
        print("seed", "%064x" % decode_int(serialize_hash(seed)[::-1]))
        cache = build_hash_struct(get_cache_size(block), seed, out_type='cache', coin='eth')
        print("cache len: ", len(cache))
        dag_bytes = get_full_size(block)
        print("dag_bytes = ", dag_bytes)
    hdr = encode_int(int(sys.argv[2], base=16))[::-1]
    hdr = '\x00' * (32 - len(hdr)) + hdr
    print("header: ", hdr)
    nonce = int(sys.argv[3], base=16)
    print("nonce: ", nonce)
    time_start = time.perf_counter()
    hash = hashimoto_light(dag_bytes, cache, hdr, nonce)
    time_elapsed = time.perf_counter() - time_start
    print("cmix", "%064x" % decode_int(hash["mix digest"][::-1]))
    print("res ", "%064x" % decode_int(hash["result"][::-1]))
    print(f"time to run hashimoto_light: {time_elapsed * 1000:.2f} ms")


if __name__ == '__main__':
    main()
