import jh
from jh_definitions import *
import sys


if len(sys.argv) != 3:
    print(sys.stderr, "usage: ", sys.argv[0], "epoch[int]", "type:cache|dag|all[string]")
    sys.exit(1)

epoch = int(sys.argv[1])
block = epoch * EPOCH_LENGTH
type = sys.argv[2]

seed = jh.deserialize_hash(jh.get_seedhash(block))
print("seed", "%064x" % jh.decode_int(jh.serialize_hash(seed)[::-1]))

if type == 'cache' or type == 'all':
    print("     now acquiring cache...")
    jh.build_hash_struct(jh.get_cache_size(block), seed, out_type='cache', coin='jng')
elif type == 'dag' or type == 'all':
    print("     now acquiring dag...")
    cache = jh.build_hash_struct(jh.get_cache_size(block), seed, out_type='cache', coin='jng')
    jh.build_hash_struct(jh.get_full_size(block), cache, out_type='dag', coin='jng')
else:
    print("     now acquiring dag...")
    print(sys.stderr, "usage: ", sys.argv[0], "epoch[int]", "type:cache|dag|all[string]")
    sys.exit(1)
    
print("jh_generate for epoch:{epoch} and type:{type} is complete")
