# cython: language_level=3

#!/usr/bin/python3.7

import copy
import os
import time
import numpy as np
cimport numpy as np
import gc
from random import randint
import multiprocessing as mp
from blake3 import blake3
import codecs
import struct
from jh_definitions import *


np.import_array()


cdef unsigned int       C_WORD_BYTES = WORD_BYTES # bytes in word
cdef unsigned long long C_DATASET_BYTES_INIT = DATASET_BYTES_INIT # bytes in dataset at genesis
cdef unsigned long long C_DATASET_BYTES_GROWTH = DATASET_BYTES_GROWTH  # dataset growth per epoch
cdef unsigned long long C_CACHE_BYTES_INIT = CACHE_BYTES_INIT  # bytes in cache at genesis
cdef unsigned long      C_CACHE_BYTES_GROWTH = CACHE_BYTES_GROWTH  # cache growth per epoch
cdef unsigned long      C_EPOCH_LENGTH = EPOCH_LENGTH   # blocks per epoch
cdef unsigned long long int       C_MIX_BYTES = MIX_BYTES   # width of mix
cdef unsigned int       C_HASH_BYTES = HASH_BYTES   # hash length in bytes
cdef unsigned int       C_DATASET_PARENTS = DATASET_PARENTS   # number of parents of each dataset element
cdef unsigned int       C_CACHE_ROUNDS = CACHE_ROUNDS   # number of rounds in cache production
cdef unsigned int       C_ACCESSES = ACCESSES   # number of accesses in hashimoto loop


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
    return [decode_int(h[i:i + C_WORD_BYTES])
            for i in range(0, len(h), C_WORD_BYTES)]

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

# blake3 hash function, outputs 32 bytes unless otherwise specified

def blake3_512(x):
    h = hash_words(lambda v: blake3(v).digest(length=64), 64, x)
    return h


def blake3_256(x):
    h = hash_words(lambda v: blake3(v).digest(), 32, x)
    return h


# ----- Parameters ------------------------------------------------------------


def get_cache_size(block_number):
    sz = C_CACHE_BYTES_INIT + \
         C_CACHE_BYTES_GROWTH * (block_number // C_EPOCH_LENGTH)
    sz -= C_HASH_BYTES
    while not isprime(sz / C_HASH_BYTES):
        sz -= 2 * C_HASH_BYTES
    return sz


def get_full_size(block_number):
    sz = C_DATASET_BYTES_INIT + \
         C_DATASET_BYTES_GROWTH * (block_number // C_EPOCH_LENGTH)
    sz -= C_MIX_BYTES
    while not isprime(sz / C_MIX_BYTES):
        sz -= 2 * C_MIX_BYTES
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
    print(f"  no saved {out_type} found, generating hash structure\n     this will take a while... ", end="")

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


cpdef np.ndarray mkcache(cache_size, seed):
    cdef np.uint32_t n = cache_size // C_HASH_BYTES
    t_start = time.perf_counter()
    # Sequentially produce the initial dataset
    # o_temp = np.empty([1, C_HASH_BYTES // C_WORD_BYTES], np.uint32)
    o = np.empty([n, C_HASH_BYTES // C_WORD_BYTES], np.uint32)
    o[0] = blake3_512(seed)
    for i in range(1, n):
        o[i] = blake3_512(int_list_to_bytes(o[i-1]))
    # Use a low-round version of randmemohash
    for _ in range(C_CACHE_ROUNDS):
        for i in range(n):
            v = o[i][0] % n
            # maps list to list, with xor function
            # blake3 expects bytes, mapping xor with integers returns
            # a list of 4-byte integers
            # o_temp = int_list_to_bytes(np.bitwise_xor(o[(i - 1 + n) % n], o[v]))
            # o_temp = int_list_to_bytes(list(map(xor, o[(i - 1 + n) % n], o[v])))
            o[i] = blake3_512(int_list_to_bytes(np.bitwise_xor(o[(i - 1 + n) % n], o[v])))
    t_elapsed = time.perf_counter() - t_start
    print("cache completed in [only!] ", t_elapsed, " seconds!  oWo  so fast")
    return o


# ----- Full dataset calculation ----------------------------------------------


def calc_dataset_item(np.ndarray[np.uint32_t, ndim=2] cache, np.uint64_t i):
    cdef np.uint32_t n = len(cache)
    cdef np.uint8_t r = C_HASH_BYTES // C_WORD_BYTES
    # initialize the mix
    # mix = copy.copy(cache[i % n])
    mix = np.ndarray.copy(cache[i % n])
    mix[0] ^= i
    mix = blake3_512(int_list_to_bytes(mix))
    # fnv it with a lot of random cache nodes based on i
    for j in range(C_DATASET_PARENTS):
        cache_index = fnv(i ^ j, mix[j % r])
        mix = list(map(fnv, mix, cache[cache_index % n]))
    return blake3_512(int_list_to_bytes(mix))


cpdef np.ndarray calc_dataset(np.uint64_t full_size, np.ndarray[np.uint32_t, ndim=2] cache):
    # generate the dataset
    cdef float t_start = time.perf_counter()
    cdef float t_elapsed = 0
    cdef float percent_done = 0
    print("percent done:       ", end="")
    total_size = full_size // C_HASH_BYTES
    dataset = np.empty([total_size, C_HASH_BYTES // C_WORD_BYTES], np.uint32)
    for i in range(total_size):
        dataset[i] = calc_dataset_item(cache, i)
        if (i / total_size) > percent_done + 0.0001:
            percent_done = i / total_size
            t_elapsed = time.perf_counter() - t_start
            print(f"\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b{(percent_done * 100):5.2f}%, ETA: {(t_elapsed / percent_done / 60):7.0f}m", end="")
    print("DAG completed in [only!] ", t_elapsed, " seconds!  oWo  so fast")

    return dataset


# ----- Main Loop -------------------------------------------------------------


def hashimoto(header, np.uint64_t nonce, np.uint64_t full_size, dataset_lookup):
    cdef unsigned long long n = full_size // C_HASH_BYTES
    cdef unsigned long int w = C_MIX_BYTES // C_WORD_BYTES
    cdef unsigned int mix_hashes = C_MIX_BYTES // C_HASH_BYTES
    cdef unsigned int mix_bytes = HASH_BYTES // WORD_BYTES
    # combine header+nonce into a 64 byte seed
    base = str_to_bytes(header) + struct.pack("<Q", nonce)
    s = blake3_512(base)
    # start the mix with replicated s
    mix = np.tile(s, mix_hashes)

    # mix in random dataset nodes
    for i in range(C_ACCESSES):
        p = int(fnv(i ^ s[0], mix[i % w]) % (n // mix_hashes) * mix_hashes)
        new_data = np.empty([C_HASH_BYTES // C_WORD_BYTES * mix_hashes], np.uint32)
        # new_data = np.empty([C_MIX_BYTES * mix_hashes], np.uint32)
        for j in range(mix_hashes):
            # new_data.extend(dataset_lookup(p + j))
            new_data = np.insert(new_data, j*mix_bytes, dataset_lookup(p + j))
        mix = list(map(fnv, mix, new_data))
    # compress mix
    cmix = []
    for i in range(0, len(mix), 4):
        cmix.append(fnv(fnv(fnv(mix[i], mix[i + 1]), mix[i + 2]), mix[i + 3]))
    return {
        "mix digest": serialize_hash(cmix),
        "result": serialize_hash(blake3_256(s + cmix))
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
    # byte strings are little-endian
    return encode_int(2 ** 256 // difficulty).ljust(32, '\0')[::-1]
    # return zpad(encode_int(2 ** 256 // difficulty), 64)[::-1]


def random_nonce():
    return randint(0, 2 ** 64)


def mine(full_size, dataset, header, difficulty, nonce):
    target = get_target(difficulty)
    # while new_result > target:
    # while decode_int(new_result) * difficulty > 2**256:
    while hashimoto_full(full_size, dataset, header, nonce).get("mix digest") > target:
        nonce = (nonce + 1) % 2 ** 64
        # new_result = hashimoto_full(full_size, dataset, header, nonce).get("mix digest")
    return nonce


# ----- Defining the Seed Hash ------------------------------------------------


def get_seedhash(block):
    s = '\x00' * 32
    for i in range(block // C_EPOCH_LENGTH):
        s = serialize_hash(blake3_256(s))
    return s
