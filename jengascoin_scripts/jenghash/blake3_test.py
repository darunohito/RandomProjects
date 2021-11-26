import unittest
from blake3 import blake3
import codecs

class Blake3Test(unittest.TestCase):
    def test_something(self):
        o = blake3(bytes(0)).hexdigest(length=32)
        # o = codecs.decode(blake3(bytes(0)).digest(length=32), 'base64')
        print("o type: ", type(o), ",\nlength: ", len(o), "\nval: ", o)
        print("max char val: ", max(o))
        self.assertEqual(True, False)  # add assertion here



if __name__ == '__main__':
    unittest.main()
