#!/usr/bin/python2.7

#
# https://eth.wiki/en/concepts/ethash/ethash
#
# This one points out some issues, but gets several things wrong, too:
# https://github.com/lukovkin/ethash
#
# The issues found in the lokovkin version:
#
# - The encode_int(nonce) does not produce the expected byte string of fixed
#   length 8. Our solution using "struct" should be better.
#
# - Target non-reversal is incorrect, given that we perform a string
#   comparison, which is big-endian.
#

#
# Requires
# python-pysha3
#
# Note: the Keccak hashes are called keccak_*, not sha3_*
# See also: https://pypi.org/project/pysha3/
#

import copy
import os
import time
import json
import numpy as np
from hash_utils import *
from random import randint
from blake3 import blake3
from binascii import hexlify


# blake3 hash function, outputs 32 bytes unless otherwise specified

def blake3_512(x):
    h = hash_words(lambda v: blake3(v).digest(length=64), 64, x)
    return h


def blake3_256(x):
    h = hash_words(lambda v: blake3(v).digest(), 32, x)
    return h


# ----- Parameters ------------------------------------------------------------


def get_cache_size(block_number):
    sz = CACHE_BYTES_INIT + \
         CACHE_BYTES_GROWTH * (block_number // EPOCH_LENGTH)
    sz -= HASH_BYTES
    while not isprime(sz / HASH_BYTES):
        sz -= 2 * HASH_BYTES
    return sz


def get_full_size(block_number):
    sz = DATASET_BYTES_INIT + \
         DATASET_BYTES_GROWTH * (block_number // EPOCH_LENGTH)
    sz -= MIX_BYTES
    while not isprime(sz / MIX_BYTES):
        sz -= 2 * MIX_BYTES
    return sz


"""
build_hash_struct()
takes:
    out_size: size [int]
    seed: seed|cache [list of ints]
    out_type: 'cache'|'dag'
    coin: 'jng'|'eth'| 'other_string'
"""


def build_hash_struct(out_size, seed, out_type='cache', coin='jng'):
    # find directory and build file name
    if out_type == 'cache':
        name_temp = int_list_to_bytes(seed)
    elif out_type == 'dag':
        name_temp = int_list_to_bytes(seed[0])
    else:
        raise Exception(f"out_type of 'cache' or 'dag' expected, '{out_type}' given")
    short_name = blake3(name_temp).hexdigest(length=16)
    name = out_type + '_L_' + str(out_size) + "_C_" + short_name + '.npy'
    cwd = os.path.dirname(__file__)
    file_dir = os.path.join(cwd, f"{coin}_{out_type}_dir")
    filepath = os.path.join(file_dir, name)

    # check for a saved hash structure
    if os.path.exists(filepath):
        print(f"loading {out_type} for length: ", out_size, " and short_name: ", short_name)
        with open(filepath, 'rb') as file:
            return np.load(filepath)
    print(f"  no saved {out_type} found, generating hash structure\n \
         this will take a while... ", end="")

    # since no saved structure exist, build from scratch
    if out_type == 'cache':
        # q = mp.Queue()
        # p = mp.Process(target=mkcache, args=(out_size, seed))
        # p.start()
        # hash_struct = q.get()
        hash_struct = mkcache(cache_size=out_size, seed=seed)
    elif out_type == 'dag':
        hash_struct = calc_dataset(full_size=out_size, cache=seed)
    else:
        raise Exception(f"out_type of 'cache' or 'dag' expected, '{out_type}' given")
    # hash_struct = np.array(hash_struct, 'uint32')  # convert to numpy array
    # gc.collect()  # attempt to free memory

    # save newly-generated hash structure
    if not os.path.exists(file_dir):
        os.mkdir(file_dir)
    with open(filepath, 'wb') as name:
        print(f"\nsaving {out_type} for length: ", out_size, " and short_name: ", short_name)
        np.save(filepath, hash_struct)

    return hash_struct


# ----- Cache Generation ------------------------------------------------------


def mkcache(cache_size, seed):
    n = cache_size // HASH_BYTES

    # Sequentially produce the initial dataset
    o = np.empty([n, HASH_BYTES // WORD_BYTES], np.uint32)
    o[0] = blake3_512(seed)
    for i in range(1, n):
        o[i] = blake3_512(int_list_to_bytes(o[i-1]))
    # Use a low-round version of randmemohash
    for _ in range(CACHE_ROUNDS):
        for i in range(n):
            v = o[i][0] % n
            # maps list to list, with xor function
            # sha expects bytes, mapping xor with integers returns
            # a list of 4-byte integers
            o_temp = int_list_to_bytes(list(map(xor, o[(i - 1 + n) % n], o[v])))
            o[i] = blake3_512(o_temp)
    return o


# ----- Full dataset calculation ----------------------------------------------


def calc_dataset_item(cache, i):
    n = len(cache)
    r = HASH_BYTES // WORD_BYTES
    i = int(i)
    # initialize the mix
    mix = copy.copy(cache[i % n])
    mix[0] ^= i
    mix = blake3_512(int_list_to_bytes(mix))
    # fnv it with a lot of random cache nodes based on i
    for j in range(DATASET_PARENTS):
        cache_index = fnv(i ^ j, mix[j % r])
        mix = list(map(fnv, mix, cache[cache_index % n]))
    return blake3_512(int_list_to_bytes(mix))


def calc_dataset(full_size, cache):
    # generate the dataset
    t_start = time.perf_counter()
    # dataset = []
    percent_done = 0
    total_size = full_size // HASH_BYTES
    dataset = np.empty([total_size, HASH_BYTES // WORD_BYTES], np.uint32)
    print("percent done:       ", end="")
    for i in range(total_size):
        # dataset.append(calc_dataset_item(cache, i))
        dataset[i] = calc_dataset_item(cache, i)
        if (i / total_size) > percent_done + 0.0001:
            percent_done = i / total_size
            print(f"\b\b\b\b\b\b{(percent_done * 100):5.2f}%", end="")
    t_elapsed = time.perf_counter() - t_start
    print("DAG completed in [only!] ", t_elapsed, " seconds!  oWo  so fast")

    return dataset


# ----- Main Loop -------------------------------------------------------------


def hashimoto(header, nonce, full_size, dataset_lookup):
    n = full_size / HASH_BYTES
    w = MIX_BYTES // WORD_BYTES
    mix_hashes = MIX_BYTES // HASH_BYTES
    # combine header+nonce into a 64 byte seed
    base = str_to_bytes(header) + struct.pack("<Q", nonce)
    s = blake3_512(base)
    # start the mix with replicated s
    mix = []
    for _ in range(mix_hashes):
        mix.extend(s)
    # mix in random dataset nodes
    for i in range(ACCESSES):
        p = int(fnv(i ^ s[0], mix[i % w]) % (n // mix_hashes) * mix_hashes)
        newdata = []
        for j in range(mix_hashes):
            newdata.extend(dataset_lookup(p + j))
        mix = list(map(fnv, mix, newdata))
    # compress mix
    cmix = []
    for i in range(0, len(mix), 4):
        cmix.append(fnv(fnv(fnv(mix[i], mix[i + 1]), mix[i + 2]), mix[i + 3]))
    return {
        "mix digest": serialize_hash(cmix),
        "result": serialize_hash(blake3_256(s + cmix))
    }


def hashimoto_light(full_size, cache, header, nonce):
    return hashimoto(header, nonce, full_size,
                     lambda x: calc_dataset_item(cache, x))


def hashimoto_full(full_size, dataset, header, nonce):
    return hashimoto(header, nonce, full_size, lambda x: dataset[x])


# ----- Mining ----------------------------------------------------------------

# We break "mine" down into smaller parts, to have better control over the
# mining process.

def get_target(difficulty):
    # byte strings are little-endian, have to reverse for target comparison
    return encode_int(2 ** 256 // difficulty).ljust(32, '\0')[::-1]


def random_nonce():
    return randint(0, 2 ** 64)


def mine(full_size, dataset, header, difficulty, nonce):
    target = get_target(difficulty)
    while hashimoto_full(full_size, dataset, header, nonce).get("mix digest") > target:
        nonce = (nonce + 1) % 2 ** 64
    return nonce


# ------- Real-life Jengascoin miner implementation ---------------------------------


# Jengascoin uses subtractive difficulty (not division-scaled)
def get_target_jh(difficulty):
    test_target = 2 ** 256 // 30000
    # byte strings are little-endian, have to reverse for target comparison
    return encode_int(test_target - difficulty).ljust(32, '\0')[::-1]
    # return encode_int(2 ** 256 - difficulty).ljust(32, '\0')[::-1]


def mine_w_update(full_size, dataset, peer_url, miner_info=None, update_period=3.0):

    def reset_miner(update_per, hash_ceil, elapsed, metadata):
        if metadata is None:

        print(f"hashrate: {hash_ceil/elapsed:.0f} H/s, best hash: ", md['best_hash'])
        miner_metadata = {}
        miner_metadata['hash_ceil'] = (hash_ceil * update_per) // elapsed
        miner_metadata.update({
            'num_hashes': 0,  # initialization value
            'best_hash': get_target_jh(1),  # initialization value
            't_start': time.perf_counter()
        })
        return miner_metadata

    md = reset_miner(update_period, 1000, 3.0)
    nonce = random_nonce()
    if miner_info is None:
        miner_info = get_miner_input(peer_url)
    target = get_target_jh(miner_info['diff_int'])
    while True:
        while md['num_hashes'] < md['hash_ceil']:
            out = hashimoto_full(full_size, dataset, miner_info['header'], nonce)
            if out['mix digest'] < md['best_hash']:
                if out['mix digest'] < target:
                    return nonce, out, miner_info['block'], miner_info['header']
                md['best_hash'] = out['mix digest']
            nonce = (nonce + 1) % 2 ** 64
            md['num_hashes'] += 1
        miner_info = get_miner_input(peer_url)
        if miner_info['new']:
            md = reset_miner(update_period, md['hash_ceil'], time.perf_counter()-md['t_start'])
            target = get_target_jh(miner_info['diff_int'])


def parse_mining_input(miner_in):
    miner_input_parsed = {
        'diff': hex(int(miner_in['difficulty'])),
        'diff_int': int(miner_in['difficulty']),
        'header': '0x' + base58.b58decode(miner_in['block']).hex(),  # "block" is actually hash of last block
        'block': miner_in['height'],  # "height" is actually "block" number, for ethash
    }
    if miner_in['old_hdr'] != miner_input_parsed['header']:
        miner_input_parsed['new'] = True
    else:
        miner_input_parsed['new'] = False
    # *************************************************************************
    miner_input_parsed['block'] = 10 * EPOCH_LENGTH  # DEBUG AND TEST ONLY!
    # *************************************************************************
    return miner_input_parsed


def get_miner_input(peer_url, hdr=None):
    # pull initial mining info
    cmd = f"curl -s {urljoin(peer_url, url_path['mine_solo'])}"
    sp = Popen(cmd, shell=True, stdin=PIPE, stdout=PIPE, stderr=STDOUT, close_fds=True)
    info, err = sp.communicate()
    if json.loads(info)['status'] == 'error':
        print(f"could not get mining info from {peer_url}")
        sys.exit(1)
    miner_in = json.loads(info)['data']
    if hdr is None:
        miner_in['old_hdr'] = False
    else:
        miner_in['old_hdr'] = hdr
    # rc = sp.wait()
    return parse_mining_input(miner_in)


# ----- Defining the Seed Hash ------------------------------------------------


def get_seedhash(block):
    s = '\x00' * 32
    for i in range(block // EPOCH_LENGTH):
        s = serialize_hash(blake3_256(s))
    return s


# ----- Main function ---------------------------------------------------------


if __name__ == "__main__":
    from subprocess import Popen, PIPE, STDOUT
    import sys
    # import sh
    from urllib.parse import urljoin
    from jh_definitions import *
    import json
    import base58

    # example call:
    # python3 jh.py http://peer1.jengas.io/ <public-key> <private-key>
    if len(sys.argv) != 4:
        print(sys.stderr, "usage: python3", sys.argv[0], "<peer-URL>", "<public-key>", "<private-key>")
        sys.exit(1)
    peer = sys.argv[1]

    miner_input = get_miner_input(peer)

    print("Startup mining info:")
    for key, value in miner_input.items():
        print(key, type(value), value)

    seed = deserialize_hash(get_seedhash(miner_input['block']))
    print("seed", "%064x" % decode_int(serialize_hash(seed)[::-1]), "\n   now acquiring cache...")
    cache = build_hash_struct(get_cache_size(miner_input['block']), seed, out_type='cache', coin='jng')
    print("cache completed. \n   now acquiring dag...")
    dataset = build_hash_struct(get_full_size(miner_input['block']), cache, out_type='dag', coin='jng')
    print("dataset completed. \n   now mining...")

    while True:
        nonce, out, block, header = mine_w_update(get_full_size(miner_input['block']), dataset, peer, miner_info=miner_input)

        miner_input = get_miner_input(peer)
        result = hashimoto_light(get_full_size(miner_input['block']), cache, miner_input['header'], nonce).get('mix digest')
        if result <= get_target_jh(miner_input['diff_int']):
            print("verification passed!")
        else:
            print("verification failed!")
