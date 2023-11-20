package main

import (
	"fmt"

	pb "github.com/IBM-Cloud/hpcs-grep11-go/grpc"

	"github.com/IBM-Cloud/hpcs-grep11-go/ep11"
	"github.com/IBM-Cloud/hpcs-grep11-go/util"
)

// generate a new 4096 bit RSA key pair
func GenerateKeyPair(cc CryptoClient) ([]byte, []byte, error) {
	generateKeyPairResponse, err := cc.CryptoClient.GenerateKeyPair(cc.Context, generateRSA4096MultiKeyPairRequest())
	if err != nil {
		panic(fmt.Errorf("generate RSA key pair error: %w", err))
	}

	return generateKeyPairResponse.PubKeyBytes, generateKeyPairResponse.PrivKeyBytes, nil
}

func generateRSA4096MultiKeyPairRequest() *pb.GenerateKeyPairRequest {
	return &pb.GenerateKeyPairRequest{
		Mech: &pb.Mechanism{
			Mechanism: ep11.CKM_RSA_PKCS_KEY_PAIR_GEN,
		},
		PubKeyTemplate: util.AttributeMap(ep11.EP11Attributes{
			ep11.CKA_ENCRYPT:         true,
			ep11.CKA_VERIFY:          true,
			ep11.CKA_MODULUS_BITS:    4096,
			ep11.CKA_PUBLIC_EXPONENT: 65537,
		}),
		PrivKeyTemplate: util.AttributeMap(ep11.EP11Attributes{
			ep11.CKA_PRIVATE:     true,
			ep11.CKA_SENSITIVE:   true,
			ep11.CKA_VERIFY:      false,
			ep11.CKA_ENCRYPT:     false,
			ep11.CKA_DECRYPT:     true,
			ep11.CKA_SIGN:        true,
			ep11.CKA_EXTRACTABLE: false,
		}),
	}
}

func generateRSA4096EncDecKeyPairRequest() *pb.GenerateKeyPairRequest {
	return &pb.GenerateKeyPairRequest{
		Mech: &pb.Mechanism{
			Mechanism: ep11.CKM_RSA_PKCS_KEY_PAIR_GEN,
		},
		PubKeyTemplate: util.AttributeMap(ep11.EP11Attributes{
			ep11.CKA_ENCRYPT:         true,
			ep11.CKA_VERIFY:          false,
			ep11.CKA_MODULUS_BITS:    4096,
			ep11.CKA_PUBLIC_EXPONENT: 65537,
		}),
		PrivKeyTemplate: util.AttributeMap(ep11.EP11Attributes{
			ep11.CKA_PRIVATE:     true,
			ep11.CKA_SENSITIVE:   true,
			ep11.CKA_VERIFY:      false,
			ep11.CKA_ENCRYPT:     false,
			ep11.CKA_DECRYPT:     true,
			ep11.CKA_SIGN:        false,
			ep11.CKA_EXTRACTABLE: false,
		}),
	}
}

func generateRSA4096SignKeyPairRequest() *pb.GenerateKeyPairRequest {
	return &pb.GenerateKeyPairRequest{
		Mech: &pb.Mechanism{
			Mechanism: ep11.CKM_RSA_PKCS_KEY_PAIR_GEN,
		},
		PubKeyTemplate: util.AttributeMap(ep11.EP11Attributes{
			ep11.CKA_ENCRYPT:         false,
			ep11.CKA_VERIFY:          true,
			ep11.CKA_MODULUS_BITS:    4096,
			ep11.CKA_PUBLIC_EXPONENT: 65537,
		}),
		PrivKeyTemplate: util.AttributeMap(ep11.EP11Attributes{
			ep11.CKA_PRIVATE:     true,
			ep11.CKA_SENSITIVE:   true,
			ep11.CKA_VERIFY:      false,
			ep11.CKA_ENCRYPT:     false,
			ep11.CKA_DECRYPT:     false,
			ep11.CKA_SIGN:        true,
			ep11.CKA_EXTRACTABLE: false,
		}),
	}
}
