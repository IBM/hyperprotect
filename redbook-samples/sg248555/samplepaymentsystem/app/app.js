/*##############################################################################
# Copyright 2019 IBM Corp. All Rights Reserved.
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.
##############################################################################*/
var express = require('express');
var fs = require('fs');
var http = require('http');
var https = require('https');
var admzip = require('adm-zip');
var rateLimit = require('express-rate-limit');

var app = express();
const bodyParser = require('body-parser');
var path = require('path');

var transactions = [];

app.use(rateLimit({
    windowMs: 60 * 1000,
    limit: 100,
    standardHeaders: true,
    legacyHeaders: false
}));

// Serve only the files the pages need, not the whole working directory
// (which contains sslcert/, package.json, node_modules/, ...).
['index.html', 'paynow.html', 'style.css', 'paynow.css', 'paynow.js'].forEach(function(file) {
    app.get('/' + file, function(req, res) {
        res.sendFile(path.join(__dirname, file));
    });
});
app.use('/images', express.static(path.join(__dirname, 'images')));
app.use(express.json());

var options = {
    key: fs.readFileSync( 'sslcert/localhost.key', 'utf8' ),
    cert: fs.readFileSync('sslcert/localhost.cert', 'utf8')
};

app.get('/', function(req, res) {
    console.log(path.join(__dirname + '/index.html'));
    res.sendFile(path.join(__dirname + '/index.html'));
});

app.get('/api/v1/attestation', function(req, res) {
    console.log('GET ' + req.path);
    const fileName = 'attestation.zip';
    const fileType = 'application/zip';
    var zip = new admzip();
    try {
        zip.addLocalFile("/var/hyperprotect/se-checksums.txt.enc");
    }
    catch (e) {
        zip.addLocalFile("/var/hyperprotect/se-checksums.txt");
    }
    zip.addLocalFile("/var/hyperprotect/se-signature.bin");
    var zipFileContents = zip.toBuffer();
    res.writeHead(200, {
        'Content-Disposition': `attachment; filename="${fileName}"`,
        'Content-Type': fileType,
      })
    res.end(zipFileContents);
});

app.get('/api/v1/attestationdocument', function(req, res) {
    console.log('GET ' + req.path);
    res.type('txt').sendFile('/var/hyperprotect/se-checksums.txt');
});

app.get('/api/v1/transactions', function(req, res) {
    console.log('GET ' + req.path);
    res.status(200).json(transactions);
});

app.post('/api/v1/transactions', (req, res) => {
    console.log('POST ' + req.path);
    let data = req.body;
    transactions.push(data);
    let record_count = transactions.length - 1;
    res.status(201).send(JSON.stringify(record_count));
})

http.createServer(app).listen(8080);
https.createServer(options, app).listen(8443);
