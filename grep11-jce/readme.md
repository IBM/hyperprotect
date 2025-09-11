
## Before you begin

To set up the IBMHPCSJCE provider, make sure that you use open JDK11 or Oracle JDK version 11.


## Step 1: Install the provider

To install the IBMHPCSJCE provider, complete the following steps:

1. Download `IBMHPCSJCE.jar` from https://github.com/ibm-hyper-protect/hpcs-grep11-jce/releases.

2. Download `IBMHPCSJCE.cer` and verify the JAR signature by using the following command:
   ```
   keytool -import -alias IBMHPCSJCE -keystore  "$JAVA_HOME/jre/lib/security/cacerts" -storepass "changeit" -file IBMHPCSJCE.cer
   jarsigner -verify IBMHPCSJCE.jar
   ```

3. Add `IBMHPCSJCE.jar` to the Java path.


## Step 2: Configure the provider

To configure the IBMHPCSJCE provider, complete the following steps.

1. Follow these steps to add the provider to the JDK/JRE security configure file:

  a. Locate the `java.security` configure file in <JDK/JRE root>/conf/security/java.security.

  b. Add the following as the last line of code in the configure file, and replace 'n' with the number next to the number in the previous line:
     ```
     security.provider.n=IBMHPCSJCE
     ```

  In the following example, `n` is replaced with `14` because the number in the previous line is `13`.
  ```
     # List of providers and their preference orders:
     security.provider.1=SUN
     ...
     security.provider.13=SunPKCS11
     security.provider.14=IBMHPCSJCE
  ```

2. Configure and start the GREP11 server. Make sure that you enable your on-prem server with mutual TLS by following these steps:

    a. Prepare your certificates for mTLS. You can get your certificates via various ways, with certificates and keys in the following format. These certificates and keys are to be used in step 3.b:
      - GREP11SERVER_TRUST_CERT_COLLECTION_FILE_PATH: The root certificate that is used to replace the system default to verify the server identity. It should be PEM-encoded with all the certificates concatenated together. Include `BEGIN CERTIFICATE` in the file header. Do this for every certificate.
      - GREP11SERVER_CLIENT_CERT_CHAIN_FILE_PATH: The client certificate. It should be PEM-encoded with `BEGIN CERTIFICATE` and `BEGIN PRIVATE KEY` in the file header.
      - GREP11SERVER_CLIENT_PRIVATE_KEY_FILE_PATH: The client key. It is an unencrypted PKCS#8 key.

      If you want to generate OpenSSL certificates, refer to [Creating OpenSSL certificates for GREP11 Virtual Servers](https://www.ibm.com/docs/en/hpvs/1.2.x?topic=servers-creating-openssl-certificates-grep11-containers). Note that the client key file should be changed into the unencrypted PKCS#8 format with the following command line:
      ```
      openssl pkcs8 -topk8 -in client.key.rsa -out client. key -nocrypt
      ```

    b. Make a note of the value of `COMMON_NAME`. It is to be used in step 3 when you configure the connection to server.


    c. Start your GREP11 server. For detailed steps, see [Creating the GREP11 container](https://www.ibm.com/docs/en/hpvs/1.2.x?topic=servers-working-grep11-virtual).


3. Configure the connection to the GREP11 server through the environment variables:

  a. Optional: Add the host names to /etc/hosts according to the information of your certificates.

  In the following example, `x.x.x.x` is the IP address of the GREP11 server, and `grep11.example.com` is the `COMMON_NAME` that is returned in the previous step.
  ```
     x.x.x.x grep11.example.com
  ```

  b. Configure the endpoint and mTLS certificate locations. Set required environment variables according to the information of the target local GREP11 server:

     WORK_DIR=<path to mTLS client certificates>
     export GREP11SERVER_TRUST_CERT_COLLECTION_FILE_PATH=${WORK_DIR}/certs/ca.pem
     export GREP11SERVER_CLIENT_CERT_CHAIN_FILE_PATH=${WORK_DIR}/certs/client.pem
     export GREP11SERVER_CLIENT_PRIVATE_KEY_FILE_PATH=${WORK_DIR}/certs/client.key
     export GREP11SERVER_ENDPOINT=<COMMON_NAME>:<GREP11SERVER_PORT>



## Step 3: Apply the provider to the application

After you complete the configuration steps of the provider, you can apply the provider to your application. The following are a few examples:

- Get the IBMHPCSJCE provider by name:
  ```
  Provider p = Security.getProvider("IBMHPCSJCE");
  ```

- Get algorithms that are implemented in the provider:
  ```
  KeyPairGenerator keyGenerator = KeyPairGenerator.getInstance("RSA", provider);
  KeyStore local_ks = KeyStore.getInstance("HPCS-OnPrem", provider);
  ```
For more information about the algorithms and services that the provider supports, see the **Reference** section below.

## Reference

### Algorithms and services implemented

For more information about the algorithms and services that are implemented in the IBMHPCSJCE provider, refer to the following table.

|  Classes   | Encryption algorithms  |
|  ----  | ----  |
| KeyAgreement  | ECDH |
| KeyPairGenerator  | RSA<br>EC<br>DH |
| KeyGenerator  | AES<br>HMAC |
| KeyFactory  | RSA<br>EC |
| Signature  |SHA1withRSA<br>SHA224withRSA<br>SHA256withRSA<br>SHA384withRSA<br>SHA512withRSA<br>SHA1withECDSA<br>SHA224withECDSA<br>SHA256withECDSA<br>SHA384withECDSA<br>SHA512withECDSA |
| MessageDigest  | SHA-1<br>SHA-224<br>SHA-256<br>SHA-384<br>SHA-512<br>SHA-512/224<br>SHA-512/256 |
| Mac  | HmacSHA1<br>HmacSHA224<br>HmacSHA256<br>HmacSHA384<br>HmacSHA512<br>HmacSHA512/224<br>HmacSHA512/256 |
| SecretKeyFactory  | AES<br>HMAC |
| Cipher  | AES<br>RSA/ECB |
| SecureRandom  | PKCS11 |
| KeyStore  | HPCS<br>HPCS-OnPrem |


### Code example

The following is a complete code example for your reference.

<details>
<summary>Sign and Verify by RSA keypair</summary>
<pre><code>
// - generate RSA keypair
KeyPairGenerator keyGenerator = KeyPairGenerator.getInstance("RSA", provider);
keyGenerator.initialize(2048);
KeyPair rsaKeyPair = keyGenerator.generateKeyPair();
//Output: "Generate RSA keypair : " + rsaKeyPair.toString()

// - init keystore instance
String alias = "e2e_key";
char[] pwd = "test".toCharArray();
//Output: "Init local keystore instance..."

// - store keystore firstly
File file = new File("/tmp/keystore");
KeyStore local_ks = KeyStore.getInstance("HPCS-OnPrem", provider);
if (file.exists()) {
	local_ks.load(new FileInputStream(file), pwd);
} else {
	local_ks.load(null, null);
	local_ks.store(new FileOutputStream(file), pwd);
}
//Output: "Init local keystore successfully"

// - set key
CertificateFactory cf = CertificateFactory.getInstance("X.509");
FileInputStream fis = new FileInputStream(new File("./lise_sommer_certificatechain.p7"));
CertPath certPath = cf.generateCertPath(fis, "PKCS7");
List<? extends Certificate> certList = certPath.getCertificates();
certificateChain = CertificateUtility.sortCertificates(certList.toArray(new Certificate[certList.size()]));
local_ks.setKeyEntry(alias, rsaKeyPair.getPrivate(), pwd, certificateChain);
//Output: "Set key entry"

// - store key to pfx
local_ks.store(os, pwd);
//Output: "Store key entry"

opStream = new FileOutputStream(outputFile);
os.writeTo(opStream);
stream = new FileInputStream(outputFile);
//Output: "Write key entry to pfx"

// - load from stored pfx
local_ks.load(stream, pwd);
//Output: "Load key entry from pfx..."

// - Retrive from loaded stream
PrivateKey retrievedKey = (PrivateKey) local_ks.getKey(alias, pwd);
//Output: "Load key entry from pfx succssfully"

// - sign and verify
byte[] dataToSign = "Send more money".getBytes(StandardCharsets.UTF_8);
// Info: "Get signature instance "
Signature rsaSig = Signature.getInstance("SHA256withRSA", provider);
// - when signing with EP11 private key
//Info: "Sign data"
rsaSig.initSign(retrievedKey);
rsaSig.update(dataToSign, 0, dataToSign.length);
byte[] signatureValue = rsaSig.sign();

// - then the signature can be validated by public key using EP11
//Info: "Verify signature"
rsaSig.initVerify(rsaKeyPair.getPublic());
rsaSig.update(dataToSign, 0, dataToSign.length);
boolean isValid = rsaSig.verify(signatureValue);
//Output: "Signature and verification result : " + isValid    

</code></pre>
</details>


<details>
<summary>Encrypt and Decrypt by AES keypair</summary>
<pre><code>
// - encrypt and decrypt
//Info: "Encrypt and Decrypt by AES ..."
KeyGenerator kg = KeyGenerator.getInstance("AES", provider);
kg.init(128);
SecretKey key = kg.generateKey();
//Output: "Generate AES secret key"

// - securerandom
final int AES_KEYLENGTH = 128;
byte[] iv = new byte[AES_KEYLENGTH / 8];
SecureRandom srAES = new SecureRandom();
srAES.nextBytes(iv);
Cipher cipher = Cipher.getInstance("AES/CBC/PKCS5Padding", provider);
//Info: "Encrypt data by AES"
cipher.init(Cipher.ENCRYPT_MODE, key, new IvParameterSpec(iv));
String targetData = "Test Encrypt and Decrypt Data";
byte[] result = cipher.doFinal(targetData.getBytes());
//Info: "Decrypt data by AES"
cipher.init(Cipher.DECRYPT_MODE, key, new IvParameterSpec(iv));
byte[] decryptData = cipher.doFinal(result);
//Output: "Verify decrypt vs. encrypt : " + targetData.equals(new String(decryptData))
</code></pre>
</details>

<details>
<summary>MAC verify</summary>
<pre><code>
// - MAC verify
KeyGenerator kgMAC = KeyGenerator.getInstance("HMAC", provider);
kg.init(128);
SecretKey keyMAC = kgMAC.generateKey();
Mac mac = Mac.getInstance("HmacSHA256", provider);
mac.init(keyMAC);
byte[] dataBytes = "Test Mac".getBytes(StandardCharsets.UTF_8);
byte[] res = mac.doFinal(dataBytes);
//Output: "MAC verify : " + !Base64.getEncoder().encodeToString(res).isEmpty()
</code></pre>
</details>

