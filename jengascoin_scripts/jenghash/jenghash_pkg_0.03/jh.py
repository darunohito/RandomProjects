#!/usr/bin/python3.10

# Jengascoin/Ethash mining algorithm

#
# Requires:
#  python3
#  blake3
#  base58
#  requests
#  joblib
#  numpy
#


import copy
import os
import time
import pickle
import codecs
import struct
import numpy as np
from random import randint
from blake3 import blake3
import base58
import requests
from urllib.parse import urljoin
from joblib import Parallel, delayed


# ----- Parameters ------------------------------------------------------------


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
JENESIS = 'Satoshi is a steely-eyed missile man'
MAX_CHAIN_TARGET = 0x8FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF  # modified

URL_PATH = {
    'MINE_SOLO':        '/api.php?q=getMiningInfo',
    'SUBMIT_SOLO':      '/api.php?q=submitNonce',
    'GET_BLOCK':       '/api.php?q=getBlock'  # =integer
}


# ----- Main function ---------------------------------------------------------


if __name__ == "__main__":
    import sys

    # example call:      <node address>
    # python3 jh.py http://peer1.jengas.io/ <public-key> <private-key>
    if len(sys.argv) < 4 or len(sys.argv) > 6:
        print(sys.stderr, "usage: python3", sys.argv[0], "<node-URL>", "<public-key>", "<private-key>", "(opt)cores", "(opt)freeze")
        sys.exit(1)
    node = sys.argv[1]

    cores = 1
    if len(sys.argv) > 4:
        cores = int(sys.argv[4])
    freeze = False
    freeze_block = 300000
    if len(sys.argv) == 6:
        if sys.argv[5] == "freeze" or sys.argv[5] == "f":
            print("DEBUG MODE: BLOCK HEIGHT FROZEN")
            freeze = True  # FROZEN ONLY FOR DEBUG & TEST


# ----- Classes ---------------------------------------------------------------


class Verifier:  # high-level class

    # must be initialized with either local chainState dictionary or node_url
    def __init__(self, size_max=1, chain_state=None, node_url=None, tiny=False):
        self.tiny = tiny
        self.sizeMax = size_max
        if isinstance(chain_state, dict):
            self.chainState = chain_state
        # init ultralight verifier link (link only useful for dev)
        elif isinstance(node_url, str):  # if ultralight verifier
            self.link = Link(node_url)  # check status of node chain
            self.chainState = self.link.chainState
        print("Initial Chain State/Verifier Info: \n", self.chainState)
        self.target = get_target(self.chainState['diff_int'])
        # init verifier smith
        self.seeds = get_seedset(self.chainState['block'])
        self.smith = Smith(self.seeds, self.sizeMax, tiny=self.tiny)
        # build cache for current epoch
        self.smith.cache = self.smith.build_hash_struct('cache')

    # ultralight verifier link update (link only useful for dev)
    def node_update(self):
        self.chainState = self.link.get_miner_input()

    # mix_digest, s_cmix_hash, nonce, header, and size_scalar are miner inputs to the verifier
    def verify(self, mix_digest, s_cmix_hash, nonce, header, size_scalar):
        if header != self.chainState['header']:
            return False, 'header does not match'  # DDoS protection layer 1
        elif mix_digest > self.target:
            return False, 'mix digest > target'  # layer 2
        res = serialize_hash(blake3_256(blake3_512(str_to_bytes(self.chainState['header'])
                                                   + struct.pack("<Q", nonce)) + mix_digest))
        if res != s_cmix_hash:
            return False, 's_cmix_hash does not match header and mix digest hash result'  # layer 3
        self.smith.sizeScalarAlt = size_scalar
        mix_digest_check = self.hashimoto_light(self.smith.get_full_size(size_scalar), self.smith.cache,
                                  self.chainState['header'], nonce)['mix digest']
        if mix_digest_check == mix_digest:
            return True, 'nonce good'  # actual nonce check
        else:
            return False, 'mix digest does not match hashimoto_light result'

    def hashimoto_light(self, full_size, cache, header, nonce):
        return hashimoto(header, nonce, full_size,
                         lambda x: self.smith.calc_dataset_item(x))


class Miner:  # high-level class

    # must be initialized with either local chainState dictionary or node_url
    def __init__(self, size_scalar, public_key, private_key=None,
                 chain_state=None, node_url=None, cores=1, init_build=False, tiny=False):
        # init static vars
        self.tiny = tiny
        self.creds = {'pubKey': public_key, 'priKey': private_key}
        self.specs = {'sizeScalar': size_scalar, 'cores': cores}
        # Check if mining on local node or server node
        if isinstance(chain_state, dict):
            self.chainState = chain_state
        elif isinstance(node_url, str):  # if ultralight verifier
            self.link = Link(node_url)  # check status of node chain
            self.chainState = self.link.chainState
        print("Initial Chain State/Miner Info: \n", self.chainState)
        self.target = get_target(self.link.chainState['diff_int'], int(MAX_CHAIN_TARGET))
        # init miner smith
        self.seeds = get_seedset(self.link.chainState['block'])
        self.smith = Smith(self.seeds, self.specs['sizeScalar'], self.creds['pubKey'],
                           self.specs['cores'], tiny=self.tiny)
        if init_build:
            # build cache and dagger for current epoch
            self.smith.cache = self.smith.build_hash_struct('cache')
            self.smith.dagger = self.smith.build_hash_struct('dag')

    @staticmethod
    def random_nonce():
        return randint(0, 2 ** 64)

    def mine(self, full_size, dataset, header, difficulty, nonce):
        while hashimoto_full(full_size, dataset, header, nonce).get("mix digest") > self.target:
            nonce = (nonce + 1) % 2 ** 64
        return nonce


class Link:  # low-level class, for linking miners/verifiers to nodes/peers

    def __init__(self, link_url):
        self.url = link_url
        self.header = ''
        self.chainState = self.get_miner_input()

    def get_miner_input(self):
        return self.parse_mining_input(self.node_request(URL_PATH['MINE_SOLO'])['data'])

    @staticmethod
    def parse_mining_input(miner_input):
        miner_input_parsed = {
            'diff': hex(int(miner_input['difficulty'])),
            'diff_int': int(miner_input['difficulty']),
            'header_hex': '0x' + base58.b58decode(miner_input['block']).hex(),  # "block" is actually hash of last block
            'header_b58': miner_input['block'],
            'block': miner_input['height'],  # "height" is actually "block" number, for ethash
        }
        hdr = encode_int(int(miner_input_parsed['header_hex'], base=16))
        miner_input_parsed['header'] = '\x00' * (32 - len(hdr)) + hdr
        return miner_input_parsed

    def get_node_block(self, block_height):
        height_param = {'height': block_height}
        return self.node_request(URL_PATH['GET_BLOCK'], params_dict=height_param)

    # ----- TESTNET ONLY ----- #
    def submit_solution(self, submission_dict):
        return self.node_request(URL_PATH['SUBMIT_SOLO'], method='post', params_dict=submission_dict)
    # ----- TESTNET ONLY ----- #

    # params_dict example: {'nonce': 1234, 'public_address': 'J2034'}
    # node_request function only supports GET and POST methods
    def node_request(self, command_string, method='get', params_dict=None):
        if method == 'get':
            if isinstance(params_dict, dict):
                for k, v in params_dict.items():
                    # format:  "&public_key=key"
                    command_string += f"&{str(k)}={str(v)}"
            print(urljoin(self.url, command_string))
            r = requests.get(urljoin(self.url, command_string))
        elif method == 'post':
            print(urljoin(self.url, command_string))
            r = requests.post(urljoin(self.url, command_string), data=params_dict)
        else:
            raise Exception(f"invalid node_request 'method' parameter {method}")
        json_out = r.json()
        if json_out['status'] == 'error':
            print(json_out['data'])
            # sys.exit(1)
        return json_out


class Smith:  # low-level class, for managing caches and datasets for miners/verifiers

    def __init__(self, seeds, size_scalar=1, cores=1, key=None, tiny=False, tiny_div=100):
        self.tiny = tiny  # used for quick-run tests with small datasets
        self.tinyDiv = tiny_div
        self.sizeScalar = size_scalar
        self.sizeScalarAlt = 1  # reserved for future functionality, for use with Verifier class
        self.cacheSize = self.get_cache_size()
        print(f"Smith cache size: {self.cacheSize}")
        self.dagSize = self.get_full_size()
        print(f"Smith dagger size: {self.dagSize}")
        self.seeds = seeds
        self.key = key  # reserved for future functionality
        self.cores = cores
        self.cache = None
        self.dagger = None

    # for Jengascoin use, set size_scalar=<dataset_size> [in integer *Gibibytes*]
    def get_cache_size(self, alt_scalar=False):
        scalar = self.sizeScalarAlt if alt_scalar else self.sizeScalar
        if isinstance(scalar, int):
            sz = CACHE_BYTES_INIT * scalar
        else:
            raise Exception(f"invalid get_cache_size 'sizeScalar' parameter {self.sizeScalar}")
        if self.tiny:
            sz = sz // self.tinyDiv
            sz = sz - sz % 2
        while not isprime(sz / HASH_BYTES):
            sz -= 2 * HASH_BYTES
        return sz

    # size_scalar=<target_size> [in *Gibibytes*]
    def get_full_size(self, alt_scalar=False):
        scalar = self.sizeScalarAlt if alt_scalar else self.sizeScalar
        if isinstance(scalar, int):
            sz = DATASET_BYTES_INIT * scalar
        else:
            raise Exception(f"invalid get_full_size 'sizeScalar' or 'sizeScalarAlt parameter {scalar}")
        if self.tiny:
            sz = sz // self.tinyDiv
        while not isprime(sz / MIX_BYTES):
            sz -= 2 * MIX_BYTES
        return sz

# ----- Manual Cache Generation -----------------------------------------------
    def mkcache(self, seed):
        n = self.get_cache_size() // HASH_BYTES
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
    def calc_dataset_chunk(self, i_start, chunk_len=1):
        n = len(self.cache)
        r = HASH_BYTES // WORD_BYTES
        i_start = int(i_start)
        o = np.empty([chunk_len, 16], dtype=np.uint32)
        # initialize the mix
        for i in range(chunk_len):
            mix = copy.copy(self.cache[(i+i_start) % n])
            mix[0] ^= i+i_start
            mix = blake3_512(int_list_to_bytes(mix))
            # fnv it with a lot of random cache nodes based on i
            for j in range(DATASET_PARENTS):
                cache_index = fnv((i+i_start) ^ j, mix[j % r])
                mix = list(map(fnv, mix, self.cache[cache_index % n]))
            o[i] = blake3_512(int_list_to_bytes(mix))
        return o

    def calc_dataset_item(self, i):
        n = len(self.cache)
        r = HASH_BYTES // WORD_BYTES
        i = int(i)
        # initialize the mix
        mix = copy.copy(self.cache[i % n])
        mix[0] ^= i
        mix = blake3_512(int_list_to_bytes(mix))
        # fnv it with a lot of random cache nodes based on i
        for j in range(DATASET_PARENTS):
            cache_index = fnv(i ^ j, mix[j % r])
            mix = list(map(fnv, mix, self.cache[cache_index % n]))
        return blake3_512(int_list_to_bytes(mix))

    def calc_dataset(self):
        # generate the dataset
        t_start = time.perf_counter()
        # dataset = []
        t_elapsed = percent_done = 0
        total_size = self.dagSize // HASH_BYTES
        dataset = np.empty([total_size, HASH_BYTES // WORD_BYTES], np.uint32)
        print("percent done:       ", end="")
        for i in range(total_size):
            # dataset.append(calc_dataset_item(cache, i))
            dataset[i] = self.calc_dataset_item(i)
            if (i / total_size) > percent_done + 0.0001:
                percent_done = i / total_size
                t_elapsed = time.perf_counter() - t_start
                print(f"\r{(percent_done * 100):5.2f}%, "
                      f"ETA: {(((1 - percent_done) / percent_done) * t_elapsed / 60 ):7.0f}m", end="")
        print(f"elapsed time: {t_elapsed/60} minutes")

        return dataset

    # flexible cache/dagger building method. Searches for saved structures, saves incrementally.
    def build_hash_struct(self, out_type, alt_seed=None, alt_size=None,
                          chunk_len=1024, pickle_period=10, partial_test=False):
        # find directory and build file name
        if out_type == 'cache':
            out_size = alt_size if isinstance(alt_size, int) else self.cacheSize
            seed = alt_seed if isinstance(alt_seed, (int, list, np.ndarray)) else self.seeds['front_seed']
            name_temp = int_list_to_bytes(seed)
        elif out_type == 'dag':
            out_size = alt_size if isinstance(alt_size, int) else self.dagSize
            seed = alt_seed if isinstance(alt_seed, np.ndarray) else self.cache
            name_temp = int_list_to_bytes(seed[0])
        else:
            raise Exception(f"out_type of 'cache' or 'dag' expected, {out_type} given")
        short_name = blake3(name_temp).hexdigest(length=16)
        row_length = out_size // HASH_BYTES
        name_root = out_type + '_L_' + str(row_length) + "_C_" + short_name
        name = name_root + '.npy'

        cwd = os.path.dirname(__file__)
        file_dir = os.path.join(cwd, f"jng_{out_type}_dir")
        filepath = os.path.join(file_dir, name)
        # check for a saved hash structure
        if os.path.exists(filepath):
            print(f"loading {out_type} for length: ", row_length, " and short_name: ", short_name)
            with open(filepath, 'rb') as file:
                hash_struct = np.load(filepath)
                file.close()
                return hash_struct
        else:
            print(f"  no saved {out_type} found!")
        print(f"generating hash structure... this will take a while... ")
        # since no saved structure exists, build from scratch
        if out_type == 'cache':
            hash_struct = self.mkcache(seed)
        elif out_type == 'dag':
            partial_name = name_root + '_partial.npy'
            partial_ind_name = name_root + '_partial_i.pkl'
            partial_fp_n = os.path.join(file_dir, partial_name)
            partial_fp_i = os.path.join(file_dir, partial_ind_name)
            if os.path.exists(partial_fp_n) and os.path.exists(partial_fp_i):  # search for partial dataset
                with open(partial_fp_n, 'rb') as hs:
                    hash_struct = np.load(partial_fp_n)  # load dataset to hash_struct
                    hs.close()
                with open(partial_fp_i, 'rb') as ind:
                    i_start = pickle.load(ind)  # check current index of partial dataset
                    ind.close()
                print(f"loaded partial {out_type} at index {i_start}")
            else:
                hash_struct = np.empty([row_length, HASH_BYTES // WORD_BYTES], np.uint32)
                i_start = 0

            pickle_count = 0
            with Parallel(n_jobs=self.cores) as parallel:  # multiprocessing
                t_start = time.perf_counter()
                for i in range(i_start, row_length, self.cores*chunk_len):
                    temp = np.asarray(parallel(delayed(self.calc_dataset_chunk)(j, chunk_len)
                                               for j in range(i, i+self.cores*chunk_len, chunk_len)))
                    for j in range(len(temp)):
                        for k in range(len(temp[j])):
                            if i + (j * chunk_len) + k < row_length:  # to keep from writing out of bounds
                                hash_struct[i + (j * chunk_len) + k] = temp[j, k]
                    percent_done = (i + chunk_len) / row_length
                    if partial_test and percent_done > 0.3:
                        print(f"\nreturning at index {i} from build_hash_struct for partial_test routine")
                        return 0
                    t_elapsed = time.perf_counter() - t_start
                    print(f"\r{(percent_done * 100):5.2f}%, "
                          f"ETA: {(((1 - percent_done) / percent_done) * t_elapsed / 60 ):7.0f}m", end="")

                    if i > pickle_count + pickle_period * chunk_len * self.cores:
                        pickle_count = i
                        if not os.path.exists(file_dir):
                            os.mkdir(file_dir)
                        with open(partial_fp_n, 'wb') as hs:
                            np.save(partial_fp_n, hash_struct)
                            hs.close()
                        with open(partial_fp_i, 'wb') as ind:
                            pickle.dump(i, ind)
                            ind.close()

            print(f"\nelapsed time: {(time.perf_counter() - t_start) / 60:.1f} minutes")
        else:
            raise Exception(f"out_type of 'cache' or 'dag' expected, '{out_type}' given")
        # save newly-generated hash structure
        if not os.path.exists(file_dir):
            os.mkdir(file_dir)
        with open(filepath, 'wb') as file:
            print(f"saving {out_type} for length: ", row_length, " and short_name: ", short_name)
            np.save(filepath, hash_struct)
            file.close()
        return hash_struct


# ----- Global Functions ------------------------------------------------------


# ----- Hashimoto -------------------------------------------------------------
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


# note: hashimoto_light is defined in the Verifier class
def hashimoto_full(full_size, dataset, header, nonce):
    return hashimoto(header, nonce, full_size, lambda x: dataset[x])


# ----- Defining the Seed Hash ------------------------------------------------
def get_seedset(block_height):
    back_temp = block_height - int(block_height % EPOCH_LENGTH)
    seeds = {
        'back_number': back_temp,
        'front_number': max(back_temp - EPOCH_LENGTH, 0)
    }
    seeds.update({
        'back_hash': get_seedhash(seeds['back_number']),
        'front_hash': get_seedhash(seeds['front_number'])
    })
    seeds.update({
        'back_seed': deserialize_hash(seeds['back_hash']),
        'front_seed': deserialize_hash(seeds['front_hash'])
    })
    return seeds


# Jengascoin alt_genesis: 'Satoshi is a steely-eyed missile man'
def get_seedhash(block_height, alt_genesis=JENESIS):
    if alt_genesis is None:
        s = '\x00' * 32
    else:
        s = bytes(alt_genesis, 'utf-8')
    for i in range(block_height // EPOCH_LENGTH):
        s = serialize_hash(blake3_256(s))
    return s


def get_target(difficulty, max_target=int(MAX_CHAIN_TARGET)):
    # byte strings are little-endian, have to reverse for target comparison
    if isinstance(max_target, int):
        # Jengascoin currently uses subtractive difficulty (not division-scaled)
        return encode_int(max(max_target - difficulty, 1)).ljust(32, '\0')[::-1]
    else:
        raise Exception(f"invalid get_target 'max_target' parameter {max_target}")


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


# ----- Fowler–Noll–Vo hash function ------------------------------------------
# used for data aggregation, non-cryptographic
FNV_PRIME = 0x01000193
def fnv(v1, v2):
    return ((v1 * FNV_PRIME) ^ v2) % 2 ** 32


# ----- Blake3 Hash Function  -------------------------------------------------
# outputs 32 bytes unless otherwise specified
def blake3_512(x):
    h = hash_words(lambda v: blake3(v).digest(length=64), 64, x)
    return h


def blake3_256(x):
    h = hash_words(lambda v: blake3(v).digest(), 32, x)
    return h
