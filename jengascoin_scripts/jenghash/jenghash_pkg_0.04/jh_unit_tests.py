# Unit Tests for jh.py 

from jh import *
import sys

node = sys.argv[1] if len(sys.argv) >= 2 else 'peer1.jengas.io'
cores = int(sys.argv[2]) if len(sys.argv) >= 3 else 2
mode = sys.argv[3] if len(sys.argv) >= 4 else 'full'  # also accepts <quick>/<q> and <instant>/<i> mode
if mode != 'full' and mode != 'f' and mode != 'quick' and mode != 'q' and mode != 'instant' and mode != 'i':
    raise Exception("input for <mode> invalid. Default: 'full', accepts: 'f', 'quick', 'q', 'instant', or 'i'")
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
if mode == 'instant' or mode == 'i':
    random_block = EPOCH_LENGTH*2 + 1
else:
    random_block = randint(EPOCH_LENGTH+1, 10000*EPOCH_LENGTH)
seed1 = deserialize_hash(get_seedhash(random_block - EPOCH_LENGTH))
seeds = get_seedset(random_block)
seed2 = seeds['front_seed']
print(f"Seedset {random_block}: \n", seeds)
assert seed1 == seed2
assert isinstance(seed2, list)
assert isinstance(seed2[0], int)
print("Seed match tests passed!")

# initialize the rest of the classes separately
smith = Smith(seeds, cores=cores, key=b'pubkey', tiny=True)
miner = Miner(1, b'pubkey', node_url=node, alt_seedblock=random_block, tiny=True)
verifier = Verifier(1, node_url=node, alt_seedblock=random_block, tiny=True)

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
print(f"calculating dagger1 with {cores} cores, with partial save/load test")
t_start = time.perf_counter()
smith.build_hash_struct('dag', alt_seed=cache2, pickle_period=1, partial_test=True)
dagger1 = smith.build_hash_struct('dag', alt_seed=cache2)
t_mid1 = time.perf_counter()
print("loading dagger1 saved file to dagger2")
dagger2 = smith.build_hash_struct('dag', alt_seed=cache3)
assert np.array_equal(dagger1, dagger2), "dagger1 is not equal to dagger2"
if mode == 'full' or mode == 'f':
    print("calculating smith.dagger with 1 core")
    t_mid2 = time.perf_counter()
    smith.dagger = smith.calc_dataset()
    t_stop = time.perf_counter()
    assert np.array_equal(dagger1, smith.dagger), "smith.dagger is not equal to dagger1"
    print(f"    improvement of {(t_stop-t_mid2) / (t_mid1-t_start) :.2f}x was achieved with {cores}x cores")
else:
    print("skipping single-core dagger")

print("Seed, Cache, and Dagger-smithing tests passed!")


# Hashimoto tests on daggers
print("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n")
print("~~~~~~~ Miner and Verifier Hashimoto Tests ~~~~~~\n")
print("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n")

for i in range(32):
    nonce = miner.random_nonce()
    hash1 = hashimoto_full(smith.dagSize, dagger1, miner.chainState['header'], nonce)
    hash2 = hashimoto_full(smith.dagSize, dagger2, miner.chainState['header'], nonce)
    assert all([a == b for a, b in zip(hash1, hash2)]), "hashes not equal"
    res, info = verifier.verify(hash1['mix digest'], hash2['result'], nonce,
                                verifier.chainState['header'], miner.specs['sizeScalar'], miner.creds['pubKey'])
    light_hash = verifier.hashimoto_light(smith.dagSize, miner.chainState['header'], nonce, miner.creds['pubKey'])
    assert hash1['mix digest'] == light_hash['mix digest']
    assert hash1['result'] == light_hash['result']
    print(f"loop {i+1}/32, nonce: {nonce}, verified? {res}, reason? {info}"
          f"\n    full mix digest: {hash1['mix digest']}"
          f"\n   light mix digest: {light_hash['mix digest']}")

print("All Miner and Verifier Hashimoto tests passed!")

print("All tests passed!")
