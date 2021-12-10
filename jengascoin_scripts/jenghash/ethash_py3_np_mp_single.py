from ethash_py3_np_mp import *
import sys
# ----- Main function ---------------------------------------------------------


# example call:
# python3 ethash_py3_np_mp_single.py 359
# 0x667c94657d5b6922693e2e6ac77b80861b80ff949c795ef4b18551e8c389a2f1 0x710a38013066d8ce 6
def main():
    # for i, data in enumerate(dataloader):
    #
    # usage: ethash_py3_np_mp_single.py epoch 0xheaderhash 0xnonce threads  (real-life mode)
    #        ethash_py3_np_mp_single.py dag-lines 0xheaderhash 0xnonce threads  (mixone mode)
    #
    if len(sys.argv) != 5:
        print(sys.stderr, "usage: ", sys.argv[0], "epoch|dag-lines",
              "0xheaderhash", "0xnonce", "threads")
        sys.exit(1)
    th = int(sys.argv[4])

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

    print("starting to build dagger...")
    dagger = build_hash_struct(dag_bytes, cache, out_type='dag', coin='eth', thread_count=th)

    i = 0
    single = calc_dataset_item(cache, i)
    while all([a == b for a, b in zip(dagger[i], single)]):
        i += 1
        single = calc_dataset_item(cache, i)
        print(f"\b\b\b\b\b\b\b\b\b\b\b\b{i}", end='')

        # r = randint(0, dag_bytes // HASH_BYTES)
        # single = calc_dataset_item(cache, r)
        # assert all([a == b for a, b in zip(dagger[r], single)]), \
        #     f"failed at index {r}\ndagger: {dagger[r]}\nsingle: {single}"

    hash_full = hashimoto_full(dag_bytes, dagger, hdr, nonce)
    print("cmix_full: ", "%064x" % decode_int(hash_full["mix digest"][::-1]))
    print("res_full ", "%064x" % decode_int(hash_full["result"][::-1]))
    assert hash == hash_full


if __name__ == '__main__':
    main()
