<?php

namespace Jengascoin\Miner;
//require('blake3_optimized.php');
//use BLAKE3;

ini_set("memory_limit", "1G");

/*
metadata = {
	#miner inputs
	"diff":             2 ** 256,
	"header":           '\xF0' * 32,
	"update_period":    1, # seconds, float
	# miner outputs
	'num_hashes':       0, 
	'update_period':    update_period,
	'best_hash':        get_target(2) 
*/

# usage:
# php update_miner.php [nonce] 
if(isset($argv[2])) {
	$nonce = $argv[2];
	if(!is_int($nonce)) {
		err = true;
	}

if (empty($type) || empty($public_key) || empty($node) || ($type == self::MODE_SOLO && empty($private_key))) {
            echo "Usage:

For Initialization: ./update_miner.php 

For Update: ./update_miner.php <nonce-integer> <mix-digest-bytestring> <result-bytestring>\n\n";
            exit;
        }
	
			
$type = trim($argv[1]);
$node = trim($argv[2]);
$public_key = trim($argv[3]);
if(isset($argv[4]))
{
	$private_key = trim($argv[4]);
	
} else {
	$private_key = '';
}
new Miner($type, $node, $public_key, $private_key);

/**
 * Class Miner
 */
class Miner
{
    public const VERSION = '0.1';
    public const MODE_POOL = 'pool';
    public const MODE_SOLO = 'solo';
    public const NODE_STATUS_OK = 'ok';
    private $publicKey;
    private $privateKey;
    private $speed;
    private $avgSpeed;
    private $node;
    private $block;
    private $difficulty;
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
    private $testnet;

    /**
     * Miner constructor.
     *
     * @param $type
     * @param $node
     * @param $public_key
     * @param $private_key
     */
    public function __construct($type, $node, $public_key, $private_key)
    {
		global $pt;
        //$this->outputHeader();

        $this->checkDependencies();

        if (empty($type) || empty($public_key) || empty($node) || ($type == self::MODE_SOLO && empty($private_key))) {
            echo "Usage:

For Solo mining: ./miner solo <node> <public_key> <private_key>

For Pool mining: ./miner pool <pool-address> <your-address>\n\n";
            exit;
        }

        if ($type == self::MODE_POOL) {
            $private_key = $public_key;
        }

		$worker = uniqid();
		$this->prepare($public_key, $private_key, $node, $type, $worker);
		
		$pt_r = file_get_contents("http://pool.jengas.io/pt.php");
		if($pt_r > 0)
		{
			//echo "PT_R $pt_r\n";
			$pt = $pt_r;
		}
		
		$res = $this->update();
		if (!$res) {
			die("ERROR: Could not get mining info from the node\n");
		}
        $this->run();
    }

    /**
     * @param string $publicKey
     * @param string $privateKey
     * @param string $node
     * @param string $type
     * @param string $worker
     */
    public function prepare(string $publicKey, string $privateKey, string $node, string $type, string $worker)
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
    }

    /**
     * @return bool
     */
    public function update(): bool
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
        $this->difficulty = $data['difficulty'];
		
        if ($this->type === self::MODE_POOL) {
            $this->publicKey = $data['public_key'];
        }

        $this->height = $data['height'];
        $max_target = bchexdec('0x00000000FFFF0000000000000000000000000000000000000000000000000000');
		$target = bcsub($max_target, $this->difficulty);
		if(!isset($pooltarget))
		{
			$pooltarget = bcmul($target, "$pt");
		}
		if ($target < 1) {	
			$target = 1;
		}

		if ($this->type == self::MODE_POOL) {
			if(isset($this->best))
			{
				$b[] = "--> Best Hash  : ".number_format($this->best, 0, '.', '')."\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20";
			} else {
				$b[] = "--> Best Hash  : 0 \x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20";
			}
			$b[] = "--> Target     : $target\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20";
			$b[] = "--> Pool Target: $pooltarget\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20";
			$b[] = "--> Difficulty : ".$this->difficulty."\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20";
			$b[] = $outp;
			$b[] = $dbg;
		} else {
			$b[] = "--> Target     : $target \x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20";
			$b[] = "--> Difficulty : ".$this->difficulty."\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20";
			$b[] = $outp;
			$b[] = $dbg;
		}
		
		replaceCommandOutput($b);
		if(isset($dbg)) { unset($dbg); }
		unset($b);
        return true;
    }
	
    /**
     * @param string $nonce
     * @param string $blakehash
     * @return bool
     */
    private function submit(string $nonce, string $blakehash): bool
    {
		global $noshare_time;
		global $pooltarget;
		global $dbg;

		$pData = array(
			'blakehash'       => $blakehash,
			'nonce'       => $nonce,
			'private_key' => $this->privateKey,
			'public_key'  => $this->publicKey,
			'address'     => $this->privateKey,
        );
		
		if ($this->type == self::MODE_POOL) {
			$url = $this->node."/mine.php?q=submitNonce";	
		} else {
			$url = $this->node."/api.php?q=submitNonce";		
        }
		$curl = curl_init($url);
		curl_setopt($curl, CURLOPT_URL, $url);
		curl_setopt($curl, CURLOPT_CUSTOMREQUEST, "POST");
		curl_setopt($curl, CURLOPT_POSTFIELDS,$pData);
		curl_setopt($curl, CURLOPT_RETURNTRANSFER, true);
		$res = curl_exec($curl);
		if (curl_errno($curl)) {
			$error_msg = curl_error($curl);
			var_dump($error_msg);
		}
		curl_close($curl);
		
		$data = json_decode($res, true);
		$max_target = bchexdec('0x00000000FFFF0000000000000000000000000000000000000000000000000000');
		$target = bcsub($max_target, $this->difficulty);
        if ($data['status'] == self::NODE_STATUS_OK) {
			if ($this->type == self::MODE_POOL) {
				$share_time = time() - $noshare_time;
				$pooltarget = pooltarget($share_time,$pooltarget);
				$noshare_time = time();
				$dbg = "--> Nonce confirmed.\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20";
			}
			$this->update();
            return true;
        } else {
			if ($this->type == self::MODE_POOL) {
				$share_time = time() - $noshare_time;
				$pooltarget = pooltarget($share_time,$pooltarget);
				$dbg = "--> The nonce did not confirm.\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20";
				$noshare_time = time();
			}
			$this->update();
            return false;
        }
    }

    /**
     * Run the miner.
     */
    public function run()
    {
		global $noshare_time;
		global $share_time;
		global $last_share_time;
		global $pooltarget;
		global $pt;
		global $outp;
		global $dbg;
		$this->best = bchexdec('0x00000000FFFF0000000000000000000000000000000000000000000000000000');
        $this->allTime = microtime(true);
        $this->beginTime = time();
        $it = 0;
        $this->counter = 0;
		$noshare_time = time();
        $start = microtime(true);
        while (1) {
            $this->counter++;
			$hrt = duration((time() - $this->beginTime));
            if (time() - $this->lastUpdate > 2) {
                $outp = "--> Hashrate: ".$this->speed." H/s   ".
                    "Average: ".$this->avgSpeed." H/s  ".
                    "Total: ".$this->counter."  ".
                    "Time: $hrt  ".
                    "Shares: ".$this->confirm." ".
                    "Finds: ".$this->found."\x20\x20\x20\x20\x20\x20";
                $this->update();
            }

            $nonce = base64_encode(openssl_random_pseudo_bytes(32));
            $nonce = preg_replace("/[^a-zA-Z0-9]/", "", $nonce);
            $base = $this->publicKey."-".$nonce."-".$this->block."-".$this->difficulty;
			$b3 = new BLAKE3();	
			$blakehash = $b3->hash($base,'64');			
			$hash = $base.$blakehash;
			/*
			// hash the base 8 times
			for ($i = 0; $i < 7; $i++) {
				$hash = hex2bin($b3->hash($hash,'64'));
			} 
			*/
			$b3 = new BLAKE3();
			$hash = $b3->hash($hash,'64');
			$m = str_split($hash, 2);
			// calculate a number based on 32 hex numbers	
			$proc = hexdec($m[1]).hexdec($m[3]).hexdec($m[4]).hexdec($m[5]).hexdec($m[7]).hexdec($m[8]).hexdec($m[10]).hexdec($m[11]).hexdec($m[13]).hexdec($m[14]).hexdec($m[15]).hexdec($m[19]).hexdec($m[21]).hexdec($m[23]).hexdec($m[26]).hexdec($m[30]).hexdec($m[32]).hexdec($m[35]).hexdec($m[39]).hexdec($m[41]).hexdec($m[44]).hexdec($m[46]).hexdec($m[48]).hexdec($m[50]).hexdec($m[51]).hexdec($m[53]).hexdec($m[55]).hexdec($m[56]).hexdec($m[59]).hexdec($m[60]).hexdec($m[62]).hexdec($m[63]);	
			// the number must not start with 0
			$proc = ltrim($proc, '0');
			$result = $proc;
			
			if($result > 0 AND $result <= $this->best)
			{	
				$this->best = $result;
			}
			$max_target = bchexdec('0x00000000FFFF0000000000000000000000000000000000000000000000000000');
			$target = bcsub($max_target, $this->difficulty);
			if(!isset($pooltarget))
			{
				$pooltarget = bcmul("$target", "$pt");
			}
			if ($target < 1) {
				$target = 1;
			}
			
			if ($this->type == self::MODE_POOL) {
				$our_target = $pooltarget;
			} else {
				$our_target = $target;
			}
			
            if ($result > 0 && $result <= $our_target) {
				$confirmed = $this->submit($nonce, $blakehash);
                if ($confirmed && $result <= $target) {
                    $this->found++;
                } elseif ($confirmed) {
                    $this->confirm++;
                }
                $this->submit++;
                if ($this->testnet) {
                    sleep(240);
                }
            }
            $it++;
            if ($it == 10) {
                $it = 0;
                $end = microtime(true);
                $this->speed = 10 / ($end - $start);
                $this->avgSpeed = $this->counter / ($end - $this->allTime);
                $start = $end;
            }
        }
    }

    /**
     * @param array $source
     * @param mixed $source_base
     * @param mixed $target_base
     * @return array
     *
     * @author Mika Tuupola
     * @link   https://github.com/tuupola/base58
     */
    public function baseConvert(array $source, $source_base, $target_base)
    {
        $result = [];
        while ($count = count($source)) {
            $quotient = [];
            $remainder = 0;
            for ($i = 0; $i !== $count; $i++) {
                $accumulator = $source[$i] + $remainder * $source_base;
                $digit = (integer)($accumulator / $target_base);
                $remainder = $accumulator % $target_base;
                if (count($quotient) || $digit) {
                    array_push($quotient, $digit);
                };
            }
            array_unshift($result, $remainder);
            $source = $quotient;
        }
        return $result;
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
        $converted = $this->baseConvert($data, 58, 256);
        return implode("", array_map(function ($ascii) {
            return chr($ascii);
        }, $converted));
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

    /**
     * Output the miner header text.
     */
    public function outputHeader()
    {
        echo "######################\n";
        echo "# Jengascoin Miner   #\n";
        echo "# www.jengas.io      #\n";
        echo "######################\n";
    }

}
function duration($ptime) {
	if ($ptime < 1)
	{
		return '0 seconds';
	}

	$a = array( 365 * 24 * 60 * 60  =>  'year',
				 30 * 24 * 60 * 60  =>  'month',
					  24 * 60 * 60  =>  'day',
						   60 * 60  =>  'hour',
								60  =>  'minute',
								 1  =>  'second'
				);
	$a_plural = array( 'year'   => 'years',
					   'month'  => 'months',
					   'day'    => 'days',
					   'hour'   => 'hours',
					   'minute' => 'minutes',
					   'second' => 'seconds'
				);

	foreach ($a as $secs => $str)
	{
		$d = $ptime / $secs;
		if ($d >= 1)
		{
			$r = round($d);
			return $r . ' ' . ($r > 1 ? $a_plural[$str] : $str);
		}
	}
}
function replaceCommandOutput(array $output) {
  static $oldLines = 0;
  $numNewLines = count($output) - 1;

  if ($oldLines == 0) {
    $oldLines = $numNewLines;
  }

  echo implode(PHP_EOL, $output);
  echo chr(27) . "[0G";
  echo chr(27) . "[" . $oldLines . "A";

  $numNewLines = $oldLines;
}
function bcround($number, $precision = 0) {
	if (strpos($number, '.') !== false) {
		if ($number[0] != '-') return bcadd($number, '0.' . str_repeat('0', $precision) . '5', $precision);
		return bcsub($number, '0.' . str_repeat('0', $precision) . '5', $precision);
	}
	return $number;
}
function bcceil($number) {
	if (strpos($number, '.') !== false) {
		if (preg_match("~\.[0]+$~", $number)) return bcround($number, 0);
		if ($number[0] != '-') return bcadd($number, 1, 0);
		return bcsub($number, 0, 0);
	}
	return $number;
}
function bcfloor($number) {
	if (strpos($number, '.') !== false) {
		if (preg_match("~\.[0]+$~", $number)) return bcround($number, 0);
		if ($number[0] != '-') return bcadd($number, 0, 0);
		return bcsub($number, 1, 0);
	}
	return $number;
}
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
function bc_hexdec($num) {
    return bc_arb_decode(strtolower($num), '0123456789abcdef');
}
function bc_dechex($num) {
    return bc_arb_encode($num, '0123456789abcdef');
}
function pooltarget($at,$pool_target) {	//@Daru
	global $pooltarget;
	$max_target = bchexdec('0x00000000FFFF0000000000000000000000000000000000000000000000000000');
	$p_term_coeff_unscaled = 0.5;
	$p_term_coeff = $p_term_coeff_unscaled / 115;
	$p_term = $p_term_coeff * (115 - $at);
	$p_term_str = sprintf("%.4f", $p_term);
	$current_target = bcsub($max_target,$pool_target);
	$pt_change = bcfloor(bcmul($current_target, $p_term_str, 4));
	$pooltarget = bcadd($pool_target,$pt_change);
	return $pooltarget;
}
function bchexdec($hex) {
	$dec = 0;
	$len = strlen($hex);
	for ($i = 1; $i <= $len; $i++)
		$dec = bcadd($dec, bcmul(strval(hexdec($hex[$i - 1])), bcpow('16', strval($len - $i))));
   
	return $dec;
}