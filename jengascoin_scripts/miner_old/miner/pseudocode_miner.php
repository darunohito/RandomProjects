<? php

/* Miner Pseudocode

prepare() //variables and structs
update_block() //current block info

[dag1, dag2] = load_dag() //check cache for correct dag
if (!dag_exists || !next_dag_exists) 
	update_dag() //produce current dags and cache
endif

$hashrate = benchmark(); //test hashrate
$update_interval = ceil($hashrate * $update_period); 

while(1)
	update_block() //get current block info
	while (dag_exists) //dag still current?
		if(new_epoch)
			mine(easy_hash); 
		elseif(
		mine()
	endwhile
	
endwhile


function mine(string $hash_type): bool
{
	$nonce_count = 0;
	while($nonce_count < $update_interval)
	$result = hashimoto($daggerset,$dagsize,$height,$nonce);
	if $result < $target
		if($hash_type == 'easy_hash')
			submit($nonce, $random_number);
			return;
		else
			submit($nonce);
			return;
		endif
	endif;
}
*/