# Unit Tests for jh.py 

from jh import *
import sys
import sha3  # because blake3 won't work on arrays

node = sys.argv[1] if len(sys.argv) >= 2 else 'peer1.jengas.io'
cores = int(sys.argv[2]) if len(sys.argv) >= 3 else 2

print("********** Running Jenghash Unit Tests **********\n\n")


# Peer communication tests, defaults to peer1
print("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n")
print("~~~~~~~~~~     Peer Communication      ~~~~~~~~~~\n")
print("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n")
link_test = Link(node)
print("Get Peer Block test:")
result = link_test.get_node_block(100)
print(f"status: {result['status']}\nblakehash: {result['data']['blakehash']}\n")
assert result['status'] == 'ok'

print("Get Mining Info test:")
result = link_test.get_miner_input()
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
result = link_test.submit_solution(submission_dictionary)
print(f"status: {result['status']}\nnonce accepted?: {result['data']}\n\n")
assert result['data'] == 'rejected'
print("Peer Communication tests passed!")


# Cache and Dataset Generation tests, very small dataset
print("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n")
print("~~~~~~ Seed, Cache, and Dataset Generation ~~~~~~\n")
print("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n")

# Find seeds, check for match
gen_seed1 = deserialize_hash(get_seedhash(0))
gen_seeds = get_seedset(0)
print("Genesis Seedset: \n", gen_seeds)
gen_seed2 = gen_seeds['front_seed']
assert gen_seed1 == gen_seed2
random_block = randint(EPOCH_LENGTH+1, 10000*EPOCH_LENGTH)
seed1 = deserialize_hash(get_seedhash(random_block))
seeds = get_seedset(random_block)
seed2 = seeds['back_seed']
print(f"Seedset {random_block}: \n", seeds)
assert seed1 == seed2
assert isinstance(seed2, list)
assert isinstance(seed2[0], int)
print("Seed match tests passed!")

# initialize the rest of the classes separately
smith = Smith(seeds, cores=cores, tiny=True)
miner = Miner(1, 'pubkey', node_url=node, tiny=True)
verifier = Verifier(4, node_url=node, tiny=True)

# build and load caches, check for match
print("making smith.cache")
smith.cache = smith.mkcache(seed1)
print("making cache2")
cache2 = smith.build_hash_struct('cache', seed2)
assert np.array_equal(cache2, smith.cache), "smith.cache is not equal to cache2"
print("loading cache2 saved file to cache3")
cache3 = smith.build_hash_struct('cache', seed1)
assert np.array_equal(cache3, smith.cache), "smith.cache is not equal to cache3"
print("Cache build/load tests passed!")

# smith and load daggers, check for match
t_start = time.perf_counter()
print(f"calculating dagger1 with {cores} cores, with partial save/load test")
smith.build_hash_struct('dag', alt_seed=cache2, pickle_period=1, partial_test=True)
dagger1 = smith.build_hash_struct('dag', alt_seed=cache2)
t_mid = time.perf_counter()
print("calculating smith.dagger with 1 core")
smith.dagger = smith.calc_dataset()
t_stop = time.perf_counter()
assert np.array_equal(dagger1, smith.dagger), "smith.dagger is not equal to dagger1"
print(f"    improvement of {(t_stop-t_mid) / (t_mid-t_start) :.2f}x was achieved with {cores}x cores")
print("loading dagger2 saved file to dagger3")
dagger3 = smith.build_hash_struct('dag', alt_seed=cache3)
assert np.array_equal(dagger3, smith.dagger), "smith.dagger is not equal to dagger3"
print("Seed, Cache, and Dagger-smithing tests passed!")


# Hashimoto tests on daggers
print("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n")
print("~~~~~~~ Miner and Verifier Hashimoto Tests ~~~~~~\n")
print("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n")

for i in range(100):
    nonce = miner.random_nonce()
    print(f"\rloop {i+1}/100, nonce: {nonce}")
    hash1 = hashimoto_full(smith.dagSize, dagger1, miner.chainState['header'], nonce)
    hash2 = hashimoto_full(smith.dagSize, smith.dagger, miner.chainState['header'], nonce)
    hash3 = hashimoto_full(smith.dagSize, dagger3, miner.chainState['header'], nonce)
    assert all([a == b == c for a, b, c in zip(hash1, hash2, hash3)]), "hashes not equal"
    res = verifier.verify(hash1['mix digest'], hash2['result'], nonce,
                          verifier.chainState['header'], miner.specs['sizeScalar'])
    light_hash = verifier.hashimoto_light(smith.dagSize, cache2, miner.chainState['header'], nonce)
    assert all([a == b for a, b in zip(hash1, light_hash)])

print("All Miner and Verifier Hashimoto tests passed!")

print("All tests passed!")
