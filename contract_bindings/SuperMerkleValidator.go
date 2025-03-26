package contracts

import (
	"encoding/binary"
	"errors"
	"fmt"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/common/hexutil"
)

// SignatureData represents the struct for signature data in the SuperMerkleValidator contract
type SignatureData struct {
	ValidUntil uint64        // uint48 in Solidity
	MerkleRoot common.Hash   // bytes32 in Solidity
	Proof      []common.Hash // bytes32[] in Solidity
	Signature  []byte        // bytes in Solidity
}

// EncodeSignatureData encodes a SignatureData struct into bytes that matches Solidity's abi.encode
func EncodeSignatureData(data SignatureData) ([]byte, error) {
	// Convert validUntil to bytes (ensuring it fits in uint48)
	if data.ValidUntil > 0xFFFFFFFFFFFF {
		return nil, errors.New("validUntil exceeds uint48 max value")
	}

	// Pack all parts of the data
	// This matches Solidity's abi.encode(uint48, bytes32, bytes32[], bytes)
	var result []byte

	// Encode the offset locations for dynamic arrays (proof and signature)
	// The first offset points to bytes32[] proof
	proofOffset := 32 * 3 // Start of dynamic data (3 params with 32 bytes each)

	// The second offset points to bytes signature, which comes after the proof array
	signatureOffset := proofOffset + 32 + (len(data.Proof) * 32) + 32 // proof offset + proof.length word + proof data + padding

	// Encode the static parts: validUntil (padded to 32 bytes) and merkleRoot
	validUntilBytes := make([]byte, 32)
	binary.BigEndian.PutUint64(validUntilBytes[24:], data.ValidUntil)
	result = append(result, validUntilBytes...)
	result = append(result, data.MerkleRoot.Bytes()...)

	// Encode the offset to the proof array
	proofOffsetBytes := make([]byte, 32)
	binary.BigEndian.PutUint64(proofOffsetBytes[24:], uint64(proofOffset))
	result = append(result, proofOffsetBytes...)

	// Encode the offset to the signature
	sigOffsetBytes := make([]byte, 32)
	binary.BigEndian.PutUint64(sigOffsetBytes[24:], uint64(signatureOffset))
	result = append(result, sigOffsetBytes...)

	// Encode the proof array
	// First, encode the length of the array
	proofLenBytes := make([]byte, 32)
	binary.BigEndian.PutUint64(proofLenBytes[24:], uint64(len(data.Proof)))
	result = append(result, proofLenBytes...)

	// Then encode each proof element
	for _, proof := range data.Proof {
		result = append(result, proof.Bytes()...)
	}

	// Encode the signature
	// First, encode the length of the signature
	sigLenBytes := make([]byte, 32)
	binary.BigEndian.PutUint64(sigLenBytes[24:], uint64(len(data.Signature)))
	result = append(result, sigLenBytes...)

	// Then encode the signature itself
	result = append(result, data.Signature...)

	// Pad the signature to a multiple of 32 bytes
	padLength := (32 - (len(data.Signature) % 32)) % 32
	padding := make([]byte, padLength)
	result = append(result, padding...)

	return result, nil
}

// DecodeSignatureData decodes bytes into a SignatureData struct
// This is the Go equivalent of Solidity's _decodeSignatureData function
func DecodeSignatureData(sigDataRaw []byte) (SignatureData, error) {
	if len(sigDataRaw) < 128 { // Minimum size for header (4 * 32 bytes)
		return SignatureData{}, errors.New("input data too short")
	}

	// Extract validUntil (uint48)
	validUntil := binary.BigEndian.Uint64(sigDataRaw[24:32])

	// Extract merkleRoot (bytes32)
	merkleRoot := common.BytesToHash(sigDataRaw[32:64])

	// Get offset to proof array
	proofOffset := binary.BigEndian.Uint64(sigDataRaw[56:64])
	if int(proofOffset)+32 > len(sigDataRaw) {
		return SignatureData{}, errors.New("invalid proof offset")
	}

	// Get offset to signature bytes
	sigOffset := binary.BigEndian.Uint64(sigDataRaw[88:96])
	if int(sigOffset)+32 > len(sigDataRaw) {
		return SignatureData{}, errors.New("invalid signature offset")
	}

	// Extract proof array length
	proofLenPos := proofOffset
	proofLen := binary.BigEndian.Uint64(sigDataRaw[proofLenPos+24 : proofLenPos+32])

	// Extract each proof element
	var proof []common.Hash
	proofStartPos := proofLenPos + 32
	for i := uint64(0); i < proofLen; i++ {
		if int(proofStartPos+(i+1)*32) > len(sigDataRaw) {
			return SignatureData{}, errors.New("proof data out of bounds")
		}
		proofElement := common.BytesToHash(sigDataRaw[proofStartPos+i*32 : proofStartPos+(i+1)*32])
		proof = append(proof, proofElement)
	}

	// Extract signature length
	sigLenPos := sigOffset
	sigLen := binary.BigEndian.Uint64(sigDataRaw[sigLenPos+24 : sigLenPos+32])

	// Extract signature bytes
	sigStartPos := sigLenPos + 32
	if int(sigStartPos+sigLen) > len(sigDataRaw) {
		return SignatureData{}, errors.New("signature data out of bounds")
	}
	signature := sigDataRaw[sigStartPos : sigStartPos+sigLen]

	return SignatureData{
		ValidUntil: validUntil,
		MerkleRoot: merkleRoot,
		Proof:      proof,
		Signature:  signature,
	}, nil
}

// BytesToHex converts bytes to a hexadecimal string with 0x prefix
func BytesToHex(b []byte) string {
	return hexutil.Encode(b)
}

// Example of how to use the encoding/decoding functions
func ExampleSignatureDataEncodeDecode() {
	// Create a sample SignatureData
	data := SignatureData{
		ValidUntil: 1679616000, // Example timestamp
		MerkleRoot: common.HexToHash("0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef"),
		Proof: []common.Hash{
			common.HexToHash("0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"),
			common.HexToHash("0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"),
		},
		Signature: hexutil.MustDecode("0x1234567890"),
	}

	// Encode the data
	encoded, err := EncodeSignatureData(data)
	if err != nil {
		fmt.Println("Error encoding:", err)
		return
	}

	// Print the encoded data
	fmt.Println("Encoded data:", BytesToHex(encoded))

	// Decode the data back
	decoded, err := DecodeSignatureData(encoded)
	if err != nil {
		fmt.Println("Error decoding:", err)
		return
	}

	// Print the decoded data
	fmt.Printf("Decoded: ValidUntil=%d, MerkleRoot=%s, ProofLen=%d, SignatureLen=%d\n",
		decoded.ValidUntil, decoded.MerkleRoot.Hex(), len(decoded.Proof), len(decoded.Signature))
}
