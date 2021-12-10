from subprocess import Popen, PIPE, STDOUT
import sys
from urllib.parse import urljoin
import jh
from jh_definitions import *
import json
import base58


# ----- Main function ---------------------------------------------------------


if __name__ == "__main__":
    

    # example call:
    # python3 jh.py http://peer1.jengas.io/ <public-key> <private-key>
    if len(sys.argv) < 4 or len(sys.argv) > 5:
        print(sys.stderr, "usage: python3", sys.argv[0], "<peer-URL>", "<public-key>", "<private-key>", "(opt)freeze")
        sys.exit(1)
    peer = sys.argv[1]

    freeze = False
    if sys.argv[4] == "freeze":
        freeze = True  # FROZEN ONLY FOR DEBUG & TEST

    miner_input = jh.get_miner_input(peer, _frozen=freeze)  # FROZEN ONLY FOR DEBUG & TEST

    print("Startup mining info:")
    for key, value in miner_input.items():
        print(key, type(value), value)

    seed = jh.deserialize_hash(jh.get_seedhash(miner_input['block']))
    print("seed", "%064x" % jh.decode_int(jh.serialize_hash(seed)[::-1]), "\n   now acquiring cache...")
    cache = jh.build_hash_struct(jh.get_cache_size(miner_input['block']), seed, out_type='cache', coin='jng')
    print("cache completed. \n   now acquiring dag...")
    dataset = jh.build_hash_struct(jh.get_full_size(miner_input['block']), cache, out_type='dag', coin='jng')
    print("dataset completed. \n   now mining...")

    found = 0
    verified = 0
    _md = None
    while True:  # FROZEN ONLY FOR DEBUG & TEST
        nonce, out, block, header, _md = jh.mine_w_update(jh.get_full_size(miner_input['block']),
                                                  dataset, peer, miner_input, 3.0, freeze, _md)
        found += 1
        miner_input = jh.get_miner_input(peer, header, freeze)
        result = jh.hashimoto_light(jh.get_full_size(miner_input['block']), cache,
                                 miner_input['header'], nonce).get('mix digest')
        if result <= jh.get_target_jh(miner_input['diff_int']):
            verified += 1
            print("block found...verification passed!    oWo    found: %d, verified: %d" % (found, verified))
        else:
            print("block found...verification failed!    >:(    found: %d, verified: %d" % (found, verified))
