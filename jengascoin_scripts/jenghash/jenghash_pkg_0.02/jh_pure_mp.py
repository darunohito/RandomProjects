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
import codecs
import struct
import numpy as np
from random import randint
from blake3 import blake3
from binascii import hexlify
import multiprocessing as mp
from multiprocessing.managers import SharedMemoryManager
from jh_definitions import *
from joblib import Parallel, delayed
from itertools import repeat




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


# ----- Appendix --------------------------------------------------------------


def decode_int(s):
    x = 0
    for i in range(len(s)):
        x += ord(s[i]) * pow(256, i)
    return x


def bytes_to_str(b):
    if isinstance(b, (bytes, bytearray)):
        return ''.join(map(chr, b))
    if isinstance(b, str):
        return b
    raise TypeError("Wanted bytes|bytearray, got ", type(b))


def encode_int(s):
    a = "%x" % s
    x = codecs.decode('0' * (len(a) % 2) + a, 'hex')[::-1]
    x = bytes_to_str(x)
    return '' if s == 0 else x


def zpad(s, length):
    return s.ljust(length, '\0')


def int_list_to_bytes(ls):
    return struct.pack("{}I".format(len(ls)), *ls)


def serialize_hash(h):
    h_serial = ''.join([encode_int(x).ljust(4, '\0') for x in h])
    return h_serial


def deserialize_hash(h):
    h = bytes_to_str(h)
    # print("h to deserialize: ", h, ", type: ", type(h))
    return [decode_int(h[i:i + WORD_BYTES])
            for i in range(0, len(h), WORD_BYTES)]


def str_to_bytes(s):
    s_ints = [0] * len(s)
    for i in range(len(s)):
        s_ints[i] = ord(s[i])
    return bytearray(s_ints)


def hash_words(h, sz, x):
    if isinstance(x, list):
        x = serialize_hash(x)
    if isinstance(x, str):
        x = str_to_bytes(x)
    y = h(x)
    return deserialize_hash(y)


def xor(a, b):
    return a ^ b


def isprime(x):
    for i in range(2, int(x ** 0.5)):
        if x % i == 0:
            return False
    return True


# ----- Data aggregation function ---------------------------------------------


FNV_PRIME = 0x01000193


def fnv(v1, v2):
    return ((v1 * FNV_PRIME) ^ v2) % 2 ** 32



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


def build_hash_struct(out_size, seed, out_type='cache', coin='jng', thread_count=1):
    # find directory and build file name
    if out_type == 'cache':
        name_temp = int_list_to_bytes(seed)
    elif out_type == 'dag':
        name_temp = int_list_to_bytes(seed[0])
    else:
        raise Exception(f"out_type of 'cache' or 'dag' expected, '{out_type}' given")
    short_name = blake3(name_temp).hexdigest(length=16)
    row_length = out_size // HASH_BYTES
    name = out_type + '_L_' + str(row_length) + "_C_" + short_name + '.npy'
    cwd = os.path.dirname(__file__)
    file_dir = os.path.join(cwd, f"{coin}_{out_type}_dir")
    filepath = os.path.join(file_dir, name)

    # check for a saved hash structure
    if os.path.exists(filepath):
        print(f"loading {out_type} for length: ", row_length, " and short_name: ", short_name)
        with open(filepath, 'rb') as file:
            return np.load(filepath)
    print(f"  no saved {out_type} found, generating hash structure\n \
         this will take a while... ", end="")

    # since no saved structure exists, build from scratch
    if out_type == 'cache':
        hash_struct = mkcache(cache_size=out_size, seed=seed)
    elif out_type == 'dag':
        hash_struct = np.empty([row_length, HASH_BYTES // WORD_BYTES], np.uint32)
        chunk_len = 1024

        with Parallel(n_jobs=thread_count) as parallel:  # multiprocessing
            percent_done = 0
            t_start = time.perf_counter()
            for i in range(0, row_length, thread_count*chunk_len):
                temp = np.asarray(parallel(delayed(calc_dataset_chunk)(seed, j, chunk_len)
                                           for j in range(i, i+thread_count*chunk_len, chunk_len)))
                for j in range(len(temp)):
                    for k in range(len(temp[j])):
                        hash_struct[i+(j*chunk_len)+k] = temp[j, k]

                percent_done = i / row_length + 0.0000001
                t_elapsed = time.perf_counter() - t_start
                print(f"\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b{(percent_done * 100):5.2f}%, "
                      f"ETA: {(t_elapsed / percent_done / 60):7.0f}m", end="")

            for i in range(row_length - (row_length % (thread_count * chunk_len))-1, row_length):
                hash_struct[i] = calc_dataset_item(cache, i)

        # with Parallel(n_jobs=thread_count) as parallel:  # multiprocessing
        #     percent_done = 0
        #     t_start = time.perf_counter()
        #     for i in range(0, row_length, thread_count):
        #         temp = parallel(delayed(calc_dataset_item)(seed, j) for j in range(i, i+thread_count))
        #         for k in range(len(temp)):
        #             hash_struct[i+k] = temp[k]
        #
        #         if (i / row_length) > percent_done + 0.0001:
        #             percent_done = i / row_length
        #             t_elapsed = time.perf_counter() - t_start
        #             print(f"\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b{(percent_done * 100):5.2f}%, "
        #                   f"ETA: {(t_elapsed / percent_done / 60):7.0f}m", end="")
        #
        #     for i in range(row_length - (row_length % thread_count), row_length):
        #         hash_struct[i] = calc_dataset_item(cache, i)

        # c_shm.close()
        # d_shm.close()
        print(f"elapsed time: {(time.perf_counter() - t_start)/60:.1f} minutes")
    else:
        raise Exception(f"out_type of 'cache' or 'dag' expected, '{out_type}' given")

    # save newly-generated hash structure
    if not os.path.exists(file_dir):
        os.mkdir(file_dir)
    with open(filepath, 'wb') as name:
        print(f"\nsaving {out_type} for length: ", row_length, " and short_name: ", short_name)
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


def calc_dataset_chunk(cache, i_start, chunk_len=1):
    n = len(cache)
    r = HASH_BYTES // WORD_BYTES
    i_start = int(i_start)
    o = np.empty([chunk_len, 16], dtype=np.uint32)
    # initialize the mix
    for i in range(chunk_len):
        mix = copy.copy(cache[(i+i_start) % n])
        mix[0] ^= i
        mix = blake3_512(int_list_to_bytes(mix))
        # fnv it with a lot of random cache nodes based on i
        for j in range(DATASET_PARENTS):
            cache_index = fnv((i+i_start) ^ j, mix[j % r])
            mix = list(map(fnv, mix, cache[cache_index % n]))
        o[i] = blake3_512(int_list_to_bytes(mix))
    return o


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
    
    
def calc_dataset_inplace(start, stop, cache, dataset):
    # generate the dataset
    for i in range(start, stop):
        dataset[i] = calc_dataset_item(cache, i)
    return 


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


# Jengascoin currently uses subtractive difficulty (not division-scaled)
def get_target_jh(difficulty):
    test_target = 2 ** 256 // 30000  # DEBUG AND TEST ONLY!
    # byte strings are little-endian, have to reverse for target comparison
    # *************************************************************************
    return encode_int(test_target - difficulty).ljust(32, '\0')[::-1]  # DEBUG AND TEST ONLY!
    # *************************************************************************
    # return encode_int(2 ** 256 - difficulty).ljust(32, '\0')[::-1]


def mine_w_update(full_size, dataset, peer_url, miner_info=None, update_period=3.0, frozen=False, metadata=None):
    if isinstance(metadata, dict):
        _metadata = metadata
    else:
        _metadata = {
            'hash_ceil': 1000,
            'elapsed': update_period
        }
    if miner_info is None:
        miner_info = get_miner_input(peer_url, frozen)
    target = get_target_jh(miner_info['diff_int'])

    def reset_miner(_update_period, __metadata):
        print(f"hashrate: {__metadata['hash_ceil']/__metadata['elapsed']:.0f} H/s, block: ",
              miner_info['block'], ", header: ", miner_info['header_b58'])
        __metadata.update({
            'hash_ceil': (__metadata['hash_ceil'] * _update_period) // __metadata['elapsed'],
            'num_hashes': 0,  # initialization value
            'best_hash': get_target_jh(1),  # initialization value
            't_start': time.perf_counter()
        })
        return __metadata

    md = reset_miner(update_period, _metadata)
    nonce = random_nonce()

    while True:
        while md['num_hashes'] < md['hash_ceil']:
            out = hashimoto_full(full_size, dataset, miner_info['header'], nonce)
            if out['mix digest'] < md['best_hash']:
                if out['mix digest'] < target:
                    return nonce, out, miner_info['block'], miner_info['header'], md
                md['best_hash'] = out['mix digest']
            nonce = (nonce + 1) % 2 ** 64
            md['num_hashes'] += 1
        miner_info = get_miner_input(peer_url, _frozen=frozen)
        if miner_info['new']:
            md['elapsed'] = time.perf_counter()-md['t_start']
            md = reset_miner(update_period, md)
            target = get_target_jh(miner_info['diff_int'])


def parse_mining_input(miner_in, __frozen=False):
    miner_input_parsed = {
        'diff': hex(int(miner_in['difficulty'])),
        'diff_int': int(miner_in['difficulty']),
        'header': '0x' + base58.b58decode(miner_in['block']).hex(),  # "block" is actually hash of last block
        'header_b58': miner_in['block'],
        'block': miner_in['height'],  # "height" is actually "block" number, for ethash
    }
    if miner_in['old_hdr'] != miner_input_parsed['header']:
        miner_input_parsed['new'] = True
    else:
        miner_input_parsed['new'] = False
    # *************************************************************************
    if __frozen:  # DEBUG AND TEST ONLY!
        miner_input_parsed['block'] = 10 * EPOCH_LENGTH
    # *************************************************************************
    return miner_input_parsed


def get_miner_input(peer_url, hdr=None, _frozen=False):
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
    return parse_mining_input(miner_in, __frozen=_frozen)


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
    if len(sys.argv) < 4 or len(sys.argv) > 6:
        print(sys.stderr, "usage: python3", sys.argv[0], "<peer-URL>", "<public-key>", "<private-key>", "(opt)threads", "(opt)freeze")
        sys.exit(1)
    peer = sys.argv[1]

    threads = 1
    if len(sys.argv) > 4:
        threads = int(sys.argv[4])
    freeze = False
    freeze_block = 300000
    if len(sys.argv) == 6:
        if sys.argv[5] == "freeze" or sys.argv[5] == "f":
            print("DEBUG MODE: BLOCK HEIGHT FROZEN")
            freeze = True  # FROZEN ONLY FOR DEBUG & TEST

    miner_input = get_miner_input(peer, _frozen=freeze)  # FROZEN ONLY FOR DEBUG & TEST

    print("Startup mining info:")
    for key, value in miner_input.items():
        print(key, type(value), value)

    seed = deserialize_hash(get_seedhash(miner_input['block']))
    print("seed", "%064x" % decode_int(serialize_hash(seed)[::-1]), "\n   now acquiring cache...")
    cache = build_hash_struct(get_cache_size(miner_input['block']), seed, out_type='cache', coin='jng')
    print("cache completed. \n   now acquiring dag...")
    dataset = build_hash_struct(get_full_size(miner_input['block']), cache, out_type='dag', coin='jng', thread_count=threads)
    print("dataset completed. \n   now mining...")

    found = 0
    verified = 0
    _md = None
    while True:  # FROZEN ONLY FOR DEBUG & TEST
        nonce, out, block, header, _md = mine_w_update(get_full_size(miner_input['block']),
                                                  dataset, peer, miner_input, 3.0, freeze, _md)
        found += 1
        miner_input = get_miner_input(peer, header, freeze)
        result = hashimoto_light(get_full_size(miner_input['block']), cache,
                                 miner_input['header'], nonce).get('mix digest')
        if result <= get_target_jh(miner_input['diff_int']):
            verified += 1
            print("block found...verification passed!    oWo    found: %d, verified: %d" % (found, verified))
        else:
            print("block found...verification failed!    >:(    found: %d, verified: %d" % (found, verified))
