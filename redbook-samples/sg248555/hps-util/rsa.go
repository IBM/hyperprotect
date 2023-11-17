package main

import (
	"encoding/base64"
	"fmt"

	"github.com/IBM-Cloud/hpcs-grep11-go/ep11"
	pb "github.com/IBM-Cloud/hpcs-grep11-go/grpc"
)

// Encrypts with HPCS
func EncryptRSA(cc CryptoClient, key KeyPair, clearData string) (string, error) {
	encryptSingleResponse, err := cc.CryptoClient.EncryptSingle(cc.Context, &pb.EncryptSingleRequest{
		Key: key.Public,
		Mech: &pb.Mechanism{
			Mechanism: ep11.CKM_RSA_PKCS,
		},
		Plain: []byte(clearData),
	})
	if err != nil {
		return "", fmt.Errorf("encrypt error: %w", err)
	}
	return base64.StdEncoding.EncodeToString(encryptSingleResponse.Ciphered), nil
}

// Decrypts with HPCS
func DecryptRSA(cc CryptoClient, key KeyPair, cypheredData string) (string, error) {
	// Read in the keypair file
	ciphered, err := base64.StdEncoding.DecodeString(cypheredData)
	if err != nil {
		return "", fmt.Errorf("failed to decode base64 to bytes: %w", err)
	}
	decryptSingleResponse, err := cc.CryptoClient.DecryptSingle(cc.Context, &pb.DecryptSingleRequest{
		Key: key.Private,
		Mech: &pb.Mechanism{
			Mechanism: ep11.CKM_RSA_PKCS,
		},
		Ciphered: ciphered,
	})
	if err != nil {
		return "", fmt.Errorf("decrypt error: %w", err)
	}
	return string(decryptSingleResponse.Plain), nil
}
