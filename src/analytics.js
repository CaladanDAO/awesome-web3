#!/usr/bin/env node
const CaladanDB = require("./caladanDB");
const fs = require("fs");
const jsonc = require("jsonc");
const organization = "CaladanDAO";
const projectID = "awesome-web3";
const baseDir = `/root/go/src/github.com/${organization}/${projectID}`

module.exports = class Analytics extends CaladanDB {
    constructor() {
        super("manager")
    }

    async parse(fn = "../defi/uniswap/config.jsonld") {
        const datac = fs.readFileSync(fn, {
            encoding: 'utf8',
            flag: 'r'
        });
        let projects = jsonc.parse(datac);
        const jsonld = require('jsonld');
        const flattened = await jsonld.flatten(projects);
	console.log(JSON.stringify(flattened, null, 4));
    }
    async generatelogs() {
	// mysql test - read chain latest block
	try {
	    let sql = "select chainID, id, blocksCovered from chain where crawling = 1";
	    let chains = await this.poolREADONLY.query(sql)
	    if ( chains.length > 0 ) {
		console.log("mysql test -- # chains: ", chains.length);
		for ( const c of chains ) {
		    console.log(JSON.stringify(c));
		}
	    } else {
		console.log("mysql test FAIL", sql);
	    }
	} catch (err) {
	    console.log("mysql error", err);
	}
	
	// bigquery test
	console.log("CHECK1 BQKey", this.BQ_KEY);
	let blockNumber = null
	let blockTS = null
	try {
            let query = `SELECT _TABLE_SUFFIX as chainID,  count(\`hash\`) numTransactions, UNIX_SECONDS(max(block_timestamp)) blockTS, max(block_number) blockNumber
 FROM \`${projectID}.caladan_evm.transactions*\` WHERE block_timestamp >= DATE_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 HOUR) 
 group by chainID LIMIT 1000;`
            let recs = await this.execute_bqJob(query);
	    if ( recs.length > 0 ) {
		console.log("bigquery test -- # chains: ", recs.length);
		for ( const c of recs ) {
		    console.log(JSON.stringify(c));
		    if ( c.chainID == 1 ) {
			blockNumber = c.blockNumber
			blockTS = c.blockTS
		    }
		}
	    } else {
		console.log("bigquery test FAIL", query);
	    }
	} catch (err) {
	    console.log("bigquery error", err);
	}

	// bigtable test - read wrapped ethereum record from accountrealtime
	try {
	    let rowKeys = ["0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2"];
            const [rows] = await this.btAccountRealtime.getRows({
		keys: rowKeys,
		filter: [{
                    family: ["metadata"],
                    column: {
			cellLimit: 1
		    }
		}]
            });
	    console.log("bigtable test: ", JSON.stringify(rows[0].data, null, 4));
	} catch (err) {
	    console.log("bigtable error", err);
	}

	// google storage test - read latest block of ethereum using above
	try {
	    const date = new Date(blockTS * 1000); // Convert Unix timestamp to milliseconds
	    const year = date.getFullYear();
	    const month = String(date.getMonth() + 1).padStart(2, '0'); // Months are zero-indexed
	    const day = String(date.getDate()).padStart(2, '0');
	    let logDT = `${year}/${month}/${day}`;
	    let filePath = `1/${logDT}/${blockNumber}.json.gz`
	    const {
		Storage
	    } = require('@google-cloud/storage');

	    
	    let storage = new Storage();
	    const bucket = storage.bucket("caladan_evm");
	    const file = bucket.file(filePath);
            const buffer = await file.download();
            const r = JSON.parse(buffer[0]); // block, receipts, evm
	    console.log("gs storage blockNumber", blockNumber, "ts=", blockTS, "blockHash=", r.block.hash, "#Txs=", r.block.transactions.length,  "#Receipts=", r.receipts.length, " #Traces=", r.traces.length);
	} catch (err) {
	     console.log("gs storage error", err);
	}
    }

}
