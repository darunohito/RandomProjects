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
//             42885687071405043298391678928695402248525555573186137581213599146454275981312 <-- around current target
$block = 'z9epQ9ijVhrHYpyFMANKqUi9xhSyEQwKeuyVRXSYWdczX8siZXXVvJeVS4bG5tfk5GdvkS944P5eNJxoPZ6YUBN';
$height = '7202';

//$mix_digest = '£yÙ&naH¯8Eq÷NµU­³	±sÏÕòî]ÿ';
//$result = '¦Áñ;aÅTmª~w`1Õç"¥=ÈÃ';
$mix_digest = '451194305969577372195535114095268554265999434508489097093700248643035756963';
$result = '59146142635372104391931399111389324454706672837199196834793707341420027059726';

$nonce = '7609359626069789394';
$header = $block;


$call_verifier = sprintf("python verify.py %s %s %s %s %s %s %s", $difficulty, $block, $height, $mix_digest, $result, $nonce, $header);
echo "\nshell call: ".$call_verifier."\n\n";

$ret_code = 0;
//exec($call_verifier, $ret_code);
passthru($call_verifier, $ret_code);

echo "php ret_code: $ret_code";

?>