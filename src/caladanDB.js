// Copyright 2023 
// This file is part of Caladan DAO Analytics

const ini = require('node-ini');

const {
    Bigtable
} = require("@google-cloud/bigtable");
const {
    BigQuery
} = require('@google-cloud/bigquery');
const {
    Storage
} = require('@google-cloud/storage');

const mysql = require("mysql2");
const util = require('util');
const exec = util.promisify(require('child_process').exec);
const path = require('path');
const fs = require('fs');
const os = require("os");

module.exports = class CaladanDB {
    GC_PROJECT = "";
    GC_BIGTABLE_INSTANCE = "";
    GC_BIGTABLE_CLUSTER = "";
    GC_STORAGE_BUCKET = "";

    CALADAN_EMAIL_USER = "";
    CALADAN_EMAIL_PASSWORD = "";


    bigQuery = null;
    googleStorage = null;
    bqTablesCallsEvents = null;

    showMemoryUsage(ctx = "") {
        const used = process.memoryUsage().heapUsed / 1024 / 1024;
        console.log(`${ctx} USED: [${used}MB]`)
    }

    constructor(serviceName = "analytics") {
        this.hostname = os.hostname();
        this.version = `1.0.0` // we will update this manually

        // 1. ready db config for WRITABLE mysql pool [always in US presently] using env variable POLKAHOLIC_DB
        let dbconfigFilename = (process.env.CALADAN_DB != undefined) ? process.env.CALADAN_DB : '/root/.mysql/.db00.cnf';
        try {
	    console.log("process.env.GOOGLE_APPLICATION_CREDENTIALS ", process.env.GOOGLE_APPLICATION_CREDENTIALS);
            let dbconfig = ini.parseSync(dbconfigFilename);
            if (dbconfig.email != undefined) {
                this.POLKAHOLIC_EMAIL_USER = dbconfig.email.email;
                this.POLKAHOLIC_EMAIL_PASSWORD = dbconfig.email.password;
            }
            if (dbconfig.gc != undefined) {
                this.GC_PROJECT = dbconfig.gc.projectName;
                this.GC_BIGTABLE_INSTANCE = dbconfig.gc.bigtableInstance;
                this.GC_BIGTABLE_CLUSTER = dbconfig.gc.bigtableCluster;
                this.GC_STORAGE_BUCKET = dbconfig.gc.storageBucket;
            }
            if (dbconfig.bq != undefined) {
                if (dbconfig.bq.substrateetlKey) {
		    this.BQ_KEY = dbconfig.bq.substrateetlKey;
		}
            }

            if (dbconfig.externalapis != undefined) {
                if (dbconfig.externalapis) {
                    this.EXTERNAL_APIKEYS = dbconfig.externalapis;
                }
            }

            this.pool = mysql.createPool(this.convert_dbconfig(dbconfig.client));
            // Ping WRITABLE database to check for common exception errors.
            this.pool.getConnection((err, connection) => {
                if (err) {
                    if (err.code === 'PROTOCOL_CONNECTION_LOST') {
                        console.error('Database connection was closed.')
                    }
                    if (err.code === 'ER_CON_COUNT_ERROR') {
                        console.error('Database has too many connections.')
                    }
                    if (err.code === 'ECONNREFUSED') {
                        console.error('Database connection was refused.')
                    }
                }

                if (connection) {
                    this.connection = connection;
                    connection.release()
                }
                return
            })
            // Promisify for Node.js async/await.
            this.pool.query = util.promisify(this.pool.query).bind(this.pool)
            this.pool.end = util.promisify(this.pool.end).bind(this.pool)
        } catch (err) {
            console.log(err);
            this.logger.fatal({
                "op": "dbconfig",
                err
            });
        }

        // 2. ready db config for READONLY mysql pool [default US replica but could be EU/AS replica] using env variable CALADAN_DB_REPLICA
        let dbconfigReplicaFilename = (process.env.CALADAN_DB_REPLICA != undefined) ? process.env.CALADAN_DB_REPLICA : '/root/.mysql/.db00-us-indexer.cnf';
        try {
            let dbconfigREADONLY = ini.parseSync(dbconfigReplicaFilename);
            this.poolREADONLY = mysql.createPool(this.convert_dbconfig(dbconfigREADONLY.client));
            // Ping READONLY database to check for common exception errors.
            this.poolREADONLY.getConnection((err, connection) => {
                if (err) {
                    if (err.code === 'PROTOCOL_CONNECTION_LOST') {
                        console.error('Database connection was closed.')
                    }
                    if (err.code === 'ER_CON_COUNT_ERROR') {
                        console.error('Database has too many connections.')
                    }
                    if (err.code === 'ECONNREFUSED') {
                        console.error('Database connection was refused.')
                    }
                }

                if (connection) {
                    this.connectionREADONLY = connection;
                    connection.release()
                }
                return
            })
            // Promisify for Node.js async/await.
            this.poolREADONLY.query = util.promisify(this.poolREADONLY.query).bind(this.poolREADONLY)
            this.poolREADONLY.end = util.promisify(this.poolREADONLY.end).bind(this.poolREADONLY)
        } catch (err) {
            console.log(err);
        }
        const bigtable = new Bigtable({
            projectId: this.GC_PROJECT
        });
        const instanceName = this.GC_BIGTABLE_INSTANCE;
        this.instance = bigtable.instance(instanceName);
        this.btAccountRealtime = this.instance.table("accountrealtime");
    }

    convert_dbconfig(c) {
        return {
            host: c.host,
            user: c.user,
            password: c.password,
            database: c.database,
            charset: c['default-character-set']
        };
    }

    get_big_query() {
        if (this.bigQuery) return this.bigQuery;
        this.bigQuery = new BigQuery({
            projectId: this.GC_PROJECT
        })
	console.log("BigQuery configured")
        return this.bigQuery;
    }

    async execute_bqJob(sqlQuery, targetBQLocation = null) {
        // run bigquery job with suitable credentials
        const bigqueryClient = this.get_big_query();
        const options = {
            query: sqlQuery,
            location: (targetBQLocation) ? targetBQLocation : this.defaultBQLocation,
        };

        try {
            const response = await bigqueryClient.createQueryJob(options);
            const job = response[0];
            const [rows] = await job.getQueryResults();
            return rows;
        } catch (err) {
            console.log(err);
            throw new Error(`An error has occurred.`, sqlQuery);
        }
        return [];
    }

    
}
