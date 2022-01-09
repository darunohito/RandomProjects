from jh import *
import sys
import codecs


# res, info = verifier.verify(hash1['mix digest'], hash2['result'], nonce,
            # verifier.chainState['header'], miner.specs['sizeScalar'])
                                
# verifier = Verifier(1, node_url=node, alt_seedblock=random_block, tiny=True)

if len(sys.argv) != 8:
    Exception("usage: verify.py <difficulty_int_str> <blockheader_b58> <height_int> "
              "<mix_digest_hex> <result_hex> <nonce_int> <header_from_miner>")

chainState_In = {
    "difficulty": sys.argv[1],
    "block": sys.argv[2],  # technically "block header"
    "height": int(sys.argv[3])
}

link = Link(local=True)
link.parse_mining_input(chainState_In)
verifier = Verifier(1, chain_state=link.chainState, tiny=True)

print(f"mix_digest input: {sys.argv[4]}")
mix_digest = sys.argv[4]
mix_digest = encode_int(int(mix_digest, base=16))
mix_digest = '\x00' * (32 - len(mix_digest)) + mix_digest
# mix_digest = struct.pack('hex', sys.argv[4])
# mix_digest = '0x'
print(f"mix_digest type: {type(mix_digest)}")
result = sys.argv[5]
result = encode_int(int(result, base=16))
result = '\x00' * (32 - len(result)) + result
nonce = int(sys.argv[6])
header_hex = '0x' + base58.b58decode(sys.argv[7]).hex()

hdr = encode_int(int(header_hex, base=16))
header = '\x00' * (32 - len(hdr)) + hdr

res, info = verifier.verify(mix_digest, result, nonce, header)
print(f"res: {res}, info: {info}\n")

if res:
    exit(0)
else:
    exit(1)

