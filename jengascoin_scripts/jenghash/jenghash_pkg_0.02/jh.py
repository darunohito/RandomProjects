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
import base58
import requests
from urllib.parse import urljoin
from jh_definitions import *
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
MAX_CHAIN_TARGET = 0x00000000FFFF0000000000000000000000000000000000000000000000000000

URL_PATH = {
    'MINE_SOLO':        '/api.php?q=getMiningInfo',
    'SUBMIT_SOLO':      '/api.php?q=submitNonce',
    'GET_BLOCK':       '/api.php?q=getBlock'  # =integer
}


# ----- Main function ---------------------------------------------------------


if __name__ == "__main__":
    import sys

    # example call:
    # python3 jh.py http://peer1.jengas.io/ <public-key> <private-key>
    if len(sys.argv) < 4 or len(sys.argv) > 6:
        print(sys.stderr, "usage: python3", sys.argv[0], "<peer-URL>", "<public-key>", "<private-key>", "(opt)cores", "(opt)freeze")
        sys.exit(1)
    peer = sys.argv[1]

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


    # must be initialized with either local chainState dictionary or peer_url
    def __init__(self, size_max, cores, chainState=None, peerUrl=None):
        self.size_max = size_max
        # init ultralight verifier lnk (link only useful for dev)
        if isinstance(peerUrl, str):  # if ultralight verifier
            self.lnk = Link(peerUrl)  # check status of peer chain
            self.input = lnk.chainState  # copy to local mining info
            print("Initial Peer Chain State: \n", self.input)
        self.target = get_target(self.input['diff_int'])
        # init verifier smth
        self.smth = Smith(lnk, size_max, pubKey, cores)
        self.seeds = get_seedset(input['height'])
        # build cache for current epoch
        smth.cache = smth.build_hash_struct(smth.cacheSize, deserialize_hash(seeds['back_hash']))
    
    
    # ultralight verifier lnk update (link only useful for dev)
    def peer_update():
        self.input = lnk.get_miner_input()
    
    
    def verify(cmix, s_cmix_hash, nonce, size_coeff, header, diff):
        if header != self.input['header']:
            return False  # DDoS protection layer 1
            self.target = get_target(diff)
        elif cmix > self.target:
            return False  # layer 2
        res = serialize_hash(blake3_256(blake3_512(str_to_bytes(self.input['header']) + struct.pack("<Q", nonce)) + cmix))
        if res != s_cmix_hash:
            return False  # layer 3
        elif hashimoto_light(smth.get_full_size(size_coeff), self.cache, self.header, nonce)['mix digest'] < self.target:
            return True  # actual nonce check
        else:
            return False
        

class Miner:  # high-level class

    def __init__(self, peerUrl, pubKey, priKey, size_coeff, cores):
        # init static vars
        self.pubKey = pubKey
        self.priKey = priKey
        self.size_coeff = size_coeff
        # init miner lnk
        self.lnk = Link(peerUrl)
        self.input = lnk.chainState
        self.target = get_target(self.input['diff'], int(MAX_CHAIN_TARGET))
        # init miner smth
        self.smth = Smith(lnk, size_coeff, pubKey, cores)
        self.seeds = get_seedset(input['height'])
        # build cache and dagger for current epoch
        smth.cache = smth.build_hash_struct(smth.cacheSize, deserialize_hash(seeds['back_hash']))
        smth.dagger = smth.build_hash_struct(smth.dagSize, smth.cache, 'dag', cores)


    def random_nonce():
        return randint(0, 2 ** 64)


    def mine(full_size, dataset, header, difficulty, nonce):
        target = get_target(difficulty)
        while hashimoto_full(full_size, dataset, header, nonce).get("mix digest") > target:
            nonce = (nonce + 1) % 2 ** 64
        return nonce
            

class Smith:  # low-level class

    def __init__(self, lnk, size_coeff, pubkey, cores):
        self.lnk = lnk
        self.cacheSize = size_coeff * CACHE_BYTES_INIT
        self.dagSize = size_coeff * DATASET_BYTES_INIT
        self.pubKey = pubKey
        self.cores = cores
        
        self.cache = None
        self.dagger = None

    # for jengascoin use, set size_coeff=<dataset_size> [in integer *Gibibytes*]
    def get_cache_size(size_coeff=1, tiny=False):    
        if isinstance(size_coeff, int):
            sz = CACHE_BYTES_INIT * size_coeff
        else:
            raise Exception(f"invalid cache 'size_coeff' parameter {size_coeff}")
        if tiny:
            sz = sz // 100
        while not isprime(sz / HASH_BYTES):
            sz -= 2 * HASH_BYTES
        return sz
        
        
    # size_coeff=<target_size> [in *Gibibytes*]
    def get_full_size(size_coeff=1, tiny=False):
        if isinstance(size_coeff, int):
            sz = DATASET_BYTES_INIT * size_coeff
        else:
            raise Exception(f"invalid cache 'size_coeff' parameter {size_coeff}")
        if tiny:
            sz = sz // 100
        while not isprime(sz / MIX_BYTES):
            sz -= 2 * MIX_BYTES
        return sz
    
    
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
    
        
    def build_hash_struct(out_size, seed, out_type='cache', core_count=1, coin='jng'):
        # find directory and build file name
        if out_type == 'cache':
            name_temp = int_list_to_bytes(seed)
        elif out_type == 'dag':
            name_temp = int_list_to_bytes(seed[0])
        else:
            raise Exception(f"out_type of 'cache' or 'dag' expected, {out_type} given")
        short_name = blake3(name_temp).hexdigest(length=16)
        row_length = out_size // HASH_BYTES
        name = out_type + '_L_' + str(row_length) + "_C_" + short_name + '.npy'
        cwd = os.path.dirname(__file__)
        file_dir = os.path.join(cwd, f"{coin}_{out_type}_dir")
        filepath = os.path.join(file_dir, name)
        fp = glob.glob(f"{filepath}_partial.npy")[-1]
        # check for a saved hash structure
        if os.path.exists(filepath):
            print(f"loading {out_type} for length: ", row_length, " and short_name: ", short_name)
            with open(filepath, 'rb') as file:
                return np.load(filepath)
        elif os.path.exists(fp[-1]):
            with open(fp[-1], 'rb') as hs:
                hash_struct = np.load(fp[-1])
                hs.close()
            with open(f"{filepath}_partial_i.pkl", 'rb') as ind:
                i_load = pickle.load(ind)
            print(f"loaded partial {out_type} at {i_load/row_length*100:.1f}% completion")
            
        else:
            print("  no saved {out_type} found!")
        print(f"generating hash structure... this will take a while... ", end="")

        # since no saved structure exists, build from scratch
        if out_type == 'cache':
            hash_struct = mkcache(cache_size=out_size, seed=seed)
        elif out_type == 'dag':
            hash_struct = np.empty([row_length, HASH_BYTES // WORD_BYTES], np.uint32)
            chunk_len = 1024
            pickle_period = 10  # loops through "i" between partial backups
            pickle_count = 0
            with Parallel(n_jobs=core_count) as parallel:  # multiprocessing
                t_start = time.perf_counter()
                for i in range(0, row_length, core_count*chunk_len):
                    temp = np.asarray(parallel(delayed(calc_dataset_chunk)(seed, j, chunk_len)
                                               for j in range(i, i+core_count*chunk_len, chunk_len)))
                    for j in range(len(temp)):
                        for k in range(len(temp[j])):
                            if i + (j * chunk_len) + k < row_length:  # to keep from writing out of bounds
                                hash_struct[i + (j * chunk_len) + k] = temp[j, k]
                    percent_done = (i + chunk_len) / row_length
                    t_elapsed = time.perf_counter() - t_start
                    print(f"\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b{(percent_done * 100):5.2f}%, "
                          f"ETA: {(t_elapsed / percent_done / 60):7.0f}m", end="")

                    if i > pickle_count * chunk_len * core_count:
                        if not os.path.exists(file_dir):
                            os.mkdir(file_dir)
                        with open(f"{filepath}_partial.npy", 'wb') as hs:
                            np.save(filepath, hash_struct)
                            hs.close()
                        with open(f"{filepath}_partial_i.pkl", 'wb') as ind:
                            pickle.dump(i, ind)
                            ind.close()

            print(f"elapsed time: {(time.perf_counter() - t_start) / 60:.1f} minutes")
        else:
            raise Exception(f"out_type of 'cache' or 'dag' expected, '{out_type}' given")
        # save newly-generated hash structure
        if not os.path.exists(file_dir):
            os.mkdir(file_dir)
        with open(filepath, 'wb') as file:
            print(f"\nsaving {out_type} for length: ", row_length, " and short_name: ", short_name)
            np.save(filepath, hash_struct)
            file.close()
        return hash_struct
        

class Link:  # low-level class
    
    def __init__(self, link_url, link_hdr):
        self.url = link_url
        self.hdr = link_hdr
        self.chainState = self.get_miner_input(self.url)
    
    
    def get_miner_input(self):
        info = self.peer_request(url, URL_PATH['MINE_SOLO'])
        miner_input = info['data']
        if hdr is None:
            miner_input['old_hdr'] = False
        else:
            miner_input['old_hdr'] = hdr
        return parse_mining_input(miner_input)
        
        
    def parse_mining_input(miner_input):
        miner_input_parsed = {
            'diff': hex(int(miner_input['difficulty'])),
            'diff_int': int(miner_input['difficulty']),
            'header': '0x' + base58.b58decode(miner_input['block']).hex(),  # "block" is actually hash of last block
            'header_b58': miner_input['block'],
            'block': miner_input['height'],  # "height" is actually "block" number, for ethash
        }
        if miner_input['old_hdr'] != miner_input_parsed['header']:
            miner_input_parsed['new'] = True
        else:
            miner_input_parsed['new'] = False
        # print("miner_input_parsed: ", miner_input_parsed)
        return miner_input_parsed


    def get_peer_block(block_height, peer_url=self.url):
        # height_param = f"&height={block_height}"
        height_param = {'height': block_height}
        return peer_request(peer_url, URL_PATH['GET_BLOCK'], params_dict=height_param)


    # ----- TESTNET ONLY ----- #
    def submit_solution(submission_dict, peer_url=self.url):
        return peer_request(peer_url, URL_PATH['SUBMIT_SOLO'], method='post', params_dict=submission_dict)
    # ----- TESTNET ONLY ----- #


    # params_dict example: {'nonce': 1234, 'public_address': 'J2034'}
    # peer_request function only supports GET and POST methods
    def peer_request(command_string, method='get', peer_url=self.url, params_dict=None):
        if method == 'get':
            if isinstance(params_dict, dict):
                for k, v in params_dict.items():
                    # format:  "&public_key=key"
                    command_string += f"&{str(k)}={str(v)}"
            print(urljoin(peer_url, command_string))
            r = requests.get(urljoin(peer_url, command_string))
        elif method == 'post':
            print(urljoin(peer_url, command_string))
            r = requests.post(urljoin(peer_url, command_string), data=params_dict)
        json_out = r.json()
        if json_out['status'] == 'error':
            print(json_out['data'])
            # sys.exit(1)
        return json_out
        
        
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


def hashimoto_light(full_size, cache, header, nonce):
    return hashimoto(header, nonce, full_size,
                     lambda x: calc_dataset_item(cache, x))


def hashimoto_full(full_size, dataset, header, nonce):
    return hashimoto(header, nonce, full_size, lambda x: dataset[x])




# ----- Defining the Seed Hash ------------------------------------------------
def get_seedset(block_height):
    back_temp = block_height - int(block_height % EPOCH_LENGTH)
    seeds = {
        'back_number': back_temp,  # next seed
        'front_number': max(back_temp - EPOCH_LENGTH, 0)  # current seed
    }
    seeds.update({
        'back_hash': get_seedhash(seeds['back_number']),  # next hash
        'front_hash': get_seedhash(seeds['front_number'])  # current hash
    })
    return seeds  # for building cache and dagger datasets
    

# jengascoin alt_genesis: 'Satoshi is a steely-eyed missile man'
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
            raise Exception(f"invalid cache 'size' parameter {size}")


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
