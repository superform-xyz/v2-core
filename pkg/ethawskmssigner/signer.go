package ethawskmssigner

import (
	"bytes"
	"context"
	"crypto/ecdsa"
	"encoding/asn1"
	"encoding/hex"
	"math/big"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/service/kms"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/crypto/secp256k1"
	"github.com/pkg/errors"
)

const (
	awsKmsSignOperationMessageType      = "DIGEST"
	awsKmsSignOperationSigningAlgorithm = "ECDSA_SHA_256"
)

var (
	keyCache       = newPubKeyCache()
	secp256k1N     = crypto.S256().Params().N
	secp256k1HalfN = new(big.Int).Div(secp256k1N, big.NewInt(2)) //nolint:mnd
)

// NewAwsKmsTransactorWithChainID creates a new transactor with the given chainID using AWS KMS
func NewAwsKmsTransactorWithChainID(ctx context.Context, svc KMS, keyId string, chainID *big.Int) (*bind.TransactOpts, error) {
	pubkey, err := GetPubKey(ctx, svc, keyId)
	if err != nil {
		return nil, err
	}

	pubKeyBytes := secp256k1.S256().Marshal(pubkey.X, pubkey.Y)

	keyAddr := crypto.PubkeyToAddress(*pubkey)
	if chainID == nil {
		return nil, bind.ErrNoChainID
	}

	signer := types.LatestSignerForChainID(chainID)

	signerFn := func(address common.Address, tx *types.Transaction) (*types.Transaction, error) {
		if address != keyAddr {
			return nil, bind.ErrNotAuthorized
		}

		txHashBytes := signer.Hash(tx).Bytes()

		rBytes, sBytes, err := getSignatureFromKms(ctx, svc, keyId, txHashBytes)
		if err != nil {
			return nil, err
		}

		// Adjust S value from signature according to Ethereum standard
		sBigInt := new(big.Int).SetBytes(sBytes)
		if sBigInt.Cmp(secp256k1HalfN) > 0 {
			sBytes = new(big.Int).Sub(secp256k1N, sBigInt).Bytes()
		}

		signature, err := getEthereumSignature(pubKeyBytes, txHashBytes, rBytes, sBytes)
		if err != nil {
			return nil, err
		}

		return tx.WithSignature(signer, signature)
	}

	return &bind.TransactOpts{
		From:   keyAddr,
		Signer: signerFn,
	}, nil
}

// GetPubKey gets the public key from KMS
func GetPubKey(ctx context.Context, svc KMS, keyId string) (*ecdsa.PublicKey, error) {
	pubkey := keyCache.get(keyId)
	if pubkey == nil {
		pubKeyBytes, err := getPublicKeyDerBytesFromKMS(ctx, svc, keyId)
		if err != nil {
			return nil, err
		}

		pubkey, err = crypto.UnmarshalPubkey(pubKeyBytes)
		if err != nil {
			return nil, errors.Wrap(err, "can not construct secp256k1 public key from key bytes")
		}

		keyCache.add(keyId, pubkey)
	}

	return pubkey, nil
}

func getPublicKeyDerBytesFromKMS(ctx context.Context, svc KMS, keyId string) ([]byte, error) {
	getPubKeyOutput, err := svc.GetPublicKey(ctx, &kms.GetPublicKeyInput{
		KeyId: aws.String(keyId),
	})
	if err != nil {
		return nil, errors.Wrapf(err, "can not get public key from KMS for KeyId=%s", keyId)
	}

	var asn1pubk asn1EcPublicKey
	if _, err = asn1.Unmarshal(getPubKeyOutput.PublicKey, &asn1pubk); err != nil {
		return nil, errors.Wrapf(err, "can not parse asn1 public key for KeyId=%s", keyId)
	}

	return asn1pubk.PublicKey.Bytes, nil
}

func getSignatureFromKms(ctx context.Context, svc KMS, keyId string, txHashBytes []byte) ([]byte, []byte, error) {
	signInput := &kms.SignInput{
		KeyId:            aws.String(keyId),
		SigningAlgorithm: awsKmsSignOperationSigningAlgorithm,
		MessageType:      awsKmsSignOperationMessageType,
		Message:          txHashBytes,
	}

	signOutput, err := svc.Sign(ctx, signInput)
	if err != nil {
		return nil, nil, err
	}

	var sigAsn1 asn1EcSig
	if _, err = asn1.Unmarshal(signOutput.Signature, &sigAsn1); err != nil {
		return nil, nil, err
	}

	return sigAsn1.R.Bytes, sigAsn1.S.Bytes, nil
}

func getEthereumSignature(expectedPublicKeyBytes []byte, txHash []byte, r []byte, s []byte) ([]byte, error) {
	rsSignature := append(adjustSignatureLength(r), adjustSignatureLength(s)...)
	signature := append(rsSignature, []byte{0}...)

	recoveredPublicKeyBytes, err := crypto.Ecrecover(txHash, signature)
	if err != nil {
		return nil, err
	}

	if hex.EncodeToString(recoveredPublicKeyBytes) != hex.EncodeToString(expectedPublicKeyBytes) {
		signature = append(rsSignature, []byte{1}...)

		recoveredPublicKeyBytes, err = crypto.Ecrecover(txHash, signature)
		if err != nil {
			return nil, err
		}

		if hex.EncodeToString(recoveredPublicKeyBytes) != hex.EncodeToString(expectedPublicKeyBytes) {
			return nil, errors.New("can not reconstruct public key from sig")
		}
	}

	return signature, nil
}

func adjustSignatureLength(buffer []byte) []byte {
	buffer = bytes.TrimLeft(buffer, "\x00")
	for len(buffer) < 32 {
		zeroBuf := []byte{0}
		buffer = append(zeroBuf, buffer...)
	}
	return buffer
}
