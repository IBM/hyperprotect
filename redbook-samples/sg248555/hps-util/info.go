package main

import (
	"fmt"
	"log"

	"github.com/IBM-Cloud/hpcs-grep11-go/ep11"
	pb "github.com/IBM-Cloud/hpcs-grep11-go/grpc"
)

// Encrypts with HPCS
func Info(cc CryptoClient) error {
	mechanismListRequest := &pb.GetMechanismListRequest{}

	// Retrieve a list of all supported mechanisms
	mechanismListResponse, err := cc.CryptoClient.GetMechanismList(cc.Context, mechanismListRequest)
	if err != nil {
		return fmt.Errorf("get mechanism list error: %s", err)
	}
	fmt.Printf("got mechanism list:\n%v ...\n", mechanismListResponse.Mechs[:1])

	mechanismInfoRequest := &pb.GetMechanismInfoRequest{
		Mech: ep11.CKM_RSA_PKCS,
	}

	// Retrieve information about the CKM_RSA_PKCS mechanism
	mechanismInfoResponse, err := cc.CryptoClient.GetMechanismInfo(cc.Context, mechanismInfoRequest)
	if err != nil {
		return fmt.Errorf("get mechanism info error: %s", err)
	}

	log.Println(mechanismInfoResponse)
	return nil
}
