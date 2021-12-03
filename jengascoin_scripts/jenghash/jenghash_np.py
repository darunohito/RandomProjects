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
from multiprocessing import shared_memory


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

    dataset_shm = shared_memory.SharedMemory(create=True, size=full_size)
    # Now create a NumPy array backed by shared memory
    dataset = np.ndarray([total_size, HASH_BYTES // WORD_BYTES], dtype=np.uint32, buffer=dataset_shm.buf)

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
                print('\b', end = '')
            print_str = f"hashrate: {hashrate:6.2f} H/s, best hash: {decode_int(best_hash):078d}"
            print_len = len(print_str)
            print(print_str, end="")  # debug only!
    return nonce


# must be paired with function in calling program which writes/reads
# JSON-encoded dictionaries, and handles initialization.
# "mode" takes 'run' or 'init'
# "parent" takes 'miner' or 'node'
def miner_file_update(metadata=None, mode='run', parent='miner'):
    if parent == 'miner':
        file_name = {
            'out':  'miner_in.txt',
            'in':   'miner_out.txt'
        }
    elif parent == 'node':
        file_name = {
            'out':  'miner_out.txt',
            'in':   'miner_in.txt'
        }
    else:
        raise Exception(f"parent of 'miner' or 'node' expected, '{parent}' given")
    if mode == 'run':
        if metadata is None:
            metadata = {
                'update_period':    1.0,  # seconds, float
                'elapsed_time':     1.0   # seconds, float
            }
            hash_ceil = 10000
        hash_ceil = (hash_ceil * metadata['update_period']) // metadata['elapsed_time']
        # create file paths
        cwd = os.path.dirname(__file__)
        file_dir = os.path.join(cwd, 'miner_temp')

        if not os.path.exists(file_dir):
            os.mkdir(file_dir)
        # write metadata to output file
        with open(os.path.join(file_dir, file_name['out']), 'w') as f_out:
            json.dump(metadata, f_out)
            f_out.close()
        # overwrite metadata from input file
        with open(os.path.join(file_dir, file_name['in']), 'r') as f_in:
            f_in.close()
            metadata = json.load(f_in)

    elif mode == 'init':
        metadata = {
            # miner inputs
            'update_period': 1.0,  # seconds, float
            'diff': 2 ** 256,
            'header': '\xF0' * 32,
            # miner outputs
            'num_hashes': 0,
            'best_hash': get_target(2)
        }
        hash_ceil = 10000
    else:
        raise Exception(f"mode of [null], 'run' or 'init' expected, '{mode}' given")

    return metadata, hash_ceil


# miner returns nonce directly,
# but will listen in the "miner_in" file for updates from node
# and will write debug/metadata to "miner_out"
# "update_period" is in seconds
# "mode" takes 'run' or 'init'
def mine_to_file(full_size, dataset, threads=1):
    metadata, hash_ceil = miner_file_update(mode='init')
    out = {  # init output
        "mix digest":   '\xFF' * 32,
        "result":       '\xFF' * 32
    }
    nonce = []
    for i in range(threads):
        nonce[i] = random_nonce()
    target = get_target(metadata['diff'])
    while 1:
        n_hashes = 0
        while n_hashes < hash_ceil:
            out = hashimoto_full(full_size, dataset, metadata["header"], nonce)
            nonce = (nonce + 1) % 2 ** 64
            n_hashes += 1
            out_mix = out.get("mix digest")
            if out_mix < target:
                return nonce, out
            if out_mix < metadata['best_hash']:  # can be left out for efficiency
                metadata['best_hash'] = out_mix  # can be left out for efficiency
        metadata["num_hashes"] = n_hashes
        metadata, hash_ceil = miner_file_update(metadata, mode='run')


# ----- Defining the Seed Hash ------------------------------------------------


def get_seedhash(block):
    s = '\x00' * 32
    for i in range(block // EPOCH_LENGTH):
        s = serialize_hash(blake3_256(s))
    return s
