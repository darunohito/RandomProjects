# cython: language_level=3

#!/usr/bin/python3.7

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
import numpy as np
cimport numpy as np
import gc
from random import randint
import multiprocessing as mp
from blake3 import blake3
import sha3
import codecs
import struct

np.import_array()

# ----- Definitions -- DO NOT CHANGE (or record backup before changing >.> ) --


cdef unsigned int WORD_BYTES = 4  # bytes in word
cdef unsigned long long DATASET_BYTES_INIT = 2 ** 30  # bytes in dataset at genesis
cdef unsigned long long DATASET_BYTES_GROWTH = 2 ** 23  # dataset growth per epoch
cdef unsigned long long CACHE_BYTES_INIT = 2 ** 24  # bytes in cache at genesis
cdef unsigned long CACHE_BYTES_GROWTH = 2 ** 17  # cache growth per epoch
cdef unsigned long EPOCH_LENGTH = 30000  # blocks per epoch
cdef unsigned int MIX_BYTES = 128  # width of mix
cdef unsigned int HASH_BYTES = 64  # hash length in bytes
cdef unsigned int DATASET_PARENTS = 256  # number of parents of each dataset element
cdef unsigned int CACHE_ROUNDS = 3  # number of rounds in cache production
cdef unsigned int ACCESSES = 64  # number of accesses in hashimoto loop


# ----- Appendix --------------------------------------------------------------


# change to cython/numpy array operation?
def decode_int(s):
    x = 0
    for i in range(len(s)):
        x += ord(s[i]) * pow(256, i)
    return x


# change to cython/numpy array operation?
def bytes_to_str(b):
    if isinstance(b, (bytes, bytearray)):
        return ''.join(map(chr, b))
    if isinstance(b, str):
        return b
    raise TypeError("Wanted bytes|bytearray, got ", type(b))


# change to cython/numpy array operation?
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

# change to cython/numpy array operation
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


cpdef np.uint32_t fnv(np.uint64_t v1, np.uint64_t v2):
    return ((v1 * FNV_PRIME) ^ v2) % 2 ** 32


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


def build_hash_struct(out_size, seed, out_type='cache', coin='eth'):
    # find directory and build file name
    if out_type == 'cache':
        name_temp = int_list_to_bytes(seed)
    elif out_type == 'dag':
        name_temp = seed[0]
    else:
        raise Exception(f"out_type of 'cache' or 'dag' expected, '{out_type}' given")
    short_name = sha3.keccak_256(name_temp).hexdigest()[0:15]
    name = out_type + '_L_' + str(out_size) + "_C_" + short_name + '.npy'
    cwd = os.path.dirname(__file__)
    file_dir = os.path.join(cwd, f"{coin}_{out_type}_dir")
    filepath = os.path.join(file_dir, name)

    # check for a saved hash structure
    if os.path.exists(filepath):
        print(f"loading {out_type} for length: ", out_size, " and short_name: ", short_name)
        with open(filepath, 'rb') as file:
            return np.load(filepath)
    print(f"  no saved {out_type} found, generating hash structure\n    this will take a while... ", end="")

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

    # save newly-generated hash structure
    if not os.path.exists(file_dir):
        os.mkdir(file_dir)
    with open(filepath, 'wb') as name:
        print(f"\nsaving {out_type} for length: ", out_size, " and short_name: ", short_name)
        np.save(filepath, hash_struct)

    return hash_struct


# ----- Cache Generation ------------------------------------------------------


cpdef np.ndarray mkcache(cache_size, seed):
    cdef np.uint32_t n = cache_size // HASH_BYTES
    t_start = time.perf_counter()
    # Sequentially produce the initial dataset
    # o_temp = np.empty([1, HASH_BYTES // WORD_BYTES], np.uint32)
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
            # o_temp = int_list_to_bytes(np.bitwise_xor(o[(i - 1 + n) % n], o[v]))
            # o_temp = int_list_to_bytes(list(map(xor, o[(i - 1 + n) % n], o[v])))
            o[i] = sha3_512(int_list_to_bytes(np.bitwise_xor(o[(i - 1 + n) % n], o[v])))
    t_elapsed = time.perf_counter() - t_start
    print("cache completed in [only!] ", t_elapsed, " seconds!  oWo  so fast")
    return o


# ----- Full dataset calculation ----------------------------------------------


def calc_dataset_item(np.ndarray[np.uint32_t, ndim=2] cache, np.uint64_t i):
    cdef np.uint32_t n = len(cache)
    cdef np.uint8_t r = HASH_BYTES // WORD_BYTES
    # initialize the mix
    # mix = copy.copy(cache[i % n])
    mix = np.ndarray.copy(cache[i % n])
    mix[0] ^= i
    mix = sha3_512(mix)
    # fnv it with a lot of random cache nodes based on i
    for j in range(DATASET_PARENTS):
        cache_index = fnv(i ^ j, mix[j % r])
        mix = list(map(fnv, mix, cache[cache_index % n]))
    return sha3_512(int_list_to_bytes(mix))


cpdef np.ndarray calc_dataset(np.uint64_t full_size, np.ndarray[np.uint32_t, ndim=2] cache):
    # generate the dataset
    cdef float t_start = time.perf_counter()
    cdef float t_elapsed = 0
    cdef float percent_done = 0
    print("percent done:       ", end="")
    total_size = full_size // HASH_BYTES
    dataset = np.empty([total_size, HASH_BYTES // WORD_BYTES], np.uint32)
    for i in range(total_size):
        dataset[i] = calc_dataset_item(cache, i)
        if (i / total_size) > percent_done + 0.0001:
            percent_done = i / total_size
            t_elapsed = time.perf_counter() - t_start
            print(f"\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b{(percent_done * 100):5.2f}%, ETA: {(t_elapsed / percent_done / 60):7.0f}m", end="")
    print("DAG completed in [only!] ", t_elapsed, " seconds!  oWo  so fast")

    return dataset


# ----- Main Loop -------------------------------------------------------------
##
## FNV_PRIME = 0x01000193
##
##
## def np.uint32_t fnv(np.uint64_t v1, np.uint64_t v2):
##     return ((v1 * FNV_PRIME) ^ v2) % 2 ** 32 
##

def hashimoto(header, np.uint64_t nonce, np.uint64_t full_size, dataset_lookup):
    cdef unsigned long long n = full_size // HASH_BYTES
    cdef unsigned int w = MIX_BYTES // WORD_BYTES
    cdef unsigned int mix_hashes = MIX_BYTES // HASH_BYTES
    cdef unsigned int mix_bytes = HASH_BYTES // WORD_BYTES
    # combine header+nonce into a 64 byte seed
    base = str_to_bytes(header) + struct.pack("<Q", nonce)
    s = sha3_512(base)
    # start the mix with replicated s
    mix = np.tile(s, mix_hashes)
    # mix = []
    # for _ in range(mix_hashes):
    #     mix.extend(s)
    # mix in random dataset nodes
    for i in range(ACCESSES):
        p = int(fnv(i ^ s[0], mix[i % w]) % (n // mix_hashes) * mix_hashes)
        new_data = np.empty([HASH_BYTES // WORD_BYTES * mix_hashes], np.uint32)
        for j in range(mix_hashes):
            # new_data.extend(dataset_lookup(p + j))
            new_data = np.insert(new_data, j*mix_bytes,dataset_lookup(p + j))
        mix = list(map(fnv, mix, new_data))
    # compress mix
    cmix = []
    for i in range(0, len(mix), 4):
        cmix.append(fnv(fnv(fnv(mix[i], mix[i + 1]), mix[i + 2]), mix[i + 3]))
    return {
        "mix digest": serialize_hash(cmix),
        "result": serialize_hash(sha3_256(s + cmix))
    }


def hashimoto_light(np.uint64_t full_size, cache, header, np.uint64_t nonce):
    return hashimoto(header, nonce, full_size,
                     lambda x: calc_dataset_item(cache, x))


def hashimoto_full(np.uint64_t full_size, dataset, header, np.uint64_t nonce):
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


# ----- Defining the Seed Hash ------------------------------------------------


def get_seedhash(block):
    s = '\x00' * 32
    for i in range(block // EPOCH_LENGTH):
        s = serialize_hash(sha3_256(s))
    return s
