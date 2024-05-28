const mysql = require('mysql');

exports.handler = async (event) => {
    const connection = mysql.createConnection({
        host: "education.czsciauswuyt.us-east-1.rds.amazonaws.com",
        user: "edu",
        password: "hashicorp",
        database: "education"
    });

    return new Promise((resolve, reject) => {
        connection.connect((err) => {
            if (err) {
                reject({
                    statusCode: 500,
                    body: `ERROR: Could not connect to MySQL instance. ${err}`
                });
                return;
            }
            connection.query('SELECT NOW()', (error, results) => {
                if (error) {
                    reject({
                        statusCode: 500,
                        body: `ERROR: Could not execute query. ${error}`
                    });
                } else {
                    resolve({
                        statusCode: 200,
                        body: `Successfully connected to RDS instance. Current time: ${results[0]['NOW()']}`
                    });
                }
                connection.end();
            });
        });
    });
};