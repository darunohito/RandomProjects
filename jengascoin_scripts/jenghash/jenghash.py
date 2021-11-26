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

import codecs
import copy
import struct
from random import randint
from blake3 import blake3

# ----- Definitions -----------------------------------------------------------


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
    # s = s[::-1]
    x = 0
    for i in range(len(s)):
        # x[i] = ord(s[i])
        x += ord(s[i]) * pow(256, i)
    return x
    # return int(s[::-1].encode('hex'), 16) if s else 0


def bytes_to_str(b):
    if isinstance(b, (bytes, bytearray)):
        b = ''.join(map(chr, b))
    return b


def encode_int(s):
    a = "%x" % s
    x = codecs.decode('0' * (len(a) % 2) + a, 'hex')[::-1]
    x = bytes_to_str(x)
    return '' if s == 0 else x
    # return '' if s == 0 else ('0' * (len(a) % 2) + a).decode('hex')[::-1]


def zpad(s, length):
    return s + '\x00' * max(0, length - len(s))


def int_list_to_bytes(list):
    b = struct.pack("{}I".format(len(list)), *list)
    # print("bytes: ", b)
    return b


def serialize_hash(h):
    h_serial = ''.join([zpad(encode_int(x), 4) for x in h])
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


# blake3 hash function, outputs 32 bytes unless otherwise specified

def blake3_512(x):
    h = hash_words(lambda v: blake3(v).digest(length=64), 64, x)
    return h


def blake3_256(x):
    h = hash_words(lambda v: blake3(v).digest(), 32, x)
    return h


def xor(a, b):
    return a ^ b


def isprime(x):
    for i in range(2, int(x ** 0.5)):
        if x % i == 0:
            return False
    return True


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


# ----- Cache Generation ------------------------------------------------------


def mkcache(cache_size, seed):
    n = cache_size // HASH_BYTES

    # Sequentially produce the initial dataset
    o = [blake3_512(seed)]
    for i in range(1, n):
        o.append(blake3_512(o[-1]))

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


# ----- Data aggregation function ---------------------------------------------


FNV_PRIME = 0x01000193


def fnv(v1, v2):
    return ((v1 * FNV_PRIME) ^ v2) % 2 ** 32


# ----- Full dataset calculation ----------------------------------------------


def calc_dataset_item(cache, i):
    n = len(cache)
    r = HASH_BYTES // WORD_BYTES
    i = int(i)
    # initialize the mix
    mix = copy.copy(cache[i % n])
    mix[0] ^= int(i)
    mix = blake3_512(mix)
    # fnv it with a lot of random cache nodes based on i
    for j in range(DATASET_PARENTS):
        cache_index = fnv(i ^ j, mix[j % r])
        mix = list(map(fnv, mix, cache[cache_index % n]))
    return blake3_512(int_list_to_bytes(mix))


def calc_dataset(full_size, cache):
    return [calc_dataset_item(cache, i)
            for i in range(full_size // HASH_BYTES)]


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
        p = fnv(i ^ s[0], mix[i % w]) % (n // mix_hashes) * mix_hashes
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
    return zpad(encode_int(2 ** 256 // difficulty), 64)[::-1]


def random_nonce():
    return randint(0, 2 ** 64)


def mine(full_size, dataset, header, difficulty, nonce):
    target = get_target(difficulty)
    while hashimoto_full(full_size, dataset, header, nonce) > target:
        nonce = (nonce + 1) % 2 ** 64
    return nonce


# ----- Defining the Seed Hash ------------------------------------------------


def get_seedhash(block):
    s = '\x00' * 32
    for i in range(block // EPOCH_LENGTH):
        s = serialize_hash(blake3_256(s))
    return s
