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
import base64
import codecs
import copy
import struct
import os
import pickle
import time
import numpy as np
# cimport numpy as np
import gc
from random import randint
import multiprocessing as mp
# from blake3 import blake3
import sha3
from blake3 import blake3
from joblib import Parallel, delayed
import json

from hash_utils import *


# sha3 hash function, outputs 64 bytes

def sha3_512(x):
    return hash_words(lambda v: sha3.keccak_512(v).digest(), 64, x)


def sha3_256(x):
    return hash_words(lambda v: sha3.keccak_256(v).digest(), 32, x)


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
            t_start = time.perf_counter()
            for i in range(0, row_length, thread_count*chunk_len):
                temp = np.asarray(parallel(delayed(calc_dataset_chunk)(seed, j, chunk_len)
                                           for j in range(i, i+thread_count*chunk_len, chunk_len)))
                for j in range(len(temp)):
                    for k in range(len(temp[j])):
                        if i + (j * chunk_len) + k < row_length:  # to keep from writing out of bounds
                            hash_struct[i + (j * chunk_len) + k] = temp[j, k]
                # IndexError: index 63832022 is out of bounds for axis 0 with size 63832022

                percent_done = (i + chunk_len) / row_length
                t_elapsed = time.perf_counter() - t_start
                print(f"\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b{(percent_done * 100):5.2f}%, "
                      f"ETA: {(t_elapsed / percent_done / 60):7.0f}m", end="")

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
    o[0] = sha3_512(seed)
    for i in range(1, n):
        o[i] = sha3_512(o[i-1])
    # Use a low-round version of randmemohash
    for _ in range(CACHE_ROUNDS):
        for i in range(n):
            v = o[i][0] % n
            # maps list to list, with xor function
            # sha expects bytes, mapping xor with integers returns
            # a list of 4-byte integers
            o_temp = int_list_to_bytes(list(map(xor, o[(i - 1 + n) % n], o[v])))
            o[i] = sha3_512(o_temp)
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
        mix = sha3_512(mix)
        # fnv it with a lot of random cache nodes based on i
        for j in range(DATASET_PARENTS):
            cache_index = fnv((i+i_start) ^ j, mix[j % r])
            mix = list(map(fnv, mix, cache[cache_index % n]))
        o[i] = sha3_512(mix)
    return o


def calc_dataset_item(cache, i):
    n = len(cache)
    r = HASH_BYTES // WORD_BYTES
    i = int(i)
    # initialize the mix
    mix = copy.copy(cache[i % n])
    mix[0] ^= i
    mix = sha3_512(mix)
    # fnv it with a lot of random cache nodes based on i
    for j in range(DATASET_PARENTS):
        cache_index = fnv(i ^ j, mix[j % r])
        mix = list(map(fnv, mix, cache[cache_index % n]))
    return sha3_512(mix)


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
            t_elapsed = time.perf_counter() - t_start
            print(
                f"\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b{(percent_done * 100):5.2f}%, "
                f"ETA: {(t_elapsed * (1/percent_done - 1) / 60):7.0f}m", end="")
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
    s = sha3_512(base)
    # start the mix with replicated s
    mix = []
    for _ in range(mix_hashes):
        mix.extend(s)
    # mix in random dataset nodes
    for i in range(ACCESSES):
        p = int(fnv(i ^ s[0], mix[i % w]) % (n // mix_hashes) * mix_hashes)
        new_data = []
        for j in range(mix_hashes):
            # new_data.extend(dataset_lookup(p + j))
            new_data.extend(dataset_lookup(p + j))
        mix = list(map(fnv, mix, new_data))
    # compress mix
    cmix = []
    for i in range(0, len(mix), 4):
        cmix.append(fnv(fnv(fnv(mix[i], mix[i + 1]), mix[i + 2]), mix[i + 3]))
    return {
        "mix digest": serialize_hash(cmix),
        "result": serialize_hash(sha3_256(s + cmix))
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
    # return encode_int(2 ** 256 - difficulty)
    return encode_int(2 ** 256 // difficulty).ljust(32, '\0')[::-1]
    # return zpad(encode_int(2 ** 256 // difficulty), 64)[::-1]


def random_nonce():
    return randint(0, 2 ** 64)


def mine(full_size, dataset, header, difficulty, nonce):
    print_interval = 1000  # debug only!
    nonce_tries = 0  # debug only!
    t_start = 0  # debug only!
    print_len = 0  # debug only!
    new_result = best_hash = get_target(2)  # debug only!
    target = get_target(difficulty)
    gc.collect()
    while new_result > target:
        nonce = (nonce + 1) % 2 ** 64
        if new_result < best_hash:  # debug only!
            best_hash = new_result  # debug only!
        new_result = hashimoto_full(full_size, dataset, header, nonce).get("mix digest")
        nonce_tries += 1  # debug only!
        if nonce_tries % print_interval == 0:  # debug only!
            t_stop = time.perf_counter()
            hashrate = print_interval / (t_stop - t_start)
            t_start = t_stop
            for _ in range(print_len):
                print('\b', end='')
            print_str = f"hashrate: {hashrate:6.2f} H/s, best hash: {decode_int(best_hash):078d}"
            print_len = len(print_str)
            print(print_str, end="")  # debug only!
    return nonce


# must be paired with function in calling program which writes/reads
# JSON-encoded dictionaries, and handles initialization.
def miner_file_update(metadata=None, mode='run'):
    if mode == 'run':
        if metadata is None:
            metadata = {
                'num_hashes':       1000,
                'update_period':    1.0,  # seconds, float
                'elapsed_time':     1.0   # seconds, float
            }
        hash_ceil = (metadata['num_hashes'] * metadata['update_period']) // metadata['elapsed_time']
        # create file paths
        cwd = os.path.dirname(__file__)
        file_dir = os.path.join(cwd, 'miner_temp')

        if not os.path.exists(file_dir):
            os.mkdir(file_dir)
        # write metadata to output file
        with open(os.path.join(file_dir, 'miner_out'), 'w') as f_out:
            json.dump(metadata, f_out)
            f_out.close()
        # overwrite metadata from input file
        with open(os.path.join(file_dir, 'miner_in'), 'r') as f_in:
            f_in.close()
            metadata = json.load(f_in)

    elif mode == 'init':
        metadata = {
            # miner inputs
            "diff": 2 ** 256,
            "header": '\xF0' * 32,
            # miner outputs
            'num_hashes': 0,
            'update_period': 1,  # seconds, float
            'best_hash': get_target(2)
        }
        hash_ceil = 1000
    else:
        raise Exception(f"mode of [null], 'run' or 'init' expected, '{mode}' given")

    return metadata, hash_ceil


# miner returns nonce directly to php call,
# but will listen in the "miner_in" file for updates from node
# and will write debug/metadata to miner_out
# "update_period" is in seconds
# "mode" takes 'run' or 'init'
def mine_to_file(full_size, dataset, threads=1):
    metadata, hash_ceil = miner_file_update(mode='init')
    n_hashes = 0
    out = {  # init output
        "mix digest":   '\xFF' * 32,
        "result":       '\xFF' * 32
    }
    nonce = []
    for i in range(threads):
        nonce[i] = random_nonce()
    target = get_target(metadata.get('diff'))
    while out.get("mix digest") > target:
        out = hashimoto_full(full_size, dataset, metadata["header"], nonce)
        nonce = (nonce + 1) % 2 ** 64
        n_hashes += 1
    return nonce


# ----- Defining the Seed Hash ------------------------------------------------


def get_seedhash(block):
    s = '\x00' * 32
    for i in range(block // EPOCH_LENGTH):
        s = serialize_hash(sha3_256(s))
    return s


if __name__ == "__main__":
    from subprocess import Popen, PIPE, STDOUT
    import sys
    # import sh
    from urllib.parse import urljoin
    from jh_definitions import *
    import json
    import base58



# ----- Main function ---------------------------------------------------------



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

    seed = deserialize_hash(get_seedhash(freeze_block))
    print("seed", "%064x" % decode_int(serialize_hash(seed)[::-1]), "\n   now acquiring cache...")
    cache = build_hash_struct(get_cache_size(freeze_block), seed, out_type='cache', coin='jng')
    print("cache completed. \n   now acquiring dag...")
    dataset = build_hash_struct(get_full_size(freeze_block), cache, out_type='dag', coin='jng', thread_count=threads)
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