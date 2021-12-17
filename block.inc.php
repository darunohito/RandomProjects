<?php

class Block
{
    /*
    * adds a block to the chain DB
    */
    public function add($height, $public_key, $nonce, $data, $date, $signature, $difficulty, $reward_signature, $blakehash, $bootstrapping=false)
    {
        global $db, $_config;
        $acc = new Account();
        $trx = new Transaction();

        $generator = $acc->get_address($public_key);

        // the transactions are always sorted in the same way, on all nodes, as they are hashed as json
        ksort($data);

        // create the hash / block id
        $hash = $this->hash($generator, $height, $date, $nonce, $data, $signature, $difficulty, $blakehash);
        $json = json_encode($data);

        // create the block data and check it against the signature
        $info = "{$generator}-{$height}-{$date}-{$nonce}-{$json}-{$difficulty}-{$blakehash}";
        if (!$bootstrapping) {
            if (!$acc->check_signature($info, $signature, $public_key)) {
                _log("Info: $info", 3);
                _log("Signature: $signature", 3);
                _log("Public Key: $public_key", 3);
                _log("Block signature check failed", 3);
                return false;
            }

            if (!$this->parse_block($hash, $height, $data, true)) {
                _log("Parse block failed");
                return false;
            }
        }
        // lock table to avoid race conditions on blocks
        $db->exec("LOCK TABLES blocks WRITE, accounts WRITE, transactions WRITE, mempool WRITE, peers write, config WRITE, assets WRITE, assets_balance WRITE, assets_market WRITE, chain_metrics WRITE");

        $reward = $this->reward($height, $data);
        
        if($height > 1) { 
            $msg = '';
            $current_burned_fees = $reward['burnt'];
            $newsupply = $reward['reward'];
            $reward = $reward['total'];
        } else { 
            $msg = $_config['genesis_message']; 
            $reward = $reward['total'];
        }

        // the reward transaction
        $transaction = [
            "src"        => $generator,
            "dst"        => $generator,
            "val"        => $reward,
            "version"    => 0,
            "date"       => $date,
            "message"    => $msg,
            "fee"        => "0.00000000",
            "public_key" => $public_key,
        ];
        $transaction['signature'] = $reward_signature;
        // hash the transaction
        $transaction['id'] = $trx->hash($transaction);
        if (!$bootstrapping) {
            // check the signature
            $info = $transaction['val']."-".$transaction['fee']."-".$transaction['dst']."-".$transaction['message']."-".$transaction['version']."-".$transaction['public_key']."-".$transaction['date'];
            if (!$acc->check_signature($info, $reward_signature, $public_key)) {
                _log("Reward signature failed");
                _log("Info $info", 3);
                _log("Sig $reward_signature", 3);
                _log("Pubkey $public_key", 3);
                return false;
            }
        }
        // insert the block into the db
        $db->beginTransaction();
        $total = count($data);

        $bind = [
            ":id"           => $hash,
            ":generator"    => $generator,
            ":signature"    => $signature,
            ":height"       => $height,
            ":date"         => $date,
            ":nonce"        => $nonce,
            ":difficulty"   => $difficulty,
            ":blakehash"    => $blakehash,
            ":transactions" => $total,
        ];
        $res = $db->run(
            "INSERT into blocks SET id=:id, generator=:generator, height=:height,`date`=:date,nonce=:nonce, signature=:signature, difficulty=:difficulty, blakehash=:blakehash, transactions=:transactions",
            $bind
        );
        if ($res != 1) {
            // rollback and exit if it fails
            _log("Block DB insert failed");
            $db->rollback();
            $db->exec("UNLOCK TABLES");
            return false;
        }

        // insert the reward transaction in the db
        $res=$trx->add($hash, $height, $transaction);
        if ($res == false) {
            // rollback and exit if it fails
            _log("Reward DB insert failed");
            $db->rollback();
            $db->exec("UNLOCK TABLES");
            return false;
        }

        // parse the block's transactions and insert them to db
        $res = $this->parse_block($hash, $height, $data, false, $bootstrapping);

        if ($res==true) {
            $res=$this->asset_market_orders($height, $hash, $public_key, $date, $signature);
        }
        
        // if any fails, rollback
        if ($res == false) {
            _log("Rollback block", 3);
            $db->rollback();
        } else {
            _log("Commiting block", 3);
            $db->commit();
        }
        // release the locking as everything is finished
        $db->exec("UNLOCK TABLES");
        
        $ttltxns = $db->run("SELECT COUNT(*) as `total` FROM transactions WHERE block=:block", [":block"=>$hash]);
        if($ttltxns)
        {
            $totaltxns = $ttltxns['0'];
            $totaltxns = $totaltxns['total'];
            _log("Total block transactions $totaltxns", 3);
            $update_tx_count = $db->run("UPDATE blocks SET transactions=:transactions WHERE id=:id", [":id"=>$hash, ":transactions"=>$totaltxns]);
        }
        
        //create block merkle root
        $merkletree = new MerkleTree();
        $b3 = new BLAKE3();
        //get all the transactions from this block
        $alltxs = $db->run("SELECT * FROM transactions WHERE block=:block ORDER by id ASC", [":block"=>$hash]);
        foreach ($alltxs as $x) {
            _log("TXID SORT: $x[id]", 3);
            _log("SRC of MERKLE TX HASH: $x[id]", 3);
            $merklehash = $b3->hash($x['id']);
            _log("Transaction ID: $x[id] | Merkle Hash: $merklehash", 3);
            $merkletree->addElement($x['id']);
            $update_tx_merkle = $db->run("UPDATE transactions SET merklehash=:merklehash WHERE id=:id", [":merklehash"=>$merklehash, ":id"=>$merklehash]);
        }
        $merkletree->create();
        $merkle_root = $merkletree->getRoot();
        $update_block_merkle_root = $db->run("UPDATE blocks SET merkleroot=:merkleroot WHERE id=:id", [":merkleroot"=>$merkle_root, ":id"=>$hash]);
        _log("Block ID: $hash | Merkle Root: $merkle_root", 3);
        
        //update metrics
        // calculate the transaction fees
        $xfees = 0;
        $marketplace_burned = 0;
        $marketplace_fees = 0;
        $royals = 0;
        if (count($data) > 0) {
            foreach ($data as $x) {
                $xfees = bcadd($xfees, $x['fee'], 8);
                if($x['version'] == 50 || $x['version'] == 55){
                    $marketplace_burned = bcadd($marketplace_burned, $x['val'], 8);
                } elseif($x['version'] == 50 || $x['version'] == 51 || $x['version'] == 52 || $x['version'] == 50) {
                    $marketplace_fees = bcadd($marketplace_fees, $x['fee'], 8);
                } elseif($x['version'] == 59) {
                    $royals = bcadd($royals, $x['val'], 8);
                }
            }
            $update_block_fees = $db->run("UPDATE blocks SET fees=:fees, marketplace_burned=:marketplace_burned, marketplace_fees=:marketplace_fees, royalties=:royals, fees_burned=:fees_burned WHERE id=:id", [":fees"=>$xfees, ":marketplace_burned"=>$marketplace_burned, ":marketplace_fees"=>$marketplace_fees, ":royals"=>$royals, ":fees_burned"=>$current_burned_fees, ":id"=>$hash]);
        }
        //get all the royalty transactions from this block
        /*
        $xroyalties = 0;
        $royalty_txs = $db->run("SELECT * FROM transactions WHERE block=:block AND version='59' ORDER by id ASC", [":block"=>$hash]);
        foreach ($royalty_txs as $x) {
            $xroyalties += $x['val'];
        }
        */
        
        
        $chain_metrics = $db->run("INSERT into chain_metrics SET id=1 ON DUPLICATE KEY UPDATE id=1");
          
        //init day fees in chain metrics
        //make sure that there is a value in day_fees, if not, add it and do initial data
        $chain_metrics = $db->row("SELECT * FROM chain_metrics WHERE id=:id", [":id"=>1]);
        $day_fees = $chain_metrics['day_fees'];
        if($height >= 2880){
            $limit = $height - 2880;
        } else {
            $limit = 1;
        }
        _log("HEIGHT FOR DAY FEES: $limit");
        if($day_fees <= 0.00000000) {
            $day = $db->run("SELECT SUM(fees) as 'fees', SUM(marketplace_fees) as 'marketplace_fees', SUM(marketplace_burned) as 'marketplace_burned', SUM(fees_burned) as 'fees_burned' FROM blocks WHERE height>=:limit", [":limit" => $limit]);
            /*
            if(!$day['0']->fees){
                $day_fees = 0;
            } else {
                $day_fees = $day['0']->fees;
            }
            if(!$day['0']->marketplace_burned){
                    $day_marketplace_burned = 0;
                } else {
                    $day_marketplace_burned = $day['0']->marketplace_burned;
                }
            if(!$day['0']->marketplace_fees){
                    $day_marketplace_fees = 0;
                } else {
                    $day_marketplace_fees = $day['0']->marketplace_fees;
                }
            if(!$day['0']->fees_burned){
                    $day_fees_burned = 0;
                } else {
                    $day_fees_burned = $day['0']->fees_burned;
                }
            */
            $day_fees = $day['0']['fees'];
            _log("DAY FEES line 226: $day_fees");
            $day_marketplace_burned = $day['0']['marketplace_burned'];
            _log("DAY MKTPLC BURNED line 228: $day_marketplace_burned");
            $day_marketplace_fees = $day['0']['marketplace_fees'];
            _log("DAY MKTPLC FEES line 230: $day_marketplace_fees");
            $day_fees_burned = $day['0']['fees_burned'];
            _log("DAY FEES BURNED line 232: $day_fees_burned");
            $day_fees = bcsub(bcsub($day_fees, $day_fees_burned, 8), $current_burned_fees, 8);
            _log("DAY FEES PROCESSED line 234: $day_fees");
            $day_marketplace_fees = bcadd(bcmul($day_marketplace_burned, "0.00000001", 8), $day_marketplace_fees, 8);
            _log("DAY MKTPLC FEES PROESSED line 236: $day_marketplace_fees");
            $update_chain_metrics = $db->run("UPDATE chain_metrics SET total_royalties=total_royalties+:royals, total_fees=total_fees+:xfees, total_supply=total_supply+:newsupply, day_fees=:day_fees, day_marketplace_fees=:day_marketplace_fees WHERE id=:id", [":royals"=>$royals,":xfees"=>$xfees,":newsupply"=>$newsupply,":day_fees"=>$day_fees, ":day_marketplace_fees"=>$day_marketplace_fees, ":id"=>1]);
            }     
        if($height > 2881){
            //decrease day_fees and $day_marketplace_fee by subtracting old_fee and old_marketplace_fee first, before updating old
            $day_fees = bcsub(bcadd(bcsub($chain_metrics['day_fees'], $chain_metrics['old_fee'], 8), $xfees, 8), $current_burned_fees, 8);
            _log("DAY FEES line 242: $day_fees");
            $day_marketplace_fees = bcadd(bcsub($chain_metrics['day_marketplace_fees'], $chain_metrics['old_marketplace_fee'], 8), $marketplace_fees, 8);
            _log("DAY MKTPLC FEES line 244: $day_marketplace_fees");
            
            //go back one extra block for old_values
            $old_blk = $height - 2880;
            $old_block = $db->row("SELECT fees, fees_burned, marketplace_fees, marketplace_burned FROM blocks WHERE height=:limit", [":limit" => $old_blk]);
            $old_fee = bcsub($old_block['fees'], $old_block['fees_burned'], 8);
            $old_marketplace_fee = bcadd(bcmul($old_block['marketplace_burned'], "0.00000001", 8), $old_block['marketplace_fees'], 8);
            
            $update_chain_metric = $db->run("UPDATE chain_metrics SET total_royalties=total_royalties+:royals, total_fees=total_fees+:xfees, total_supply=total_supply+:newsupply, day_fees=:day_fees, day_marketplace_fees=:day_marketplace_fees, old_fee=:old_fee, old_marketplace_fee=:old_marketplace_fee WHERE id=:id", [":royals"=>$royals,":xfees"=>$xfees,":newsupply"=>$newsupply,":old_fee"=>$old_fee, ":old_marketplace_fee"=>$old_marketplace_fee, ":day_fees"=>$day_fees, ":day_marketplace_fees"=>$day_marketplace_fees, ":id"=>1]);
        }
        
        return true;
    }
    
    /*
    * processes asset market orders
    */
    public function asset_market_orders($height, $hash, $public_key, $date, $signature)
    {
        global $db;
        $trx=new Transaction;
        // checks all bid market orders ordered in the same way on all nodes
        $r=$db->run("SELECT * FROM assets_market WHERE status=0 and quantity_done<quantity AND type='bid' ORDER by asset ASC, id ASC");
        foreach ($r as $x) {
            $finished=0;
            //remaining part of the order
            $val=$x['quantity']-$x['quantity_done'];
            // starts checking all ask orders that are still valid
            $asks=$db->run("SELECT * FROM assets_market WHERE status=0 and quantity_done<quantity AND asset=:asset AND price<=:price AND type='ask' ORDER by price ASC, id ASC", [":asset"=>$x['asset'], ":price"=>$x['price']]);
            foreach ($asks as $ask) {
                // how much of the ask should we use to fill the bid order
                $use=0;
                $remaining = $ask['quantity']-$ask['quantity_done'];
                if ($remaining>$val) {
                    $use=$val;
                } else {
                    $use=$ask['quantity']-$ask['quantity_done'];
                }
                $order_value = bcmul($use,$ask['price'],8);
                $val-=$use;
                $db->run("UPDATE assets_market SET quantity_done=quantity_done+:done WHERE id=:id", [":id"=>$ask['id'], ":done"=>$use]);
                $db->run("UPDATE assets_market SET quantity_done=quantity_done+:done WHERE id=:id", [":id"=>$x['id'], ":done"=>$use]);

                $db->run("INSERT into assets_balance SET account=:account, asset=:asset, balance=:balance ON DUPLICATE KEY UPDATE balance=balance+:balance2", [":account"=>$x['account'], ":asset"=>$x['asset'], ":balance"=>$use, ":balance2"=>$use]);
                $jnga=$use*$x['price'];
                
                //the bidder offered more than the asker demanded, refund difference
                if($x['price'] > $ask['price'])
                {
                    $remainder = $jnga - ($use * $ask['price']);
                    $jnga = $jnga - $remainder;
                    _log("Bid price $x[price] Ask price $ask[price]", 1);
                    _log("Refunding remaining bid order value of $remainder to $x[account] use $use rema $remainder", 1);
                    $refund = $db->run("UPDATE accounts SET balance=balance+:balance WHERE id=:id", [":balance"=>$remainder, ":id"=>$x['account']]);
                    _log("Refund bool $refund", 3);
                    $b3 = new BLAKE3();	
                    $marketrefund = "MarketRefund";
                    $random = $b3->hash($x['id'].$ask['id'].$remainder.$marketrefund.$hash,'64'); 
                    $new = [
                        "id"         => $random,
                        "public_key" => $x['id'],
                        "dst"        => $x['account'],
                        "val"        => $remainder,
                        "fee"        => 0,
                        "signature"  => $signature,
                        "version"    => 58,
                        "date"       => $date,
                        "message"    => "Refund $remainder to $x[account]"
                    ];
                                    
                    $res=$trx->add($hash, $height, $new);
                    if (!$res) {
                        return false;
                    }
                }
                
                //payout royalties!
                $royalties_paid = 0;
                $assetid = $x['asset'];
                $royals = $db->row("SELECT royalties FROM assets WHERE id='$assetid'");
                if($royals)
                {
                    $roy = $royals['royalties'];
                    $roy = json_decode($roy, true);
                    if(is_array($roy))
                    {
                        foreach($roy as $address => $pct)
                        {
                            $address = preg_replace("/[^a-zA-Z0-9]/", "", $address);
							//add acc if not exist
							$acc = new Account();
							$acc->add_id($address, $hash);
							
                            if(is_numeric($pct))
                            {
                                $royalty_payment = 0;
                                $royalty_payment = bcmul($order_value,($pct / 100),8);
                                $royalty_payment = bcdiv($royalty_payment,1,8);
                                $bcc = bccomp("$royalty_payment", '0.00000001', 8);
                                if($bcc == "1")
                                {
                                    $royalties_paid = $royalties_paid + $royalty_payment;
                                    _log("Processing $pct percent royalties for $address payment amount $royalty_payment", 1);
                                    $rez = $db->run("UPDATE accounts SET balance=balance+:val WHERE id=:id", [":val" => $royalty_payment, ":id" => $address]);
                                    if($rez)
                                    {
                                        _log("Added $royalty_payment to account $address $rez", 3);
                                        $b3 = new BLAKE3();
                                        $royaltypay = "RoyaltyPayment";
                                        $random = $b3->hash($x['id'].$ask['id'].$royalty_payment.$royaltypay.$hash,'64');
                                        _log("V59 ID PARTS - $x[id]-$ask[id]-$royalty_payment-$royaltypay-$hash", 1);
                                        $new = [
                                                "id"         => $random,
                                                "public_key" => $x['id'],
                                                "dst"        => $address,
                                                "val"        => $royalty_payment,
                                                "fee"        => 0,
                                                "signature"  => $signature,
                                                "version"    => 59,
                                                "date"       => $date,
                                                "src"		 => $ask['id'],
                                                "message"    => "$pct percent royalties for $address payment amount $royalty_payment"
                                            ];
                                        _log(json_encode($new), 1);	
                                        $res=$trx->add($hash, $height, $new);
                                        if (!$res) {
                                            return false;
                                        }
                                    }
                                    else
                                    {
                                        _log("Unable to add $royalty_payment to account $address -  account does not exist", 1);
                                    }
                                }
                                else
                                {
                                    _log("Unable to add $royalty_payment to account $address -  royalty payment less than 0.00000001", 1);
                                }
                            }
                        }
                    }
                    $order_value = $order_value - $royalties_paid;
                }
                else
                {
                    _log("Unable to get royalty data for asset $asset", 1);
                }
                

                
                $db->run("UPDATE accounts SET balance=balance+:balance WHERE id=:id", [":balance"=>$order_value, ":id"=>$ask['account']]);

                $b3 = new BLAKE3();	
                $random = $b3->hash($x['id'].$ask['id'].$val.$hash,'64'); 
                $new = [
                        "id"         => $random,
                        "public_key" => $x['id'],
                        "dst"        => $ask['account'],
                        "val"        => $order_value,
                        "fee"        => 0,
                        "signature"  => $signature,
                        "version"    => 58,
                        "date"       => $date,
                        "message"    => "$jnga proceeds from market order $ask[id] matched to $x[id]"
                    ];
                    
                $res=$trx->add($hash, $height, $new);
                if (!$res) {
                    return false;
                }
                if ($val<=0) {
                    break;
                }
            }
        }


        $st=$db->run("UPDATE assets_market SET status = 1 WHERE quantity = quantity_done AND status = 0");
        return true;
    }
    
    /*
    * Hard forks the chain
    */
    public function do_hard_forks($height, $block)
    {
        global $db;
    }

    /*
    * returns the current block, without the transactions
    */
    public function current()
    {
        global $db;
        $current = $db->row("SELECT * FROM blocks ORDER by height DESC LIMIT 1");
        if (!$current) {
            $this->genesis();
            return $this->current(true);
        }
        return $current;
    }

    /*
    * returns the previous block
    */
    public function prev()
    {
        global $db;
        $current = $db->row("SELECT * FROM blocks ORDER by height DESC LIMIT 1,1");

        return $current;
    }

    /* @Daru
    * calculates the difficulty
    */
    public function difficulty($height = 0)
    {
        global $db, $_config;

        // if no block height is specified, use the current block.
        if ($height == 0) {
            $current = $this->current();
        } else {
            $current = $this->get($height);
        }
        
        $height = $current['height'];

        if ($height>1) {
            $blks=0;
            $total_time=0;
            if ($height > 120) {
                $lim = 120;
            } else {
                $lim = $height-1;
            }
            $blk = $db->run("SELECT `date`, height FROM blocks ORDER by height DESC LIMIT $lim", [":limit"=>$lim]);
			$i = 0;
			while ($i<$height && $i<$lim-1) {
                $time=$blk[$i]['date']-$blk[$i+1]['date'];
                $i += 1;
                $blks += 1 / ($i); //decreasing emphasis on historical values
                $total_time+=$time / ($i);
            }
            $result=ceil($total_time/$blks);

            _log("Block time: $result", 4);
            _log("Current Diff: $current[difficulty]", 4);
            $dif = $current['difficulty'];

            $max_target = bchexdec('0x8000000000000000000000000000000000000000000000000000000000000000');
            
            $p_term_coeff_unscaled = 0.33; // keep between 0 and 1, NON-INCLUSIVE. Higher numbers make the system more sensitive.
            _log("p term coeff unscaled $p_term_coeff_unscaled", 4);
            $p_term_coeff = $p_term_coeff_unscaled / $_config['target_blocktime']; // scale to keep stable 
            _log("p term coeff 			$p_term_coeff", 4);
            $p_term = $p_term_coeff * ($_config['target_blocktime'] - $result); // Proportional term
            _log("p term 				$p_term", 4);
            $p_term_str = sprintf("%.4f", $p_term);
            _log("p term str 			$p_term_str", 4);
            $current_target = bcsub($max_target,$current['difficulty']);
            _log("Maxtarget 			$max_target", 4);
            _log("current target  		$current_target", 4);
            $diff_change = bcfloor(bcmul($current_target, $p_term_str, 4));
            _log("diff_change 				$diff_change", 4);
            $dif = bcadd($current['difficulty'],$diff_change);
            _log("New Diff: 			$dif", 4);
        } else {
            return $current['difficulty'];
        }

        
        //minimum & maximum check
        if (bccomp($dif,'1') < 0) {
            $dif = '1';
        } elseif (bccomp($dif,bcsub($max_target,'1')) > 0) {
            $dif = bcsub($max_target,1);
        }

        $ratio_check = bcdiv(bcsub($max_target,$current['difficulty']),bcsub($max_target,$dif),5);
        _log("Ratio of old target to new target: $ratio_check", 4);
        
        _log("Difficulty: $dif", 4);
        return $dif;
    }

    /*
    * calculates the maximum block size and increase by 10% the number of transactions if > 1000 on the last 100 blocks
    */
    public function max_transactions()
    {
        global $db;
        $current = $this->current();
        $limit = $current['height'] - 100;
        $avg = $db->single("SELECT AVG(transactions) FROM blocks WHERE height>:limit", [":limit" => $limit]);
        if ($avg < 1000) {
            _log("$avg average transactions over last 100 blocks - Setting max transactions back to 1000", 3);
            return 1000;
        }
        $new_max = ceil($avg * 1.1);
        _log("$avg average transactions over last 1000 blocks - Increasing max transactions - New max $new_max", 3);
        return $new_max;
    }

    // calculate the reward for each block
    public function reward($id, $data = [])
    {	
        $start_rew = microtime(true);
        global $db;
        if($id == 1) {
            _log("REWARD FUNCTION ID:  $id");
            $reward['total'] = '10000000.00000000';
            _log("REWARD FUNCTION GENESIS REWARD:  $reward[total]");
            return $reward;
        }
        //calculate utility over the last day based on asset and market related transaction amounts and fee amounts
        $current = $this->current();
        $height = $current['height'];
        //$current = json_decode($current);
        
        if ($id > 1) {
            if($height < 2882) {
                if($height > 0) {
                    $limit = 0;
                    $divisor = $height;
                } elseif($height==0) {
                    $limit = 0;
                    $divisor = 1;
                }
            } else {
                $limit = $height - 2880;
                $divisor = 2880;
            }
            $currentheight = $height+1;
            _log("current height: $currentheight", 3);
            _log("Divisor: $divisor", 3);
    
    
            //1. get all the fees from the last average blocks per day (2880)
            $chain_metrics = $db->row("SELECT * FROM chain_metrics WHERE id=:id", [":id"=>1]);
            
            $supply = $chain_metrics['total_supply'];
            _log("Total supply from chain_metrics? $supply");
    
            
            $total_rew = microtime(true) - $start_rew; 
            _log("Time took to run sql queries? $total_rew seconds");
            
            $totalfees = number_format($chain_metrics['day_fees'], 8, '.', '');
            _log("Total Fees: $totalfees", 3);
            
            //total market related fees
            $utilityfee = number_format($chain_metrics['day_marketplace_fees'], 8, '.', '');
            _log("Utility (Mktplace fees): $utilityfee in $divisor blocks", 3);
            
            //average fees per block over 1 day, set floor as 1 sat
            $averagefees = bcdiv($totalfees, $divisor, 8);
    
            if($averagefees < .00000001){
                $averagefees = number_format(.00000001, 8, '.', '');
            }
            
            _log("Total Fees Averaged: $averagefees per block over $divisor blocks", 3);
            
           //utility percentage is the percentage of the average asset and market related fees of the total fees averaged over the blocks from the last day
           if ($utilityfee != 0) {
               _log("Scenario A: There were marketplace fees in the last $divisor blocks.", 3);
               $utility = bcdiv(bcdiv($utilityfee, $divisor, 8), $averagefees, 8);
               _log("Utility (calculated): $utility", 3);
           }
           if ($utilityfee == 0) {
               _log("Scenario B: There were NO marketplace fees in the last $divisor blocks.", 3);
               $utility = .0001;
               _log("Utility (imputed): $utility", 3);
           }
            
            
            //when less than 10,000,000 jnga exist, make supply higher to help with initial distribution.
            if($supply < 10000000) {
                $supply = 10000000;
            }
            _log("Supply: $supply", 3);
            
            //get last block reward amount
            $current = $current;
            //don't use genesis reward as a base
            if($height>1){
                $lastreward = $db->single("SELECT val FROM transactions WHERE version=:version AND height=:height", [":version" => '0', ":height" => $lastblk]);
                //get last block fees
                $lastblock = $db->row("SELECT * FROM blocks WHERE height=:height", [":height" => $lastblk]);
                $lastfees = bcsub($lastblock['fees'], $lastblock['fees_burned'], 8);
                //subtract last block fees from block reward to find base reward of last block
                $lastblockbase = bcsub($lastreward, $lastfees, 8);
                _log("Last Block: $lastblk, Last Block Reward: $lastreward, Last Block Fees: $lastfees, Last Block Base: $lastblockbase", 3);
                //determine if last block reward base is equal to or above desired growth percentage and set base for current block
/*                 $econbase = bcmul(bcdiv(".08", "1051200", 8), $supply, 8);
                $minbase = bcmul(bcdiv(".001", "1051200", 8), $supply, 8);
                if(bccomp($lastblockbase, $minbase) >= 0) { */
                $econbase = bcmul(bcdiv(".08", "1051200", 8), $supply, 8);
                $minbase = bcmul(bcdiv(".001", "1051200", 8), $supply, 8);
                if($lastblockbase >= $minbase) {
                    $currentbase = $lastblockbase;
                    _log("Last Block Base ($lastblockbase) >= Min Base (.1%/yr): $minbase (Econ Base (8%/yr): $econbase)", 3);
                } else {
                    $currentbase = $minbase;
                    _log("Econ Base Would Have Been: $econbase | Testing with Min Base Base: $minbase", 3);
                }  
            } else {
                $econbase = bcmul(bcdiv(".08", "1051200", 8), $supply, 8);
                $currentbase = $econbase;
            }
            
            // calculate the transaction fees in this block
            $fees = 0;
            if (count($data) > 0) {
                foreach ($data as $x) {
                    $fees = bcadd($fees, $x['fee'], 8);
                }
                _log("This block has Fees: $fees", 3);
            } else {
                _log("This block has NO fees: $fees", 3);
            }
    
            //if asset and market related fees are less than .1% of total fees when averaged over the day, reduce the block reward by .1%
            $burnt = 0;
            if($utility < .001) {
                $utility = .0001;
                $rewardc = bcmul(bcsub("1", $utility, 8), $currentbase, 8);
                if($fees > 0) {
                    $feesc = bcmul(bcsub("1", $utility, 8), $fees, 8);
                    if($feesc <= 0.00000001) {
                        _log("$burnt fees are burnt are burnt due to very low utility: original fees:$fees", 3);
                        $burnt = $fees;
                    } else {
                        $burnt = bcsub($fees, $feesc, 8);
                        _log("$burnt fees are burnt are burnt due to low utility: original fees:$fees ( remaining fees: $feesc)", 3);
                    }
                }
                
                _log("Reduce Base Reward by: -0.01%", 3);
                _log("Current Base: $currentbase - 0.01% is $rewardc", 3);
            } elseif($utility > .01) {
            //if asset and market related fees are more than 1% of total fees when averaged over the day, increase the block reward by .1%
                $utility = .0001;
                $rewardc = bcmul(bcadd("1", $utility, 8), $currentbase, 8);
                _log("Increase Base Reward: +0.01%", 3);
                _log("Current Base: $currentbase + 0.01% is $rewardc", 3);
                
            } else {
            //if asset and market related fees are more than .1%  but less than 1% of total fees when averaged over the day, leave the reward the same
                $rewardc = number_format($currentbase, 8, '.', '');
                _log("Utility was > .1% but less than 1%: NO CHANGE. $currentbase equals $rewardc", 3);
            }
            
            $reward = $rewardc;
            
            if ($reward <= 0) {
                $reward = $econbase;
                _log("Calculated reward was $rewardc, =< 0: Econbase: $econbase is used", 3);
            }
            
            $reward = [
                "reward"    =>  number_format($reward, 8, '.', ''),
                "fees"      =>  number_format($fees, 8, '.', ''),
                "burnt"     =>  number_format($burnt, 8, '.', ''),
                "total"     =>  bcsub(bcadd($reward, $fees, 8), $burnt, 8)
            ];
            
            $totalreward = ($reward['total']);
            _log("Total Reward: $totalreward", 3);
            
            //
            $total_rew2 = microtime(true) - $start_rew; 
            _log("Total time to calculate rewards? $total_rew2 seconds");
        }

        return $reward;
    
    }

    /*
    * calculate the reward for each block
    */
/*
    public function reward($id, $data = [])
    {
        global $_config;
        if ($id <= $_config['total_reward_blocks']) {
            $reward = $_config['block_reward'];
        } else {
            $reward = 0;
        }
        
        // calculate the transaction fees
        $fees = 0;
        if (count($data) > 0) {
            foreach ($data as $x) {
                $fees += $x['fee'];
            }
        }
        //return number_format($reward + $fees, 8, '.', '');
        $burnt  = 0;
        $reward = [
            "reward"    =>  number_format($reward, 8, '.', ''),
            "fees"      =>  number_format($fees, 8, '.', ''),
            "burnt"     =>  number_format($burnt, 8, '.', ''),
            "total"     =>  bcsub(bcadd($reward, $fees, 8), $burnt, 8)
        ];
        return $reward;
    }
*/

    /*
    * checks the validity of a block
    */
    public function check($data)
    {
        // blakehash must have at least 20 chars
        if (strlen($data['blakehash']) < 20) {
            _log("Invalid block blakehash - $data[blakehash]");
            return false;
        }
        $acc = new Account();

        if ($data['date']>time()+30) {
            _log("Future block - $data[date] $data[public_key]", 2);
            return false;
        }
        
        // generator's public key must be valid
        if (!$acc->valid_key($data['public_key'])) {
            _log("Invalid public key - $data[public_key]");
            return false;
        }

        //difficulty should be the same as our calculation
        if ($data['difficulty'] != $this->difficulty()) {
            _log("Invalid difficulty - $data[difficulty] - ".$this->difficulty());
            return false;
        }

        //check the blakehash hash and the nonce to produce a valid block
        if (!$this->mine($data['public_key'], $data['nonce'], $data['blakehash'], $data['difficulty'], 0, 0, $data['date'])) {
            _log("Mine check failed");
            return false;
        }

        return true;
    }

    /*
    * creates a new block on this node
    */
    public function forge($nonce, $blakehash, $public_key, $private_key)
    {
        global $db;
        //check the blakehash and the nonce to produce a valid block
        if (!$this->mine($public_key, $nonce, $blakehash)) {
            _log("Forge failed - Invalid blakehash");
            return false;
        }

        // the block's date timestamp must be bigger than the last block
        $current = $this->current();
        $height = $current['height'] += 1;
        $date = time();
        if ($date <= $current['date']) {
            _log("Forge failed - Date older than last block");
            return false;
        }

        // get the mempool transactions
        $txn = new Transaction();
        $data = $txn->mempool($this->max_transactions());

        $difficulty = $this->difficulty();
        $acc = new Account();
        $generator = $acc->get_address($public_key);

        // always sort  the transactions in the same way
        ksort($data);

        // sign the block
        $signature = $this->sign($generator, $height, $date, $nonce, $data, $private_key, $difficulty, $blakehash);
        // reward transaction and signature

        $reward = $this->reward($height, $data);
        $reward = $reward['total'];

        $msg = '';
        $transaction = [
            "src"        => $generator,
            "dst"        => $generator,
            "val"        => $reward,
            "version"    => 0,
            "date"       => $date,
            "message"    => $msg,
            "fee"        => "0.00000000",
            "public_key" => $public_key,
        ];
        ksort($transaction);
        $reward_signature = $txn->sign($transaction, $private_key);

        // add the block to the blockchain
        $res = $this->add(
            $height,
            $public_key,
            $nonce,
            $data,
            $date,
            $signature,
            $difficulty,
            $reward_signature,
            $blakehash
        );
        if (!$res) {
            _log("Forge failed - Block->Add() failed");
            return false;
        }
        return true;
    }

    /*
    * check if the arguments are good for mining a specific block
    */
    public function mine($public_key, $nonce, $blakehash, $difficulty = 0, $current_id = 0, $current_height = 0, $time=0)
    {
        global $_config;
   
        // invalid future blocks
        if ($time>time()+30) {
            return false;
        }

        // if no id is specified, we use the current
        if ($current_id === 0 || $current_height === 0) {
            $current = $this->current();
            $current_id = $current['id'];
            $current_height = $current['height'];
        }
        _log("Nonce $nonce", 3);
        _log("Current Block id $current_id", 3);
        _log("Block Timestamp $time", 3);
        if ($time == 0) {
            $time=time();
        }
        // get the current difficulty if empty
        if ($difficulty === 0) {
            $difficulty = $this->difficulty();
        }
        _log("Difficulty: $difficulty", 3);
        if (empty($public_key)) {
            _log("Empty public key", 3);
            return false;
        }
        
        // blake mining
        _log("Blake3 Mining - $current_height", 3);
        
        // the hash base for blakehash
        $base = "$public_key-$nonce-".$current_id."-$difficulty";
        _log("Base $base", 3);
        
        $b3 = new BLAKE3();	
        $chain_hash = $b3->hash($base,'64');
        if($chain_hash !== $blakehash)
        {
            _log("Chain doesnt match miner: Chain_hash: $chain_hash Miner_hash: $blakehash", 3);
            return false;
        }
        _log("Chain_hash: $chain_hash Miner_hash: $blakehash", 3);

        // all nonces are valid in testnet
        if ($_config['testnet'] == true) {
            return true;
        }

        // prepare the base for the hashing
        $hash = $base.$blakehash;
        _log("Base $base", 3);
        _log("Blakehash $blakehash", 3);

        // hash the base 8 times
        for ($i = 0; $i < 7; $i++) {
            $b3 = new BLAKE3();
            $hash = $b3->hash($hash,'64','bin');
        }

        $b3 = new BLAKE3();
        $result = $b3->hash($hash,32,'int'); //digest to 32 bytes
        $target = bcsub(bchexdec('0x8000000000000000000000000000000000000000000000000000000000000000'), $difficulty);
        _log("Target $target", 3);
        
        if (bccomp($result, $target) <= 0) {
            _log("Difficulty $difficulty", 3);
            _log("Result $result", 3);
            return true;
        }
        _log("Mining target $target difficulty $difficulty result $result", 2);
        return false;
    }

    /*
    * parse the block transactions
    */
    public function parse_block($block, $height, $data, $test = true, $bootstrapping=false)
    {
        global $db;
        // data must be array
        if ($data === false) {
            _log("Block data is false", 3);
            return false;
        }
        $acc = new Account();
        $trx = new Transaction();
        // no transactions means all are valid
        if (count($data) == 0) {
            return true;
        }

        // check if the number of transactions is not bigger than current block size
        $max = $this->max_transactions();
        if (count($data) > $max) {
            _log("Too many transactions in block", 3);
            return false;
        }

        $balance = [];

        foreach ($data as &$x) {
            // get the sender's account if empty
            if (empty($x['src'])) {
                $x['src'] = $acc->get_address($x['public_key']);
            }
            if (!$bootstrapping) {
                //validate the transaction
                $txd = $trx->check($x, $height);
                if (!$txd->status) {
                    _log("Transaction check failed - $x[id] $txd->error ", 3);
                    return false;
                }

                // prepare total balance
                if(!isset($balance["$x[src]"]))
                {
                    $balance["$x[src]"] = 0;
                }
                $balance["$x[src]"] += $x['val'] + $x['fee'];
                // check if the transaction is already on the blockchain
                if ($db->single("SELECT COUNT(1) FROM transactions WHERE id=:id", [":id" => $x['id']]) > 0) {
                    _log("Transaction already on the blockchain - $x[id]", 3);
                    return false;
                }
            }
        }

        if (!$bootstrapping) {
            // check if the account has enough balance to perform the transaction
            foreach ($balance as $id => $bal) {
                $res = $db->single(
                    "SELECT COUNT(1) FROM accounts WHERE id=:id AND balance>=:balance",
                    [":id" => $id, ":balance" => $bal]
                );
                if ($res == 0) {
                    _log("Not enough balance for transaction - $id", 3);
                    return false; // not enough balance for the transactions
                }
            }
        }
        // if the test argument is false, add the transactions to the blockchain
        if ($test == false) {
            foreach ($data as $d) {
                $res = $trx->add($block, $height, $d);
                if ($res == false) {
                    return false;
                }
            }
        }

        return true;
    }

    /*
    * add the genesis block
    */
    private function genesis()
    {
        global $db;
        global $_config;
        $signature = $_config['signature'];
        $public_key = $_config['genesis_public_key'];
        $reward_signature = $_config['reward_signature'];
        $blakehash = $_config['blakehash'];

        $difficulty = $_config['difficulty'];
        $height = 1;
        $data = [];
        $date = $_config['date'];
        $nonce = $_config['nonce'];


        $res = $this->add(
            $height,
            $public_key,
            $nonce,
            $data,
            $date,
            $signature,
            $difficulty,
            $reward_signature,
            $blakehash
        );
        if (!$res) {
            api_err("Could not add the genesis block.");
        }
    }

    /*
    * delete last X blocks
    */
    public function pop($no = 1)
    {
        $current = $this->current();
        return $this->delete($current['height'] - $no + 1);
    }

    /*
    * delete all blocks >= height
    */
    public function delete($height)
    {
        global $_config;
        if ($height < 2) {
            $height = 2;
        }
        global $db;
        $trx = new Transaction();

        $r = $db->run("SELECT * FROM blocks WHERE height>=:height ORDER by height DESC", [":height" => $height]);

        if (count($r) == 0) {
            return true;
        }
        $db->beginTransaction();
        $db->exec("LOCK TABLES blocks WRITE, accounts WRITE, transactions WRITE, mempool WRITE, peers write, config WRITE, assets WRITE, assets_balance WRITE, assets_market WRITE");

        foreach ($r as $x) {
            $res = $trx->reverse($x['id']);
            if ($res === false) {
                _log("A transaction could not be reversed. Delete block failed.");
                $db->rollback();
                // the blockchain has some flaw, we should resync from scratch
           
                $current = $this->current();
                if (($current['date']<time()-(3600*48)) && $_config['auto_resync']!==false) {
                    _log("Blockchain corrupted. Resyncing from scratch.");
                    $db->run("SET foreign_key_checks=0;");
                    $tables = ["accounts", "transactions", "mempool","blocks"];
                    foreach ($tables as $table) {
                        $db->run("TRUNCATE TABLE {$table}");
                    }
                    $db->run("SET foreign_key_checks=1;");
                    $db->exec("UNLOCK TABLES");
                            
              
                    $db->run("UPDATE config SET val=0 WHERE cfg='sanity_sync'");
                    @unlink(SANITY_LOCK_PATH);
                    system("php utils/sanity.php  > /dev/null 2>&1  &");
                    exit;
                }
                $db->exec("UNLOCK TABLES");
                return false;
            }
            $res = $db->run("DELETE FROM blocks WHERE id=:id", [":id" => $x['id']]);
            if ($res != 1) {
                _log("Delete block failed.");
                $db->rollback();
                $db->exec("UNLOCK TABLES");
                return false;
            }
            
            //pool payment reversal code. May be broken
            /*$res = $db->run("DELETE * FROM pool_payments WHERE height=:height", [":height" => $x['height']]);
            if ($res != 1) {
                _log("Delete payment failed.");
                $db->rollback();
                $db->exec("UNLOCK TABLES");
                return false;
            }*/
        }

      

        $db->commit();
        $db->exec("UNLOCK TABLES");
        return true;
    }

    /*
    * delete specific block
    */
    public function delete_id($id)
    {
        global $db;
        $trx = new Transaction();

        $x = $db->row("SELECT * FROM blocks WHERE id=:id", [":id" => $id]);

        if ($x === false) {
            return false;
        }
        // avoid race conditions on blockchain manipulations
        $db->beginTransaction();
        $db->exec("LOCK TABLES blocks WRITE, accounts WRITE, transactions WRITE, mempool WRITE, peers write, config WRITE, assets WRITE, assets_balance WRITE, assets_market WRITE");

        // reverse all transactions of the block
        $res = $trx->reverse($x['id']);
        if ($res === false) {
            // rollback if you can't reverse the transactions
            $db->rollback();
            $db->exec("UNLOCK TABLES");
            return false;
        }
        // remove the actual block
        $res = $db->run("DELETE FROM blocks WHERE id=:id", [":id" => $x['id']]);
        if ($res != 1) {
            //rollback if you can't delete the block
            $db->rollback();
            $db->exec("UNLOCK TABLES");
            return false;
        }
        
        //pool payment reversal code. May be broken
            /*$res = $db->run("DELETE * FROM pool_payments WHERE height=:height", [":height" => $x['height']]);
            if ($res != 1) {
                _log("Delete payment failed.");
                $db->rollback();
                $db->exec("UNLOCK TABLES");
                return false;
            }*/
        
        // commit and release if all good
        $db->commit();
        $db->exec("UNLOCK TABLES");
        return true;
    }

    /*
    * sign a new block, used when mining
    */
    public function sign($generator, $height, $date, $nonce, $data, $key, $difficulty, $blakehash)
    {
        $json = json_encode($data);
        $info = "{$generator}-{$height}-{$date}-{$nonce}-{$json}-{$difficulty}-{$blakehash}";

        $signature = ec_sign($info, $key);
        return $signature;
    }

    // generate the blake hash of the block data and convert it to base58
    public function hash($public_key, $height, $date, $nonce, $data, $signature, $difficulty, $blakehash)
    {
        $json = json_encode($data);
        $b3 = new BLAKE3();	
        $hash = $b3->hash("{$public_key}-{$height}-{$date}-{$nonce}-{$json}-{$signature}-{$difficulty}-{$blakehash}",'64');
        return hex2coin($hash);
    }

    // exports the block data, to be used when submitting to other peers
    public function export($id = "", $height = "")
    {
        if (empty($id) && empty($height)) {
            return false;
        }

        global $db;
        $trx = new Transaction();
        if (!empty($height)) {
            $block = $db->row("SELECT * FROM blocks WHERE height=:height", [":height" => $height]);
        } else {
            $block = $db->row("SELECT * FROM blocks WHERE id=:id", [":id" => $id]);
        }

        if (!$block) {
            return false;
        }
        $r = $db->run("SELECT * FROM transactions WHERE version>0 AND block=:block", [":block" => $block['id']]);
        $transactions = [];
        foreach ($r as $x) {
			//wtf someone removed this?
			if ($x['version']==58||$x['version']==59) {
                //internal transactions are not exported
                continue;
            }
			//
            $trans = [
                "id"         => $x['id'],
                "dst"        => $x['dst'],
                "val"        => $x['val'],
                "fee"        => $x['fee'],
                "signature"  => $x['signature'],
                "message"    => $x['message'],
                "version"    => $x['version'],
                "date"       => $x['date'],
                "public_key" => $x['public_key'],
            ];
            ksort($trans);
            $transactions[$x['id']] = $trans;
        }
        ksort($transactions);
        $block['data'] = $transactions;

        // the reward transaction always has version 0
        $gen = $db->row(
            "SELECT public_key, signature FROM transactions WHERE version=0 AND block=:block",
            [":block" => $block['id']]
        );
        if(is_array($block))
        {
            $block['public_key'] = $gen['public_key'];
            $block['reward_signature'] = $gen['signature'];
        }
        return $block;
    }

    //return a specific block as array
    public function get($height)
    {
        global $db;
        if (empty($height)) {
            return false;
        }
        $block = $db->row("SELECT * FROM blocks WHERE height=:height", [":height" => $height]);
        return $block;
    }
    public function getBlock($block_id)
    {
        global $db;
        if (empty($block_id)) {
            return false;
        }
        $block = $db->row("SELECT * FROM blocks WHERE id=:id", [":id" => $block_id]);
        return $block;
    }
}
