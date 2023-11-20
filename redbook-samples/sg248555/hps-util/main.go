package main

import (
	"fmt"
	"io/fs"
	"log"
	"os"
	"time"
)

type KeyPair struct {
	Private, Public []byte
}

var (
	Public64  = os.Getenv("HPCS_PUB")
	Private64 = os.Getenv("HPCS_PRIV")
)

const (
	PublicPath  = "/mnt/data/public.key"
	PrivatePath = "/mnt/data/private.key"
)

// try to read keys from environment or data volume
func readKeys() (KeyPair, error) {
	key := KeyPair{}

	// try to read keys from environment
	if Public64 != "" && Private64 != "" {
		key.Public = Decode(Public64)
		key.Private = Decode(Private64)
		return key, nil
	}

	// try to read keys from data volume
	_, pubErr := os.Stat(PublicPath)
	_, privErr := os.Stat(PrivatePath)
	if os.IsNotExist(pubErr) && os.IsNotExist(privErr) {
		// The keys can be stored on persistend storage or even built into container images
		err := os.WriteFile("/mnt/data/public.key", key.Public, 0o600|fs.ModeExclusive)
		if err != nil {
			panic(fmt.Errorf("public key write error: %s", err))
		}
		err = os.WriteFile("/mnt/data/private.key", key.Private, 0o644|fs.ModeExclusive)
		if err != nil {
			panic(fmt.Errorf("private key write error: %s", err))
		}
		return key, nil
	}

	return key, fmt.Errorf("no key in env or data")
}

// generate new keypair
func generateKeys(cc CryptoClient) (KeyPair, error) {
	// Generate a new wrapped RSA 4096 keypair.
	// This can only be used in conjunction with the HPCS service / HSM bearing the correct master key
	var err error
	key := KeyPair{}
	key.Public, key.Private, err = GenerateKeyPair(cc)
	if err != nil {
		return key, fmt.Errorf("key generation error: %s", err)
	}

	// The keys can be stored on persistend storage or even built into container images
	err = os.WriteFile(PublicPath, key.Public, 0o600|fs.ModeExclusive)
	if err != nil {
		return key, fmt.Errorf("public key write error: %s", err)
	}
	err = os.WriteFile(PrivatePath, key.Private, 0o644|fs.ModeExclusive)
	if err != nil {
		return key, fmt.Errorf("private key write error: %s", err)
	}

	// If necessary this can be logged as it is wrapped / encrypted with the HPCS key
	log.Printf(
		"\nnew public : %s\n\nnew private: %s\n\n",
		Encode(key.Public),
		Encode(key.Private))
	return key, nil
}

func main() {
	cc := NewCryptoClient()
	defer cc.Close()

	err := Info(cc)
	if err != nil {
		panic(fmt.Errorf("could get mechanism info: %s", err))
	}

	// get wrapped key pair
	key, err := readKeys()
	if err != nil {
		log.Printf("read key error: %s", err)
		key, err = generateKeys(cc)
		if err != nil {
			panic(fmt.Errorf("generate key error: %s", err))
		}
	}

	// use wrapped key pair to encrypt data
	enc, err := EncryptRSA(cc, key, fmt.Sprintf("testing data encryption %s", time.Now()))
	if err != nil {
		panic(fmt.Errorf("encrypt error: %s", err))
	}

	// use wrapped key pair to decrypt data
	dec, err := DecryptRSA(cc, key, enc)
	if err != nil {
		panic(fmt.Errorf("decrypt error: %s", err))
	}

	log.Printf("result: %s\n", dec)
}
