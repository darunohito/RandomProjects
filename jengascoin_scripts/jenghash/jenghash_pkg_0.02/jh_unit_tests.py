# Unit Tests for jh.py 

from jh import *
import sys

node = sys.argv[1] if len(sys.argv) >= 2 else 'peer1.jengas.io'
cores = sys.argv[2] if len(sys.argv) >= 3 else 2

print("********** Running Jenghash Unit Tests **********\n\n")


# Peer communication tests, defaults to peer1

print("~~~~~~~~~~     Peer Communication      ~~~~~~~~~~\n")
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
print("~~~~~~~ Seed, Cache, and Dataset Generation ~~~~~~~\n")

# Find seeds, check for match
seed1 = deserialize_hash(get_seedhash(0))
seeds = get_seedset(0)
print("Seedset 0: \n", seeds)
seed2 = seeds['front_seed']
assert seed1 == seed2
random_block = randint(EPOCH_LENGTH+1, 10000*EPOCH_LENGTH)
seed1 = deserialize_hash(get_seedhash(random_block))
seeds = get_seedset(random_block)
seed2 = seeds['back_seed']
print(f"Seedset {random_block}: \n", seeds)
assert seed1 == seed2
assert isinstance(seed2, list)
assert isinstance(seed2[0], int)
print("Seed match tests passed!")

smith = Smith(seeds, cores=cores, tiny=True)
# build and load caches, check for match
print("making smith.cache")
smith.cache = smith.mkcache(seed1)
print("making cache2")
cache2 = smith.build_hash_struct('cache', seed2)
assert smith.cache.all() == cache2.all(), "smith.cache is not equal to cache2"
print("loading cache2 saved file to cache3")
cache3 = smith.build_hash_struct('cache', seed1)
assert smith.cache.all() == cache3.all(), "smith.cache is not equal to cache3"
print("Cache build/load tests passed!")

# build and load daggers, check for match
print("calculating smith.dagger")
smith.dagger = smith.calc_dataset()
print("calculating dagger2")
dagger2 = smith.build_hash_struct('dag', cache3)
assert smith.dagger.all() == dagger2.all(), "smith.dagger is not equal to dagger2"
print("loading dagger2 saved file to dagger3")
dagger3 = smith.build_hash_struct('dag', cache2)
assert smith.dagger.all() == dagger3.all(), "smith.dagger is not equal to dagger3"

# if not os.path.exists(file_dir):
#     os.mkdir(file_dir)
# with open(f"{filepath}_partial.npy", 'wb') as hs:
#     np.save(filepath, hash_struct)
#     hs.close()

# hasher = hashlib.md5()
# with open('myfile.jpg', 'rb') as afile:
#     buf = afile.read()
#     hasher.update(buf)
# print(hasher.hexdigest())


print("All tests passed!")

