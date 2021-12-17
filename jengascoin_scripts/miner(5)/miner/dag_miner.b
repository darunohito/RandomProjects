<?php
namespace Jengascoin\Miner;
require('blake3_optimized.php');
use BLAKE3;

ini_set("memory_limit", "8G");


$type = trim($argv[1]);
$size = intval(trim($argv[2]));
$node = trim($argv[3]);
$public_key = trim($argv[4]);
if(isset($argv[5]))
{
	$private_key = trim($argv[5]);
	
} else {
	$private_key = '';
}

//var_dump($argv);
new Miner($type, $size, $node, $public_key, $private_key);
// See https://github.com/ethereum/wiki/wiki/Dagger-Hashimoto#dagger-graph-building

// $SAFE_PRIME_512 = 2**512 - 38117;     # Largest Safe Prime less than 2**512
class Miner
{
	public const VERSION = '0.1';
    public const MODE_POOL = 'pool';
    public const MODE_SOLO = 'solo';
    public const NODE_STATUS_OK = 'ok';
	//public const P = 2**512 - 38117;              # Safe Prime for hashing and random number generation
	public const TwoExp64 = '18446744073709551616'; //to improve efficiency
	public const Mb = 983040 * 8; // NUM_BITS, megabyte, multiple of 65536
	//public const Gb = 999948288 * 8; // NUM_BITS, gigabyte, multiple of 65536
	//public const n = 4000055296 * 8; // NUM_BITS,  # Size of the dataset (4 Gigabytes); MUST BE MULTIPLE OF 65536
    //public const n_inc = 65536;      	# Increment in value of n per period; MUST BE MULTIPLE OF 65536 
	#with epochtime=20000 gives 882 MB growth per year
    private $cache_size;               	# Size of the light client's cache (can be chosen by light client; not part of the algo spec)
    private $diff;                    	# Difficulty (adjusted during block evaluation)
    private $epochtime;              	# Length of an epoch in blocks (how often the dataset is updated)
    private $k;                         # Number of parents of a node
    private $w;                         # Used for modular exponentiation hashing
    private $accesses;                 	# Number of dataset accesses during hashimoto
	private $prime; 					# Experimental prime value, not yet implemented
	
	//from old miner
	private $publicKey;
    private $privateKey;
    private $speed;
    private $avgSpeed;
    private $node;
    private $block;
    //private $difficulty; replace with $diff
    private $counter;
    private $allTime;
    private $beginTime;
    private $type;
    private $worker;
    private $lastUpdate;
    private $submit;
    private $confirm;
    private $found;
    private $height;
	private $epoch;
    private $testnet;
	  
	/**
     * miner constructor.
     *
     * @param $type
     * @param $node
     * @param $public_key
     * @param $private_key
     */
    public function __construct($type, $size, $node, $public_key, $private_key)
    {	
		$this->outputHeader();
		$this->checkDependencies();
		
		if (empty($type) || empty($size) || empty($public_key) || empty($node) || ($type == self::MODE_SOLO && empty($private_key))) {
            echo "Usage:

For Solo mining: ./eth_stuff solo <size_in_MB> <node> <public_key> <private_key>

For Pool mining: ./eth_stuff pool <size_in_MB> <pool-address> <your-address>\n\n";
            exit;
        }
		if ((log($size,2) % 1) != 0) {
			$size = 2^(floor(log($size,2)));
			echo "DAG size rounded down to nearest power of 2\n";
		}
			
		if ($type == self::MODE_POOL) {
            $private_key = $public_key;
        }
		
		$worker = uniqid();
		
		$this->prepare($public_key, $private_key, $node, $type, $worker, $size);
		
		$pt_r = file_get_contents("http://pool.jengas.io/pt.php");
		if($pt_r > 0)
		{
			//echo "PT_R $pt_r\n";
			$pt = $pt_r;
		}
		
		$this->update_block();
		$base = $this->publicKey."-".$this->block."-".$this->diff;
		$daglength = $this->size*(SELF::Mb);
		echo "bit length: " . $daglength . "\n";
		
		//build the DAG
		//$dagger = $this->produce_dag($base,$daglength);
		$dagger = $this->produce_dag($base,$daglength/1024);
		//$this->update_dag();
		
		//mine the DAG
		$nonce = $this->mine($dagger);
		echo "nonce found! :o\n";
		
		//check the nonce
		if($this->verify($dagger, $this->block, $nonce)) {
			echo "nonce good! :D\n";
		} else {
			echo "nonce bad >:(\n";
		}
		exit(0);
	}
	
	/**
     * @param string $publicKey
     * @param string $privateKey
     * @param string $node
     * @param string $type
     * @param string $worker
     */
    public function prepare(string $publicKey, string $privateKey, string $node, string $type, string $worker, int $size)
    {
		
        $this->publicKey = $publicKey;
        $this->privateKey = $privateKey;
        $this->node = $node;
        $this->type = $type;
        $this->worker = $worker;
        $this->counter = 0;
        $this->submit = 0;
        $this->confirm = 0;
        $this->found = 0;
		$this->max_target = bcsub(bcpow(16,127) ,1); //63.5-byte max target/difficulty
		$this->target = $this->max_target;
		
		// ethash stuff
		$this->P = bcsub(bcpow(2,512),38117);
		$this->size = $size;
		$this->diff = 2**14;
		$this->epochtime = 10080; // 10080 yields DAG updates twice per week @ 30s blocktimes, this won't be constant in the full implementation!
		$this->accesses = 200; 
		$this->cache_size = 2500;
		$this->k = 1; 
		$this->w = '4'; //NOT SURE WHAT VALUE THIS IS ACTUALLY SUPPOSED TO BE >.<
		//$this->w = 4;
		$this->epoch = 0;
    }
	
	/**
     * Output the miner header text.
     */
    public function outputHeader()
    {
        echo "########################\n";
        echo "# Jengascoin DAG miner #\n";
        echo "# www.jengas.io        #\n";
        echo "########################\n";
    }
	
	/**
     * Check for the required dependencies.
     */
    public function checkDependencies()
    {
        if (!extension_loaded("gmp")) {
            die("The GMP PHP extension is missing.");
        }

        if (!extension_loaded("openssl")) {
            die("The OpenSSL PHP extension is missing.");
        }

        if (floatval(phpversion()) < 7.2) {
            die("The minimum PHP version required is 7.2.");
        }
    }
	
	public function produce_dag($seed, $length) 
	{
		$b3 = new BLAKE3();
		$epoch_str = $this->epoch;
		$base_str_short = $b3->hash($seed,'16'); //shorthash record of base
		$cwd = str_replace('\\', '/', getcwd());
		$dag_path = $cwd.'/dag_cache/DAG_E='.$epoch_str.'_L='.$length.'_B=.php';
		if(!file_exists($dag_path))
		{
		
		echo "Creating DAG\n";
		$blakehash = bchexdec($b3->hash($seed,'64'));
		echo "Blakehash: $blakehash\n";
		$picker = bcpowmod($blakehash, $this->w, $this->P);
		$init = $picker;
		$o = encode_int($picker, '64');
		$percentdone = 0;
		echo "DAG percent generated: ". str_pad(number_format($percentdone*100,1,".",""),5,STR_PAD_LEFT) ."%";
		for($i=1; $i<$length; $i++) {
			// $x = $picker = ($picker * $init) % P
			$x = $picker = bcmod(bcmul($picker,$init),$this->P);
			for($i2=0; $i2++; $i2<$this->k) {
				$x = gmp_xor($x,$o[(bcmod($x,(string)$i))]);
			}
			$o .= encode_int(bcpowmod($x, $this->w, $this->P), '64');
			if(($i / $length) > ($percentdone + 0.0001))
			{
				$percentdone = ($i / $length);
				echo chr(8).chr(8).chr(8).chr(8).chr(8).chr(8). str_pad(number_format($percentdone*100,2,".",""),5,STR_PAD_LEFT) ."%";
			}
		}
		echo "\nDAG completed\n";
		echo "DAG length: " . strlen($o) . "\n";
		
		//log the DAG, DAG length, DAG epoch, and DAG seed (base)
		//$epoch_str = var_export((int)(floor($this->height/$this->epochtime)), true);
		//$daglen_str = var_export($daglength, true);
		//$base_str = var_export($base, true);
		$dag_str = var_export($o, true);
		
		/*$var = "<?php\n\n\$epoch_cache = $epoch_str;\n\$daglength_cache = $daglen_str;\n\$base_cache = $base_str;\n\$dagger_cache = $dag_str;\n?>"; */
		//file_put_contents('DAG_E'.$epoch_str.'_L'.$daglen_str.'_.php', $var);
		$var = "<?php\n\n\$dagger_cache = $dag_str;\n?>";
		
		file_force_contents($cwd.'/dag_cache/DAG_E='.$epoch_str.'_L='.$length.'.php', $var);
		unset($var); //free memory
		return $o;
		
		} else {
			$dag_file = file_get_contents($dag_path);
			return $dag_file;
		}
	}
	
	
	public function mine($daggerset) 
	{
		// nonce = randint(0, 2**64)
		$nonces_tried = 0;
		$nonce = openssl_random_pseudo_bytes(8);
		$nonce_int = decode_int($nonce);
		echo "Target:    $this->target\n";
		echo "Max T:     $this->max_target\n";
		$best_result = '';
		while (1) 
		{
			//$result = hashimoto($daggerset, get_dagsize(params, block),params, decode_int(block.prevhash), $nonce);
			//$result = $this->hashimoto($daggerset, bcmul($this->size,(string)SELF::Mb),$this->block, $nonce);
			$result = $this->hashimoto($daggerset, (string)strlen($daggerset),$this->block, $nonce);
			if (bccomp($result,$this->target) <= 0) 
			{
				echo "\nSolution:  $result\n";
				break;
			}
			$nonces_tried++;
			if(bccomp($result,$best_result) < 0 || $nonces_tried == 1)
			{
				$best_result = $result;
			}
			$nonce_int = bcadd($nonce_int,'1');
			if (bccomp($nonce_int,SELF::TwoExp64) > 0) 
			{
				$nonce_int = 0;
			}
			$nonce = encode_int($nonce_int, '64');
			
			if(($nonces_tried % 10) == 0)
			{
				//echo "\ncurrent:   $result \n";
				echo "  ".chr(8).chr(8).chr(8).chr(8).chr(8).chr(8).chr(8)."\r\rBest hash: $best_result, nonces tried: $nonces_tried";
			}
		}
		$nonce_64 = bc_arb_encode($nonce_int,'123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz');
		echo "\nReturned nonce: $nonce_64\n";
		
		return $nonce;
	}
	
	public function hashimoto($dag, $dagsize, $header, $nonce) 
	{
		$m = bcfloor(bcsub(bcdiv($dagsize,'2'),1));
		$mix = bc_hexdec(blake3($nonce.$header,'64'));
		for($i=0; $i<$this->accesses; $i++) {
			//mix ^= dag[m + (mix % 2**64) % m]
			$dagstr = '';
			$i2 = bcadd($m,bcmod(bcmod($mix,SELF::TwoExp64),$m));
			$mix256 = encode_int($mix,'64');
			for($i3=0; $i3<strlen($mix256); $i3++) //If there's a way to reference an 64-byte string in a bytewise way, that would be a great 
			{
				$dagstr .= $dag[bcadd($i2,(string)$i3)];
				if(bccomp(bcadd($i2,(string)($i3+1)),$dagsize) >= 0)
				{
					$i2 = '0';
				}					
			}
			$mix = gmp_xor(decode_int($mix256),decode_int($dagstr));
			//echo "dag[$i2]: \n     " . decode_int($dagstr) . "\n";
			//echo "mix: \n     " . $mix . "\n\n";
		}
		return bc_hexdec(dbl_blake3($mix,'64'));
	}
	
	public function quick_hashimoto($seed, $dagsize, $header, $nonce)
	{
		$m = bcfloor(bcsub(bcdiv($dagsize,'2'),1));
		$mix = bc_hexdec(blake3($nonce.$header,'64'));
		for($i=0; $i<$this->accesses; $i++) {
			//mix ^= dag[m + (mix % 2**64) % m]
			$dagstr = '';
			$i2 = bcadd($m,bcmod(bcmod($mix,SELF::TwoExp64),$m));
			$mix256 = encode_int($mix,'64');
			for($i3=0; $i3<strlen($mix256); $i3++)
			{
				$dagstr .= $dag[bcadd($i2,(string)$i3)];
				if(bccomp(bcadd($i2,(string)($i3+1)),$dagsize) >= 0)
				{
					$i2 = '0';
				}					
			}
			$mix = gmp_xor(decode_int($mix256),quick_calc($seed, $m + bcmod(bcmod($mix,SELF::TwoExp64)),$m));
			//echo "dag[$i2]: \n     " . decode_int($dagstr) . "\n";
			//echo "mix: \n     " . $mix . "\n\n";
		}
		return bc_hexdec(dbl_blake3($mix,'64'));
	}
	
	public function verify($daggerset, $block, $nonce) 
	{
		//$result = $this->hashimoto($daggerset, bcmul($this->size,(string)SELF::Mb),$this->block, $nonce);
		$result = $this->hashimoto($daggerset, (string)strlen($daggerset),$this->block, $nonce);
		return (bccomp($result,$this->target) <= 0);
	}
	
	/**
     * @return bool
     */
    public function update_block(): bool
    {
		global $noshare_time;
		global $pooltarget;
		global $pt;
		global $outp;
		global $dbg;
        $this->lastUpdate = time();

        $extra = "";
        if ($this->type == self::MODE_POOL) {
            $extra = "&worker=".$this->worker."&address=".$this->privateKey."&hashrate=".$this->speed;
			$res = file_get_contents($this->node."/mine.php?q=info".$extra);	
		} else {
			$res = file_get_contents($this->node."/api.php?q=getMiningInfo".$extra);		
        }
		$info = json_decode($res, true);
        if ($info['status'] != self::NODE_STATUS_OK) {
            return false;
        }

        $data = $info['data'];
        $this->block = $data['block'];
        $this->diff = $data['difficulty'];
		
        if ($this->type === self::MODE_POOL) {
            $this->publicKey = $data['public_key'];
        }

        $this->height = $data['height'];
		$this->epoch = (int)(floor($this->height/$this->epochtime));
		echo "\nepoch: ".$this->epoch."\n";
		$this->target = bcsub($this->max_target, $this->diff);
		
		if(!isset($pooltarget))
		{
			$pooltarget = bcmul($this->target, "$pt");
		}
		if ($this->target < 1) {	
			$this->target = 1;
		}

		if ($this->type == self::MODE_POOL) {
			if(isset($this->best))
			{
				$b[] = "\n--> Best Hash  : ".number_format($this->best, 0, '.', '');
			} else {
				$b[] = "\n--> Best Hash  : 0";
			}
			$b[] = "\n--> Target     : $this->target";
			$b[] = "\n--> Pool Target: $pooltarget";
			$b[] = "\n--> Difficulty : ".$this->diff;
			$b[] = $outp;
			$b[] = $dbg;
		} else {
			$b[] = "\n--> Target     : $this->target";
			$b[] = "\n--> Difficulty : ".$this->diff;
			$b[] = $outp;
			$b[] = $dbg;
		}
		
		//replaceCommandOutput($b);
		if(isset($dbg)) { unset($dbg); }
		unset($b);
        return true;
    }
	
	function update_dag(): bool
	{
		$res = $this->update_block();
		if (!$res) {
			die("ERROR: Could not get mining info from the node\n");
		}
		//have correct dag(s) in cache?
			//if so, pull it into memory 
		//if not,
		
		if(intval($this->height) - $this->epochtime > (int)(ceil($this->height/$this->epoch))) {
			//update $epoch
			$this->epoch = (int)(floor($this->height/$this->epochtime));
			//generate dag 
			
			//want to pregenerate next epoch's dag? if so,
				//generate next dag 
			//new epoch time for next epoch? (depends on gamification implementation)
				//if so, store it in $this->epochtime
			//save new daggerset into cache file
			
			
			return true;
		} else {
			return false;
		}
	}
	
	// NEW FUNCTIONS START ***********************************************************
	public function quick_calc($seed, $p)
	{
		$w = $this->w;
		$P = $this->P;
		$cache = [];
		
		function quick_calc_cached($p)
		{
			if(in_array($p, $cache))
			{
			}
			elseif($p == 0)
			{
				$cache[$p] = bcpowmod(blake3($seed,'64'), strval($w), $P);
			}
			else
			{
				$x = bcpowmod(blake3($seed,'64'), strval($p+1) * $w, $P);
				//for _ in range(params["k"]):
				for ($i=0; $i<$this->k; $i++)
				{
					$x = pow($x, quick_calc_cached($x % $p));
				}
				$cache[$p] = bcpowmod($x, $w, $P);
				return $cache[$p];
			}
		}
		return quick_calc_cached($p);
	}


	public function get_prevhash($n) //$n is just block height I think
	{
		if ($n <= 0)
		{	// return genesis block hash
			return(blake3('Let there be light','64'));
		} else { //return previous block hash (requires update() prior to query)
			return($this->block);
		}
	}

	public function get_seedset()
	{
		$seedset = [];
		$seedset["back_number"] = (int)$this->height - ((int)$this->height % $this->epochtime);
		$seedset["back_hash"] = get_prevhash($seedset["back_number"]);
		$seedset["front_number"] = max($seedset["back_number"] - $this->epochtime, 0);
		$seedset["front_hash"] = get_prevhash($seedset["front_number"]);
		return $seedset;
	}

	public function get_dagsize()
	{ //Not decided yet for Jengas blockchain, but will likely not scale over time in quite the same way as Ethereum DAG
		return $this->size * SELF::Mb; // + ($block['height'] / $params["epochtime"]) * $params["n_inc"];
	}

	public function get_daggerset($params, $block)
	{
		$dagsz = get_dagsize($params, $block);
		$seedset = get_seedset($params, $block);
		if ($seedset["front_hash"] <= 0)
		{
			# No back buffer is possible, just make front buffer
			return "{front: {dag: " . produce_dag($params, $seedset['front_hash'], $dagsz) . ", block_number: 0}}";
		}
		else
		{
			return "{front: {dag: " . produce_dag($seedset["front_hash"], $dagsz) . ", block_number: " . $seedset["front_number"] . "},
			back: {dag: " . produce_dag($seedset["back_hash"], $dagsz) . ", block_number: " . $seedset["back_number"] . "}}";
		}
	}

	public function light_verify($header, $nonce)
	{
		$seedset = get_seedset($block);
		$result = quick_hashimoto($seedset["front_hash"], get_dagsize($params, $block), $params, decode_int($block['prevhash']), $nonce);
		return $result * $params["diff"] < pow(2, 256);
	}

	// NEW FUNCTIONS END ***********************************************************

    /**
     * @param array $source
     * @param mixed $source_base
     * @param mixed $target_base
     * @return array
     *
     * @author Mika Tuupola
     * @link   https://github.com/tuupola/base58
     */
	 
    public function baseConvert($source, $source_base, $target_base)
    {
		$source = str_split($source);
        $result = [];
        while ($count = count($source)) {
            $quotient = [];
            $remainder = 0;
            for ($i = 0; $i !== $count; $i++) {
                $accumulator = intval($source[$i]) + $remainder * $source_base;
                $digit = (integer)($accumulator / $target_base);
                $remainder = $accumulator % $target_base;
                if (count($quotient) || $digit) {
                    array_push($quotient, $digit);
                };
            }
            array_unshift($result, $remainder);
            $source = $quotient;
        }
		return implode("", array_map(function ($ascii) {
            return chr($ascii);
        }, $result));
    }

    /**
     * @param mixed $data
     * @param bool  $integer
     * @return int|string
     *
     * @author Mika Tuupola
     * @link   https://github.com/tuupola/base58
     */
    public function base58Decode($data, $integer = false)
    {
        $data = str_split($data);
        $data = array_map(function ($character) {
            $chars = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz";
            return strpos($chars, $character);
        }, $data);
        /* Return as integer when requested. */
        if ($integer) {
            $converted = $this->baseConvert($data, 58, 10);
            return (integer)implode("", $converted);
        }
        $converted = baseConvert($data, 58, 256);
        return implode("", array_map(function ($ascii) {
            return chr($ascii);
        }, $converted));
    }
}


// BCmath version for huge numbers
function bc_arb_encode($num, $basestr) {
    if( ! function_exists('bcadd') ) {
        Throw new Exception('You need the BCmath extension.');
    }

    $base = strlen($basestr);
    $rep = '';

    while( true ){
        if( strlen($num) < 2 ) {
            if( intval($num) <= 0 ) {
                break;
            }
        }
        $rem = bcmod($num, $base);
        $rep = $basestr[intval($rem)] . $rep;
        $num = bcdiv(bcsub($num, $rem), $base);
    }
    return $rep;
}

function bc_arb_decode($num, $basestr) {
    if( ! function_exists('bcadd') ) {
        Throw new Exception('You need the BCmath extension.');
    }

    $base = strlen($basestr);
    $dec = '0';

    $num_arr = str_split((string)$num);
    $cnt = strlen($num);
    for($i=0; $i < $cnt; $i++) {
        $pos = strpos($basestr, $num_arr[$i]);
        if( $pos === false ) {
            Throw new Exception(sprintf('Unknown character %s at offset %d', $num_arr[$i], $i));
        }
        $dec = bcadd(bcmul($dec, $base), $pos);
    }
    return $dec;
}
//hexdec with BCmath
function bc_hexdec($num) {
    return bc_arb_decode(strtolower($num), '0123456789abcdef');
}
function bc_dechex($num) {
    return bc_arb_encode($num, '0123456789abcdef');
}
function bchexdec($hex)
{
	$dec = 0;
    $len = strlen($hex);
    for ($i = 1; $i <= $len; $i++)
        $dec = bcadd(strval($dec), bcmul(strval(hexdec($hex[$i - 1])), bcpow('16', strval($len - $i))));
   
    return $dec;
}

function bcfloor($number)
{
	if (strpos($number, '.') !== false) {
		if (preg_match("~\.[0]+$~", $number)) return bcround($number, 0);
		if ($number[0] != '-') return bcadd($number, 0, 0);
		return bcsub($number, 1, 0);
	}
	return $number;
}

function bcround($number, $precision = 0)
{
	if (strpos($number, '.') !== false) {
		if ($number[0] != '-') return bcadd($number, '0.' . str_repeat('0', $precision) . '5', $precision);
		return bcsub($number, '0.' . str_repeat('0', $precision) . '5', $precision);
	}
	return $number;
}


function encode_int($x,$bytelen) 
{
    // Encode an integer x as a string of bytelen characters using a big-endian scheme 
    $o = '';
    for ($i=0; $i<($bytelen); $i++)
	{
        $o = chr(bcmod($x,'256')).$o;
        $x = bcdiv($x,'256');
	}
    return $o;
}

function decode_int($s)
{
    // Unencode an integer x from a string using a big-endian scheme 
    $x = '';
    for ($i=0; $i<strlen($s); $i++)
	{
        $x = bcmul($x,'256');
        $x = bcadd($x, ord($s[$i]));
	}
    return $x;
}

function blake3($x, $len_str)
{
	$b3 = new BLAKE3();
	//$b3->hash($seed) ???
	
	//if isinstance(x, (int, long)):
	//x = encode_int(x)
	//return decode_int(utils.sha3(x))
	if(is_int($x))
	{
		$x = encode_int($x, '64');
	}
	//return decode_int($b3->hash($x,$len_str)); //not sure where utils is in original eth_stuff.py. We don't have access to it so ?
	return $b3->hash($x,$len_str);
}

function dbl_blake3($x,$len_str)
{
	$b3 = new BLAKE3();
	//$b3->hash($seed); ???
	
	//if isinstance(x, (int, long)):
	//x = encode_int(x)
	//return decode_int(utils.sha3(utils.sha3(x)))
	
	if (is_int($x))
	{
		$x = encode_int($x, '64');
	}
	//return decode_int(utils.sha3(utils.sha3(x)))
	//return decode_int($b3->hash($b3->hash($x,$len_str),$len_str)); //same issue as above
	return $b3->hash($b3->hash($x,$len_str),$len_str);
}

function file_force_contents($dir, $contents){
	$parts = explode('/', $dir);
	$file = array_pop($parts);
	$dir = '';
	foreach($parts as $part)
	$dir .= "$part/";
		if(!is_dir($dir)) {
			if(!mkdir($dir,0777,true)) {
				echo "\ndir: ".$dir."\n";
				die("Failed to create DAG cache directory & file!\n");
			}
		}
	file_put_contents("$dir/$file", $contents);
}