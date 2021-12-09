# Unit Tests for jh.py 

from jh import *
import sys

if len(sys.argv) >=2:
    peer = sys.argv[1]
else:
    peer = 'peer1.jengas.io'

print("********** Running Jenghash Unit Tests **********\n\n")


# Peer communication tests, defaults to peer1


print("~~~~~~~~~~     Peer Communication      ~~~~~~~~~~\n")
print("Get Peer Block test:")
result = get_peer_block(peer, 100)
print(f"status: {result['status']}\nblakehash: {result['data']['blakehash']}\n")
assert result['status'] == 'ok'

print("Get Mining Info test:")
result = get_miner_input(peer)
print(f"header: {result['header']}\ndiff: {result['diff']}\n")
assert isinstance(result['diff_int'], int)

print("Submit Nonce test:")  # TESTNET ONLY
submission_dictionary = {
    'nonce': 'asdf1234',  # base58 encoded nonce
    'cmix': 'abcde12345',
    'blakehash': 'abcde12345',
    'public_key': 'pubkey',
    'private_key': 'privkey'
}
result = submit_solution(peer, submission_dictionary)
print(f"status: {result['status']}\nnonce accepted?: {result['data']}\n\n")
assert result['data'] == 'rejected'
print("Peer Communication tests passed!")



# Cache and Dataset Generation tests, very small dataset
print("~~~~~~~~~~ Cache and Dataset Generation ~~~~~~~~~~\n")

seed1 = get_seedhash(0)
seeds = get_seedset(0)
seed2 = seeds['front_hash']
print("Seedset 0: \n", seeds)
assert seed1 == seed2

smth = Smith()
cache1 = smth.mkcache(get_cache_size(1, tiny=True), seed1)
cache2 = smth.build_hash_struct(get_cache_size(1, tiny=True), seed1)
c1b = blake3(cache1).digest()
c2b = blake3(cache2).digest()
print("cache1 blakehash: ", c1b)
print("cache2 blakehash: ", c2b)
assert c1b == c2b






print("All tests passed!")

