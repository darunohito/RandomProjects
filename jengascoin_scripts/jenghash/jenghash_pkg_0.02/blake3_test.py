import unittest
import time
import base64
import jh
from random import randint
from blake3 import blake3

NUM_RUNS = 100000  # hashes
INPUT_LENGTH = 64  # bytes
OUTPUT_LENGTH = 64  # bytes
NULL_TEST_64 = b'rxNJufX5oaagQE3qNtzJSZvLJcmtwRK3zJqTyuQfMmLgDwPntprya3+q8J/NMzBQM43f4IW4zIacqYsgbAgkOg=='
FOO_TEST_64 = b'BOC7OfMLGj/rifU2yTvhUFVILfdIZ0sA0m5adXd3Aul5EHS3URtZ0xxxxi9adFaJ+myUl/aL3xBh/gf1GNQQwA=='

class Blake3Test(unittest.TestCase):
    def test_something(self):

        input_bytes = b''
        test_out = jh.int_list_to_bytes(jh.blake3_512(input_bytes))
        print("null input,        blake3 hash: ", test_out.hex())
        print("                    [base64]: ", base64.b64encode(test_out))
        self.assertEqual(base64.b64encode(test_out), NULL_TEST_64)

        input_bytes = bytes('foo', 'utf-8')
        test_out = jh.int_list_to_bytes(jh.blake3_512(input_bytes))
        print("'foo' utf-8 input, blake3 hash: ", test_out.hex())
        print("                    [base64]: ", base64.b64encode(test_out))
        self.assertEqual(base64.b64encode(test_out), FOO_TEST_64)

        byte_array = []
        o = []
        for _ in range(NUM_RUNS):
            o.append(0)
            int_list = []
            for _ in range(INPUT_LENGTH // 4):
                int_list.append(randint(0, 4294967295))
            byte_array.append(jh.int_list_to_bytes(int_list))
        print(NUM_RUNS, " runs, ", INPUT_LENGTH, " input bytes, ", OUTPUT_LENGTH, " output bytes...now running")

        t_start = time.perf_counter()
        for i in range(NUM_RUNS):
            o[i] = blake3(byte_array[i]).hexdigest(length=OUTPUT_LENGTH)
        t_stop = time.perf_counter()
        t_elapsed = t_stop - t_start

        hashrate = NUM_RUNS / t_elapsed
        print("Completed in ", t_elapsed, "s, Hashrate: ", hashrate)


if __name__ == '__main__':
    unittest.main()
