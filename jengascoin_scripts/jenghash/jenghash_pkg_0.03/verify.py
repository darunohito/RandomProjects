from jh import *


# res, info = verifier.verify(hash1['mix digest'], hash2['result'], nonce,
            # verifier.chainState['header'], miner.specs['sizeScalar'])
                                
# verifier = Verifier(1, node_url=node, alt_seedblock=random_block, tiny=True)

if len(sys.argv) != 8:
    Exception("usage: verify.py <difficulty_int_str> <blockheader> <height_int> "
              "<mix_digest_b> <result_b> <nonce_int> <header_from_miner>")

chainState_In = {
    "difficulty": sys.argv[1],
    "block": sys.argv[2],  # technically "block header"
    "height": int(sys.argv[3])
}

link = Link(local=True)
link.parse_mining_input(chainState_In)
verifier = Verifier(1, chain_state=link.chainState, tiny=True)


mix_digest = sys.argv[4]
result = sys.argv[5]
nonce = int(sys.argv[6])
header = sys.argv[7]

res, info = verifier.verify(mix_digest, result, nonce, header)
print(f"res: {res}, info: {info}\n")

if res:
    exit(0)
else:
    exit(1)

