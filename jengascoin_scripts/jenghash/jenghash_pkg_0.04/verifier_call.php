<?php

/*
class Verifier:  # high-level class

    # must be initialized with either local chainState dictionary or node_url
    def __init__(self, size_max=1, chain_state=None, node_url=None, alt_seedblock=False, tiny=False):
*/
	
/*
{"status":"ok","data":{"difficulty":"57894484195676894936233969324885049345274108201212047720873616043608126730146","block":"z9epQ9ijVhrHYpyFMANKqUi9xhSyEQwKeuyVRXSYWdczX8siZXXVvJeVS4bG5tfk5GdvkS944P5eNJxoPZ6YUBN","height":7202,"testnet":false,"recommendation":"mine"},"coin":"jengas"}
*/


$difficulty = '57894484195676894936233969324885049345274108201212047720873616043608126730146';
$block = 'z9epQ9ijVhrHYpyFMANKqUi9xhSyEQwKeuyVRXSYWdczX8siZXXVvJeVS4bG5tfk5GdvkS944P5eNJxoPZ6YUBN';
$height = '7202';

//$mix_digest = '£yÙ&naH¯8Eq÷NµU­³	±sÏÕòî]ÿ';
//$result = '¦Áñ;aÅTmª~w`1Õç"¥=ÈÃ';
$mix_digest = '0x'.bin2hex('£yÙ&naH¯8Eq÷NµU­³	±sÏÕòî]ÿ');
$result = '0x'.bin2hex('¦Áñ;aÅTmª~w`1Õç"¥=ÈÃ');
$nonce = '7609359626069789394';
$header = $block;

$call_verifier = sprintf("python verify.py %s %s %s %s %s %s %s", $difficulty, $block, $height, $mix_digest, $result, $nonce, $header);
echo "\noutput: ".$call_verifier."\n\n";

$ret_code = 0;
//exec($call_verifier, $ret_code);
passthru($call_verifier, $ret_code);

echo "php ret_code: $ret_code";

?>